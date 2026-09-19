# frozen_string_literal: true

require 'active_support/concern'

module MixinBot
  module Outputs
    ##
    # ActiveRecord concern for the generated +MixinOutput+ receipt model
    # (mixin_bot:outputs generator). Implements the receipt-store interface
    # the poller consumes, on top of the table's unique
    # +(bot_app_id, output_id)+ index:
    #
    #   class MixinOutput < ApplicationRecord
    #     include MixinBot::Outputs::ReceiptModel
    #   end
    #
    # ReceiptModel also registers the model as the processing job's receipt
    # loader and provides cache_snapshot! for the envelope's snapshot bridge.
    #
    # Required columns (see the generated migration): bot_app_id, output_id,
    # amount, asset_id, state, transaction_hash, output_index,
    # output_created_at (the chain timestamp), memo, opponent_id, trace_id,
    # enqueued_at, plus Rails timestamps (created_at backs the sweep query).
    #
    module ReceiptModel
      extend ActiveSupport::Concern

      class_methods do
        # Records the output or reports it as already seen. Uniqueness is
        # enforced by the (bot_app_id, output_id) index, so concurrent pollers
        # race safely.
        def record!(bot_app_id:, output:)
          existing = find_by(bot_app_id:, output_id: output['output_id'])
          return [existing, :duplicate] if existing

          receipt = create!(
            bot_app_id:,
            output_id: output['output_id'],
            amount: output['amount'],
            asset_id: output['asset_id'],
            state: output['state'],
            transaction_hash: output['transaction_hash'],
            output_index: output['output_index'],
            output_created_at: output['created_at']
          )
          [receipt, :created]
        rescue ActiveRecord::RecordNotUnique
          [find_by!(bot_app_id:, output_id: output['output_id']), :duplicate]
        end

        def mark_enqueued!(receipt)
          receipt.update!(enqueued_at: Time.now)
        end

        # created_at is the Rails timestamp (when the receipt row was written),
        # so the sweep's cutoff means "recorded before this moment".
        def unenqueued(bot_app_id:, older_than:)
          where(bot_app_id:, enqueued_at: nil).where(created_at: ...older_than)
        end
      end

      # Caches the envelope's resolved snapshot data (one bridge per output).
      def cache_snapshot!(memo:, opponent_id:, trace_id:)
        update!(memo:, opponent_id:, trace_id:) unless frozen?
      end

      included do
        MixinBot::Outputs.receipt_loader = method(:find)
      end
    end
  end
end
