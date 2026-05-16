# frozen_string_literal: true

require 'test_helper'

module MixinBot
  class TestSafePayUrl < Minitest::Test
    def test_generate_safe_pay_url
      res = MixinBot.api.safe_pay_url(
        members: [MixinBot.config.app_id],
        threshold: 1,
        asset_id: CNB_ASSET_ID,
        amount: 0.00000001,
        trace: SecureRandom.uuid,
        memo: 'test from MixinBot'
      )

      assert res.start_with?('https://mixin.one/pay/MIX')
    end
  end
end
