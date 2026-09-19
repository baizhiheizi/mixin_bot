# frozen_string_literal: true

require 'bigdecimal'

module MixinBot
  module Outputs
    ##
    # Application-facing view of one Mixin output (a transfer touching the
    # bot's Safe UTXO set — inbound or outbound).
    #
    # The output stream itself carries amount/asset/state but no memo; the
    # memo, counterparty, and trace id are bridged lazily — at most once per
    # output — through the snapshot notification API
    # (+create_safe_snapshot_notification+). A failed bridge logs a warning
    # and yields nil fields; processing continues without them.
    #
    # Wraps a receipt record (the poller's dedup row): output fields are read
    # from it and resolved snapshot data is cached back onto it. Receipt-like
    # objects must expose:
    #   output_id, amount (String), asset_id, state, transaction_hash,
    #   output_index, memo, opponent_id, trace_id
    #   snapshot_bridged?            # bridge already attempted (success or not)
    #   cache_snapshot!(memo:, opponent_id:, trace_id:)  # write-back
    #
    #   envelope.amount        # => BigDecimal
    #   envelope.memo          # => String or nil (bridged on first access)
    #   envelope.spent?        # => true when the output is spent
    #
    class Envelope
      attr_reader :receipt, :api

      ##
      # @param receipt [Object] receipt record backing this envelope
      # @param api [MixinBot::API] bot client used for the snapshot bridge
      #
      def initialize(receipt, api:)
        @receipt = receipt
        @api = api
      end

      def output_id
        receipt.output_id
      end

      # The output's amount as a BigDecimal.
      def amount
        BigDecimal(receipt.amount.to_s)
      end

      def asset_id
        receipt.asset_id
      end

      def transaction_hash
        receipt.transaction_hash
      end

      def output_index
        receipt.output_index
      end

      # True when the output is spent (outbound from the bot's perspective).
      def spent?
        receipt.state == 'spent'
      end

      def state
        receipt.state
      end

      ##
      # Snapshot-derived memo; nil when the bridge failed or the snapshot has
      # no memo. Bridged at most once per output.
      #
      def memo
        bridge_snapshot.memo
      end

      # Snapshot-derived counterparty user id; nil on bridge failure.
      def opponent_id
        bridge_snapshot.opponent_id
      end

      # Snapshot-derived trace id (the sender's idempotency trace); nil on
      # bridge failure.
      def trace_id
        bridge_snapshot.trace_id
      end

      private

      # Returns the memo/opponent/trace triple after a single bridge attempt.
      # Receipts whose bridge already ran (success OR failure — the flag is
      # written in both cases) short-circuit the API call, so each output is
      # bridged at most once per receipt lifetime, not just per Envelope.
      def bridge_snapshot
        return @bridge_snapshot if defined?(@bridge_snapshot)

        if receipt.respond_to?(:snapshot_bridged?) && receipt.snapshot_bridged?
          return Snapshot.new(memo: receipt.memo, opponent_id: receipt.opponent_id,
                              trace_id: receipt.trace_id, bridged: true)
        end

        fetch_snapshot
      end

      def fetch_snapshot
        response = api.create_safe_snapshot_notification(
          transaction_hash: receipt.transaction_hash,
          output_index: receipt.output_index,
          receiver_id: api.config.app_id
        )

        snapshot = response['data'].is_a?(Hash) ? response['data'] : {}

        fields = Snapshot.new(
          memo: snapshot['memo'],
          opponent_id: snapshot['opponent_id'],
          trace_id: snapshot['trace_id'],
          bridged: true
        )

        if receipt.respond_to?(:cache_snapshot!)
          receipt.cache_snapshot!(
            memo: fields.memo,
            opponent_id: fields.opponent_id,
            trace_id: fields.trace_id
          )
        end

        fields
      rescue StandardError => e
        MixinBot::Outputs.logger.call(:snapshot_bridge_error,
                                      "#{e.class}: #{e.message} (output #{receipt.output_id})")
        # Mark the attempt even on failure so later jobs don't re-POST.
        receipt.cache_snapshot!(memo: nil, opponent_id: nil, trace_id: nil) if receipt.respond_to?(:cache_snapshot!)
        Snapshot.new(memo: nil, opponent_id: nil, trace_id: nil, bridged: false)
      end

      # Immutable triple of bridged snapshot fields.
      Snapshot = Struct.new(:memo, :opponent_id, :trace_id, keyword_init: true) do
        def initialize(bridged:, memo: nil, opponent_id: nil, trace_id: nil)
          super(memo:, opponent_id:, trace_id:)
          @bridged = bridged
        end

        def bridged?
          @bridged
        end
      end
    end
  end
end
