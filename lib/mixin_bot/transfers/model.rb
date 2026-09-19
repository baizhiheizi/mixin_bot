# frozen_string_literal: true

require 'active_support/concern'

module MixinBot
  module Transfers
    ##
    # ActiveRecord concern for the generated +MixinTransfer+ model
    # (mixin_bot:transfers generator): the transfer ledger's state machine and
    # its execution entry points.
    #
    #   class MixinTransfer < ApplicationRecord
    #     include MixinBot::Transfers::Model
    #   end
    #
    #   transfer = MixinTransfer.create!(
    #     recipient_id: user_id, asset_id: ASSET, amount: '1.5',
    #     memo: 'payout', trace_id: SecureRandom.uuid
    #   )
    #   transfer.perform!                      # executes the Safe pipeline
    #   transfer.reconcile!                    # resolves unknown outcomes
    #   MixinTransfer.reconcile_pending!       # recurring-job entry point
    #
    # Required columns (see the generated migration): recipient_id, asset_id,
    # amount, memo, trace_id (unique), state (default 'pending'),
    # previous_state, transaction_hash, error, transitioned_at, bot_app_id
    # (nil = the default bot), plus Rails timestamps.
    #
    module Model
      extend ActiveSupport::Concern

      STATES = %w[pending broadcast confirmed failed reconciling].freeze

      included do
        validates :trace_id, presence: true, uniqueness: true
        validates :recipient_id, :asset_id, :amount, presence: true
        validates :state, inclusion: { in: STATES }
      end

      class_methods do
        # Recurring-job entry point: resolve every transfer whose send attempt
        # ended indeterminately (timeout after submission).
        def reconcile_pending!
          reconciling.find_each(&:reconcile!)
        end
      end

      ##
      # Audited state transition. Never mutate #state directly.
      #
      # @param state [String] target state
      # @param transaction_hash [String, nil] set when the network revealed it
      # @param error [String, nil] set when the transition records a failure
      #
      def transition_to!(state, transaction_hash: nil, error: nil)
        update!(
          previous_state: self.state,
          state:,
          transaction_hash: transaction_hash || self.transaction_hash,
          error:,
          transitioned_at: Time.now
        )
      end

      ##
      # Executes the Safe pipeline for this transfer (idempotent per trace
      # id). Definitive rejections mark the transfer failed; indeterminate
      # network outcomes mark it reconciling. {Reconcile} resolves those.
      #
      def perform!
        return self if state == 'confirmed'
        raise MixinBot::ArgumentError, "transfer #{trace_id} is failed and will not be retried" if state == 'failed'

        Performer.new(self, api: bot_api).perform
      end

      ##
      # Resolves an indeterminate outcome: confirm from the trace's snapshot,
      # or re-send with the same trace id (safe — the network deduplicates).
      #
      def reconcile!
        Reconcile.new(self, api: bot_api).call
      end

      # The API client bound to this transfer's bot (bot_app_id or default).
      def bot_api
        MixinBot.bot_by_app_id(bot_app_id) || MixinBot.api
      end
    end
  end
end
