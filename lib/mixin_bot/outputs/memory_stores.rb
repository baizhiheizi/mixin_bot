# frozen_string_literal: true

module MixinBot
  module Outputs
    ##
    # In-memory receipt store: the dedup gate + enqueue bookkeeping the poller
    # needs, backed by nothing but a Hash. Used by the offline test suite and
    # available for non-ActiveRecord hosts; Rails applications use the
    # generated +MixinOutput+ model (see {ReceiptModel}), which implements the
    # same interface:
    #
    #   record!(bot_app_id:, output:)   # => [receipt, :created] or
    #                                   #    [existing, :duplicate]
    #   mark_enqueued!(receipt)         # stamp the receipt as dispatched
    #   unenqueued(bot_app_id:, older_than:) # records not yet dispatched
    #
    class MemoryReceiptStore
      ##
      # A receipt row: the poller's dedup + cache record for one output.
      # Field names match the generated +mixin_outputs+ table columns.
      #
      Receipt = Struct.new(
        :id, :bot_app_id, :output_id, :amount, :asset_id, :state,
        :transaction_hash, :output_index, :created_at,
        :memo, :opponent_id, :trace_id,
        :enqueued_at, :recorded_at,
        keyword_init: true
      ) do
        # Writes resolved snapshot data back onto the receipt (one-time cache).
        def cache_snapshot!(memo:, opponent_id:, trace_id:)
          self.memo = memo
          self.opponent_id = opponent_id
          self.trace_id = trace_id
        end
      end

      def initialize(clock: -> { Time.now })
        @records = {}
        @sequence = 0
        @clock = clock
      end

      def record!(bot_app_id:, output:)
        key = [bot_app_id, output['output_id']]
        existing = @records[key]
        return [existing, :duplicate] if existing

        @sequence += 1
        receipt = Receipt.new(
          id: @sequence,
          bot_app_id:,
          output_id: output['output_id'],
          amount: output['amount'],
          asset_id: output['asset_id'],
          state: output['state'],
          transaction_hash: output['transaction_hash'],
          output_index: output['output_index'],
          created_at: output['created_at'],
          recorded_at: @clock.call
        )
        @records[key] = receipt
        [receipt, :created]
      end

      def mark_enqueued!(receipt)
        receipt.enqueued_at = @clock.call
      end

      def unenqueued(bot_app_id:, older_than:)
        @records.values.select do |receipt|
          receipt.bot_app_id == bot_app_id &&
            receipt.enqueued_at.nil? &&
            receipt.recorded_at < older_than
        end
      end
    end

    ##
    # In-memory cursor store: remembers, per bot app id, the last processed
    # output position (the outputs API's own created_at value). The generated
    # +MixinPollerCursor+ model (see {CursorModel}) implements the same
    # interface durably:
    #
    #   value(bot_app_id:)          # => String or nil
    #   advance!(bot_app_id:, value:)
    #
    class MemoryCursorStore
      def initialize
        @values = {}
      end

      def value(bot_app_id:)
        @values[bot_app_id]
      end

      def advance!(bot_app_id:, value:)
        @values[bot_app_id] = value
      end
    end
  end
end
