# frozen_string_literal: true

module MixinBot
  module Transfers
    ##
    # Executes the Safe pipeline for one transfer record:
    # build_utxos → build_safe_transaction → verify → sign → send, with the
    # transfer's trace id as the request id, so network-side deduplication
    # makes every retry safe.
    #
    # Outcome mapping:
    # - success → broadcast (transaction hash stored), then confirmed when the
    #   submission response carries the hash (it normally does);
    # - definitive API rejection (insufficient funds, invalid request, ...) →
    #   failed — never retried;
    # - indeterminate network outcome (timeout/connection loss around the
    #   submission) → reconciling — {Reconcile} resolves it.
    #
    class Performer
      # Indeterminate-outcome network errors: the submission may or may not
      # have landed, so the transfer goes to reconciling rather than failed.
      NETWORK_ERRORS = [Faraday::Error, SocketError, Errno::ETIMEDOUT, Timeout::Error].freeze

      attr_reader :transfer, :api

      def initialize(transfer, api:)
        @transfer = transfer
        @api = api
      end

      ##
      # Runs the pipeline and records the outcome. Re-raises unexpected
      # (non-API, non-network) errors — those are bugs, left to the job
      # backend's retry policy, with the transfer still in its prior state.
      #
      # @return [MixinBot::Transfers::Performer]
      #
      def perform
        response = api.create_safe_transfer(
          asset_id: transfer.asset_id,
          amount: transfer.amount.to_d,
          members: [transfer.recipient_id],
          memo: transfer.memo.to_s,
          trace_id: transfer.trace_id
        )

        data = response['data']
        data = data.first if data.is_a?(Array)
        data ||= {}

        transfer.transition_to!('broadcast', transaction_hash: data['transaction_hash'])
        transfer.transition_to!('confirmed', transaction_hash: data['transaction_hash']) if data['transaction_hash']
        self
      rescue MixinBot::APIError => e
        transfer.transition_to!('failed', error: "#{e.class}: #{e.message}")
        self
      rescue Faraday::Error, SocketError, Errno::ETIMEDOUT, Timeout::Error => e
        Transfers.logger.call(:indeterminate, "#{e.class}: #{e.message} (trace #{transfer.trace_id})")
        transfer.transition_to!('reconciling', error: "#{e.class}: #{e.message}")
        self
      end
    end
  end
end
