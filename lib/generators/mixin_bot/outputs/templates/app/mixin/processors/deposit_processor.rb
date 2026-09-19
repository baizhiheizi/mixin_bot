# frozen_string_literal: true

module Mixin
  module Processors
    # Example processor: matches every inbound (unspent) output. Replace the
    # predicate and body with real business rules — processors run in the job
    # queue and enqueue is at-least-once, so key side effects on
    # envelope.output_id to stay idempotent.
    class DepositProcessor < MixinBot::Outputs::Processor
      def self.matches?(envelope)
        !envelope.spent?
      end

      def process
        Rails.logger.info(
          "received #{envelope.amount} of #{envelope.asset_id} (output #{envelope.output_id})"
        )
      end
    end
  end
end
