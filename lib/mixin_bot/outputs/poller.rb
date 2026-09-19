# frozen_string_literal: true

module MixinBot
  module Outputs
    ##
    # The polling loop: fetches a page of the bot's outputs oldest-first,
    # records unseen outputs in the receipt store (the dedup gate), enqueues
    # every matching processor through the job queue, and advances the cursor
    # only after the whole page is absorbed — so a mid-page failure re-fetches
    # the page and receipts absorb the overlap.
    #
    # Each loop iteration first sweeps receipts that were recorded but never
    # dispatched (a crash between the two steps), re-evaluating predicates and
    # enqueueing late — making dispatch at-least-once.
    #
    # All collaborators are injectable for offline testing: sleeper, clock,
    # stores, processor list, and the enqueue hook. {#run} blocks until {#stop};
    # signal wiring is the process's job (the mixin_bot:poller rake task).
    #
    #   poller = Poller.new(api: MixinBot.bot(:shop), interval: 5)
    #   trap('TERM') { poller.stop }
    #   poller.run
    #
    class Poller
      DEFAULT_INTERVAL = 5
      DEFAULT_PAGE_SIZE = 500

      attr_reader :api, :receipts, :cursor, :interval, :page_size

      ##
      # @param api [MixinBot::API] the bot whose outputs are polled
      # @param receipts [#record!, #mark_enqueued!, #unenqueued] receipt store
      #   (default: in-memory; Rails hosts pass their MixinOutput model)
      # @param cursor [#value, #advance!] cursor store keyed by bot app id
      # @param processors [Array<Class>, nil] processor classes; nil discovers
      #   them from the Mixin::Processors namespace on first use
      # @param interval [Numeric] seconds between fetch cycles
      # @param page_size [Integer] outputs fetched per cycle
      # @param state [String] output state filter ('' = all states, covering
      #   inbound unspent outputs and outbound spent ones)
      # @param enqueuer [#call, nil] called with (processor_class, receipt);
      #   defaults to ProcessingJob.perform_later
      # @param sleeper [#call, nil] called with seconds between cycles
      # @param clock [#call, nil] returns current Time (sweep bookkeeping)
      # @param logger [#call, nil] called with (level, detail)
      #
      # The collaborator-injection surface is the design (see the @param docs).
      # rubocop:disable-next Metrics/ParameterLists
      def initialize(api: MixinBot.api, receipts: MemoryReceiptStore.new, cursor: MemoryCursorStore.new,
                     processors: nil, interval: DEFAULT_INTERVAL, page_size: DEFAULT_PAGE_SIZE, state: '',
                     enqueuer: nil, sleeper: nil, clock: nil, logger: nil)
        @api = api
        @bot_app_id = api.config.app_id
        @receipts = receipts
        @cursor = cursor
        @processors = processors
        @interval = interval
        @page_size = page_size
        @state = state
        @enqueuer = enqueuer || ->(processor, receipt) { ProcessingJob.perform_later(receipt.id, processor.name) }
        @sleeper = sleeper || ->(seconds) { sleep seconds }
        @clock = clock || -> { Time.now }
        @logger = logger || Outputs.logger
        @stopping = false
      end

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

        last = page.last
        @cursor.advance!(bot_app_id: @bot_app_id, value: last['created_at']) if last
        page.size
      end

      private

      def sweep_undispatched
        cutoff = @clock.call - @interval
        @receipts.unenqueued(bot_app_id: @bot_app_id, older_than: cutoff).each do |receipt|
          dispatch(Envelope.new(receipt, api: @api), receipt)
        end
      end

      def fetch_page
        response = @api.safe_outputs(state: @state, limit: @page_size,
                                     offset: @cursor.value(bot_app_id: @bot_app_id).to_s, order: 'ASC')
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
