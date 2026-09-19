# frozen_string_literal: true

module MixinBot
  module Transfers
    ##
    # Resolves a transfer whose send attempt ended indeterminately (timeout
    # or connection loss around the submission):
    #
    # - a snapshot exists for the trace id → the transfer landed; confirm
    #   from the snapshot (no funds ever re-sent);
    # - no snapshot exists → nothing landed; re-send with the same trace id —
    #   the network's trace deduplication makes that safe.
    #
    class Reconcile
      attr_reader :transfer, :api

      def initialize(transfer, api:)
        @transfer = transfer
        @api = api
      end

      ##
      # @return [Symbol] :confirmed, :resent or :failed (definitive rejection
      #   surfaced by the re-send)
      #
      def call
        snapshot = fetch_snapshot_by_trace

        if snapshot
          transfer.transition_to!('confirmed',
                                  transaction_hash: snapshot['transaction_hash'] || transfer.transaction_hash)
          :confirmed
        else
          Performer.new(transfer, api:).perform
          :resent
        end
      end

      private

      # Returns the snapshot hash for the trace id, or nil when the network
      # has none (the only outcome that justifies a re-send).
      def fetch_snapshot_by_trace
        response = api.safe_snapshot_by_trace(transfer.trace_id)
        data = response['data']
        data.is_a?(Hash) && data['snapshot_id'] ? data : nil
      rescue MixinBot::NotFoundError
        nil
      end
    end
  end
end
