# frozen_string_literal: true

require 'test_helper'
require 'mixin_bot/rails'
require 'support/fake_transfer'
require 'digest'
require 'jose'

module MixinBot
  class TransfersModelTest < Minitest::Test
    def setup
      super
      @host = FakeTransfer.new(
        trace_id: 'trace-1', recipient_id: 'user-1',
        asset_id: CNB_ASSET_ID, amount: '1.5', memo: 'payout'
      )
    end

    def teardown
      FakeTransfer.reconciling_records = []
      FakeTransfer.reconcile_hook = nil
      MixinBot.bots.clear
      super
    end

    def test_states_constant_covers_the_state_machine
      assert_equal %w[pending broadcast confirmed failed reconciling], MixinBot::Transfers::Model::STATES
    end

    def test_transition_to_audits_the_previous_state_and_time
      before = Time.now.to_i - 1

      @host.transition_to!('broadcast', transaction_hash: 'aa' * 32)

      assert_equal 'pending', @host.previous_state
      assert_equal 'broadcast', @host.state
      assert_equal 'aa' * 32, @host.transaction_hash
      assert_nil @host.error
      refute_nil @host.transitioned_at
      assert_operator @host.transitioned_at.to_i, :>=, before
    end

    def test_transition_graph_enforced
      legal = MixinBot::Transfers::Model::TRANSITIONS

      legal.each do |from, targets|
        targets.each do |to|
          host = FakeTransfer.new(state: from)
          host.transition_to!(to)
          assert_equal to, host.state, "#{from} → #{to} must be allowed"
        end
      end

      # every non-legal move raises, and terminal states never change
      legal.keys.product(MixinBot::Transfers::Model::STATES).each do |from, to|
        next if legal[from].include?(to) || from == to

        host = FakeTransfer.new(state: from)
        error = assert_raises(MixinBot::ArgumentError, "#{from} → #{to} must be rejected") do
          host.transition_to!(to)
        end
        assert_match(/illegal transfer transition/, error.message)
        assert_equal from, host.state
      end
    end

    def test_same_state_transition_is_a_no_op
      @host.transition_to!('pending')

      assert_equal 'pending', @host.state
      assert_nil @host.previous_state
    end

    def test_transition_can_record_an_error
      @host.transition_to!('failed', error: 'insufficient balance')

      assert_equal 'failed', @host.state
      assert_equal 'insufficient balance', @host.error
    end

    def test_perform_skips_confirmed_transfers
      @host.state = 'confirmed'

      result = @host.perform!

      assert_same @host, result
    end

    def test_perform_refuses_failed_transfers
      @host.state = 'failed'

      error = assert_raises(MixinBot::ArgumentError) { @host.perform! }

      assert_match(/will not be retried/, error.message)
    end

    def test_perform_uses_the_bot_bound_to_the_transfer
      shop = MixinBot.register_bot(:transfer_shop, **registry_credentials('transfer-shop-app-id', 'shop'))
      @host.bot_app_id = 'transfer-shop-app-id'

      assert_same shop, @host.bot_api
    end

    def test_reconcile_pending_iterates_reconciling_records
      @host.state = 'reconciling'
      reconciled = []
      FakeTransfer.reconciling_records = [@host]
      FakeTransfer.reconcile_hook = ->(t) { reconciled << t }

      FakeTransfer.reconcile_pending!

      assert_equal [@host], reconciled
    end

    private

    def registry_credentials(app_id, seed_suffix)
      session_seed = Digest::SHA256.digest("mixin_bot:test:registry:#{seed_suffix}:session")[0, 32]
      spend_seed = Digest::SHA256.digest("mixin_bot:test:registry:#{seed_suffix}:spend")[0, 32]
      session_kp = JOSE::JWA::Ed25519.keypair(session_seed)
      spend_kp = JOSE::JWA::Ed25519.keypair(spend_seed)

      {
        app_id:,
        session_id: app_id,
        session_private_key: session_kp[1].unpack1('H*'),
        server_public_key: session_kp[0].unpack1('H*'),
        spend_key: spend_kp[1].unpack1('H*')
      }
    end
  end
end
