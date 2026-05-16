# frozen_string_literal: true

require 'test_helper'

module MixinBot
  class TestSnapshot < Minitest::Test
    def setup
    end

    def test_safe_snapshots
      res = MixinBot.api.safe_snapshots limit: 5

      assert_equal res['data'][0]['type'], 'snapshot'
    end

    def test_safe_snapshot_notification
      res =
        MixinBot
        .api
        .create_safe_transfer(
          asset_id: CNB_ASSET_ID,
          members: TEST_UID,
          amount: 0.0011,
          memo: 'test from MixinBot',
          spend_key: SPEND_KEY
        )

      r = MixinBot.api.create_safe_snapshot_notification(
        transaction_hash: res['data'].first['transaction_hash'],
        output_index: 0,
        receiver_id: TEST_UID
      )

      refute_nil r['data']
    end
  end
end
