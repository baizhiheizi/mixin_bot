# frozen_string_literal: true

require 'test_helper'

module MixinBot
  class TestExternal < Minitest::Test
    def test_external_proxy_send_raw_transaction
      raw = MixinApiStubs::RAW_TX_HEX
      res = MixinBot.api.external_proxy(method: 'sendrawtransaction', params: [raw])

      refute_nil res['data']
    end

    def test_external_proxy_get_transaction
      hash = '25bea01c02af130579e44cd878ce0dcfe82d8acb42d5dbaaf96b08735d5f6626'
      res = MixinBot.api.external_proxy(method: 'gettransaction', params: [hash])

      assert_equal hash, res['data']['hash']
    end
  end
end
