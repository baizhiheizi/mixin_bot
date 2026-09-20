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
    # Including the model also registers it as the integration's receipt
    # store (the mixin_bot:poller rake task) and as the processing job's
    # receipt loader. The poller's resume cursor is derived from the receipts
    # themselves — the newest output sequence per bot — so there is no
    # separate cursor table.
    #
    # Required columns (see the generated migration): bot_app_id, output_id,
    # amount, asset_id, state, transaction_hash, output_index, sequence
    # (the outputs API's pagination key — the poller's cursor), memo,
    # opponent_id, trace_id, snapshot_bridged, enqueued_at, plus Rails
    # timestamps (created_at backs the sweep query).
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

        # The poller's resume position: the newest output sequence recorded
        # for this bot — unique and monotonic, and the key the outputs API
        # paginates on (nil = fetch from the beginning). Derived from the
        # receipts themselves — no separate cursor state.
        def cursor_value(bot_app_id:)
          where(bot_app_id:).maximum(:sequence)
        end
      end

      # Caches the envelope's resolved snapshot data (one bridge attempt per
      # output — including failures, which cache nils and the flag).
      def cache_snapshot!(memo:, opponent_id:, trace_id:)
        update!(memo:, opponent_id:, trace_id:, snapshot_bridged: true) unless frozen?
      end

      included do
        MixinBot::Outputs.receipt_loader = method(:find)
        MixinBot::Outputs.receipt_store = self
      end
    end
  end
end
