# frozen_string_literal: true

require 'test_helper'

module MixinBot
  class TestLegacyTransfer < Minitest::Test
    def setup
    end

    def test_transfer_asset_to_user
      trace_id = SecureRandom.uuid
      res =
        MixinBot
        .api
        .create_transfer(
          PIN_CODE,
          asset_id: CNB_ASSET_ID,
          opponent_id: TEST_UID,
          amount: 0.00000001,
          memo: 'test from MixinBot',
          trace_id:
        )

      assert_equal res['data']['trace_id'], trace_id
    end

    def test_transfer
      snapshots = MixinBot.api.snapshots['data']

      trace_id = snapshots.first['trace_id']
      res = MixinBot.api.transfer(trace_id)

      assert_equal res['data']['trace_id'], trace_id
    end
  end
end
