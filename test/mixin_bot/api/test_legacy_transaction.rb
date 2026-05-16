# frozen_string_literal: true

require 'test_helper'

module MixinBot
  class TestLegacyTransaction < Minitest::Test
    def setup
    end

    def test_transfer_asset_to_multisig
      trace_id = SecureRandom.uuid
      res =
        MixinBot
        .api
        .create_multisig_transaction(
          PIN_CODE,
          asset_id: CNB_ASSET_ID,
          receivers: MULTI_SIGN_MEMBERS,
          threshold: 3,
          amount: 0.00000001,
          memo: 'test from MixinBot',
          trace_id:
        )

      assert_equal res['data']['trace_id'], trace_id
    end

    def test_transfer_asset_to_mainnet
      trace_id = SecureRandom.uuid
      res =
        MixinBot
        .api
        .create_mainnet_transaction(
          PIN_CODE,
          asset_id: CNB_ASSET_ID,
          opponent_id: 'XINRXkrW1CpocUznN5feEBGYtMLku3vRKTZDpT6wFoobYnPhtbdsKjiTp6DPCUHWm8VPrcyaRabGjbxjFR5rWFa9XU77tX6d',
          amount: 0.00000001,
          memo: 'test from MixinBot',
          trace_id:
        )

      assert_equal res['data']['trace_id'], trace_id
    end

    def test_get_public_network_wide_deposit_records
      res = MixinBot.api.transactions
      refute_nil res['data']
    end
  end
end
