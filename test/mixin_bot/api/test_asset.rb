# frozen_string_literal: true

require 'test_helper'

module MixinBot
  class TestAsset < Minitest::Test
    include WebMock::API

    def test_assets
      r = MixinBot.api.assets

      assert r['data'].is_a?(Array)
    end

    def test_asset
      r = MixinBot.api.asset('965e5c6e-434c-3fa9-b780-c50f43cd955c')
      assert r['data']['asset_id'] == '965e5c6e-434c-3fa9-b780-c50f43cd955c'
    end

    def test_ticker
      r = MixinBot.api.ticker('965e5c6e-434c-3fa9-b780-c50f43cd955c')

      refute_nil r['data']
    end

    def test_safe_fees
      r = MixinBot.api.safe_fees

      assert_requested :get, 'https://api.mixin.one/safe/fees'
      assert r['data'].is_a?(Array)
      assert r['data'].first['fee_amount'].present?
    end

    def test_read_safe_fees_alias
      r = MixinBot.api.read_safe_fees

      assert_requested :get, 'https://api.mixin.one/safe/fees'
      refute_nil r['data']
    end
  end
end
