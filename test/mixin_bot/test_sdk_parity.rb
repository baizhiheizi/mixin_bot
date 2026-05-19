# frozen_string_literal: true

require 'test_helper'

module MixinBot
  class TestSdkParity < Minitest::Test
    def test_url_scheme_users
      url = UrlScheme.scheme_users(TEST_UID)
      assert_includes url, 'mixin://users/'
    end

    def test_unique_object_id
      id = MixinBot.utils.unique_object_id('a', 'b')
      assert_match(/\A[0-9a-f-]{36}\z/i, id)
    end

    def test_generate_user_checksum
      sum = MixinBot.utils.generate_user_checksum([{ 'session_id' => 'bbb' }, { 'session_id' => 'aaa' }])
      assert_equal 32, sum.length
    end

    def test_chain_name
      api = MixinBot::API.new
      assert_equal 'Bitcoin', api.chain_name('c6d0c728-2624-429b-8e0d-d9d19b6592fa')
    end

    def test_tip_body_for_withdrawal
      api = MixinBot::API.new
      body = api.tip_body_for_withdrawal_create('addr', '1', '0', SecureRandom.uuid, 'm')
      assert body.start_with?('TIP:WITHDRAWAL:CREATE:')
    end

    def test_fetch_user_sessions_stub
      res = MixinBot.api.fetch_user_sessions([TEST_UID])
      assert res['data'].is_a?(Array)
    end

    def test_pending_safe_deposits_stub
      res = MixinBot.api.pending_safe_deposits
      assert res['data'].is_a?(Array)
    end

    def test_network_asset_stub
      res = MixinBot.api.network_asset(CNB_ASSET_ID)
      assert_equal CNB_ASSET_ID, res['data']['asset_id']
    end

    def test_build_occupy_transaction_extra
      utxos = MixinBot.api.safe_outputs(state: 'unspent', asset: MixinBot::API::Transaction::XIN_ASSET_ID, limit: 1)['data']
      skip 'no utxos in stub' if utxos.empty?

      tx = MixinBot.api.build_occupy_transaction(
        amount: '0.0001',
        inscription_hash: 'aa' * 32,
        sequence: 1,
        utxos:
      )
      extra = JSON.parse(tx[:extra])
      assert_equal 'occupy', extra['operation']
      assert_equal 1, extra['sequence']
    end
  end
end
