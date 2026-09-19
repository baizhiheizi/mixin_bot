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

      # The allowed state graph: pending is pre-submission; broadcast means
      # the transaction was submitted; confirmed and failed are terminal;
      # reconciling means a submission outcome was indeterminate.
      TRANSITIONS = {
        'pending' => %w[broadcast failed reconciling],
        'broadcast' => %w[confirmed reconciling],
        'reconciling' => %w[broadcast confirmed failed],
        'confirmed' => [].freeze,
        'failed' => [].freeze
      }.freeze

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
      # Audited state transition through the allowed graph. Never mutate
      # #state directly. Same-state transitions are no-ops (idempotent
      # retries); terminal states (confirmed, failed) never change.
      #
      # @param state [String] target state
      # @param transaction_hash [String, nil] set when the network revealed it
      # @param error [String, nil] set when the transition records a failure
      # @raise [MixinBot::ArgumentError] when the transition is not allowed
      #
      def transition_to!(state, transaction_hash: nil, error: nil)
        state = state.to_s
        return self if state == self.state

        unless TRANSITIONS.fetch(self.state, []).include?(state)
          raise MixinBot::ArgumentError, "illegal transfer transition: #{self.state.inspect} → #{state.inspect}"
        end

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
