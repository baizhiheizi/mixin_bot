# frozen_string_literal: true

module MixinBot
  module Outputs
    ##
    # The polling loop: fetches a page of the bot's outputs oldest-first,
    # records unseen outputs in the receipt store (the dedup gate), enqueues
    # every matching processor through the job queue, and advances its cursor
    # only after the whole page is absorbed.
    #
    # The resume cursor is derived from the receipts themselves — the newest
    # output timestamp recorded for the bot — and kept in memory afterwards:
    # receipts recorded past a mid-page failure cover the remainder (the
    # outputs API returns outputs strictly after the offset), so there is no
    # gap and no separate cursor state.
    #
    # Each loop iteration first sweeps receipts that were recorded but never
    # dispatched (a crash between the two steps), re-evaluating predicates and
    # enqueueing late — making dispatch at-least-once.
    #
    # All collaborators are injectable for offline testing: sleeper, clock,
    # receipt store, processor list, and the enqueue hook. {#run} blocks until
    # {#stop}; signal wiring is the process's job (the mixin_bot:poller rake
    # task).
    #
    #   poller = Poller.new(api: MixinBot.bot(:shop), interval: 5)
    #   trap('TERM') { poller.stop }
    #   poller.run
    #
    class Poller
      DEFAULT_INTERVAL = 5
      DEFAULT_PAGE_SIZE = 500

      attr_reader :api, :receipts, :interval, :page_size

      # rubocop:disable Metrics/ParameterLists
      ##
      # @param api [MixinBot::API] the bot whose outputs are polled
      # @param receipts [#record!, #mark_enqueued!, #unenqueued, #cursor_value]
      #   receipt store (default: the registered store from the generated
      #   model, else in-memory; Rails hosts normally rely on the registration)
      # @param processors [Array<Class>, nil] processor classes; nil discovers
      #   them from the Mixin::Processors namespace on first use
      # @param interval [Numeric] seconds between fetch cycles
      # @param page_size [Integer] outputs fetched per cycle
      # @param state [String] output state filter ('' = all states, covering
      #   inbound unspent outputs and outbound spent ones)
      # @param asset [String, nil] restrict polling to one asset id
      # @param members [Array<String>, String, nil] restrict polling to these
      #   member user ids (defaults to the bot itself at the API)
      # @param threshold [Integer, nil] members threshold (defaults to the
      #   members count at the API)
      # @param enqueuer [#call, nil] called with (processor_class, receipt);
      #   defaults to ProcessingJob.perform_later
      # @param sleeper [#call, nil] called with seconds between cycles
      # @param clock [#call, nil] returns current Time (sweep bookkeeping)
      # @param logger [#call, nil] called with (level, detail)
      #
      def initialize(api: MixinBot.api, receipts: nil,
                     processors: nil, interval: DEFAULT_INTERVAL, page_size: DEFAULT_PAGE_SIZE, state: '',
                     asset: nil, members: nil, threshold: nil,
                     enqueuer: nil, sleeper: nil, clock: nil, logger: nil)
        @api = api
        @bot_app_id = api.config.app_id
        @receipts = receipts || Outputs.receipt_store || MemoryReceiptStore.new
        @processors = processors
        @interval = interval
        @page_size = page_size
        @state = state
        @asset = asset
        @members = Array(members) if members
        @threshold = threshold
        @enqueuer = enqueuer || ->(processor, receipt) { ProcessingJob.perform_later(receipt.id, processor.name) }
        @sleeper = sleeper || ->(seconds) { sleep seconds }
        @clock = clock || -> { Time.now }
        @logger = logger || Outputs.logger
        @stopping = false
        @cursor_value = nil
      end
      # rubocop:enable Metrics/ParameterLists

      ##
      # Runs fetch cycles until {#stop} is called. One cycle = sweep stale
      # receipts, fetch a page, absorb every output, advance the cursor.
      # Cycle errors are logged and retried after the interval; the cursor
      # only moves after a fully absorbed page.
      #
      # @return [void]
      #
      def run
        until stopped?
          begin
            poll_once
          rescue StandardError => e
            @logger.call(:poll_error, e)
          end

          break if stopped?

          @sleeper.call @interval
        end
      end

      ##
      # Requests termination; the in-flight cycle finishes first.
      #
      # Signal-safe: a plain flag (no Mutex — trap handlers cannot synchronize).
      def stop
        @stopping = true
      end

      def stopped?
        @stopping
      end

      ##
      # One fetch cycle. Exposed for tests and callers that drive the loop
      # themselves.
      #
      # @return [Integer] number of outputs in the fetched page
      #
      def poll_once
        sweep_undispatched

        page = fetch_page
        page.each { |output| absorb(output) }

        @cursor_value = page.last['created_at'] if page.last
        page.size
      end

      private

      def sweep_undispatched
        cutoff = @clock.call - @interval
        @receipts.unenqueued(bot_app_id: @bot_app_id, older_than: cutoff).each do |receipt|
          dispatch(Envelope.new(receipt, api: @api), receipt)
        end
      end

      # Resume position: the newest recorded receipt for this bot, held in
      # memory afterwards (advance = in-memory, no persistence needed).
      def fetch_page
        @cursor_value ||= @receipts.cursor_value(bot_app_id: @bot_app_id)

        response = @api.safe_outputs(
          state: @state, limit: @page_size, offset: @cursor_value.to_s, order: 'ASC',
          asset: @asset, members: @members, threshold: @threshold
        )
        Array(response['data'])
      end

      def absorb(output)
        receipt, status = @receipts.record!(bot_app_id: @bot_app_id, output:)
        return if status == :duplicate

        dispatch(Envelope.new(receipt, api: @api), receipt)
      end

      # Evaluates every processor against the envelope and enqueues the
      # matches, then stamps the receipt as dispatched. An output matching no
      # processor is stamped without work.
      def dispatch(envelope, receipt)
        processor_list(envelope).each { |processor| @enqueuer.call(processor, receipt) }
        @receipts.mark_enqueued!(receipt)
      rescue StandardError => e
        # Leave the receipt undispatched so the next sweep retries the enqueue.
        @logger.call(:dispatch_error, "#{e.class}: #{e.message} (output #{receipt.output_id})")
      end

      def processor_list(envelope)
        @processors ||= Processors.discover
        Processors.for_envelope(envelope, processors: @processors)
      end
    end
  end
end
