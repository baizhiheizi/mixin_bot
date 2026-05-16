# frozen_string_literal: true

require 'test_helper'

module MixinBot
  class TestTransfer < Minitest::Test
    def setup
    end

    def test_safe_transfer_asset_to_user
      request_id = SecureRandom.uuid
      res =
        MixinBot
        .api
        .create_safe_transfer(
          asset_id: CNB_ASSET_ID,
          members: TEST_UID,
          amount: 0.001,
          memo: 'test from MixinBot',
          request_id:,
          spend_key: SPEND_KEY
        )

      assert_equal res.dig('data', 0, 'request_id'), request_id
    end
  end
end
