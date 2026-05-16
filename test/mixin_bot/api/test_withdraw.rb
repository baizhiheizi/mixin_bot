# frozen_string_literal: true

require 'test_helper'

module MixinBot
  class TestWithdraw < Minitest::Test
    def setup
    end

    def test_create_withdraw_address
      res = MixinBot.api.create_withdraw_address(
        asset_id: ETH_ASSET_ID,
        pin: PIN_CODE,
        destination: WITHDRAW_ETH_ADDRESS,
        label: 'BigOne'
      )

      assert_equal res['data']['destination'].downcase, WITHDRAW_ETH_ADDRESS.downcase
    end

    def test_create_eos_withdraw_address
      res = MixinBot.api.create_withdraw_address(
        asset_id: EOS_ASSET_ID,
        pin: PIN_CODE,
        destination: WITHDRAW_EOS_ACCOUNT_NAME,
        tag: WITHDRAW_EOS_ACCOUNT_TAG,
        label: 'BigOne'
      )

      assert_equal res['data']['destination'], WITHDRAW_EOS_ACCOUNT_NAME
    end

    def test_get_withdraw_addresses
      address = MixinBot.api.create_withdraw_address(
        asset_id: ETH_ASSET_ID,
        pin: PIN_CODE,
        destination: WITHDRAW_ETH_ADDRESS,
        label: 'BigOne'
      )
      address_id = address['data']['address_id']

      res = MixinBot.api.get_withdraw_address(address_id)

      assert_equal res['data']['destination'].downcase, WITHDRAW_ETH_ADDRESS.downcase
    end

    def test_delete_withdraw_address
      address = MixinBot.api.create_withdraw_address(
        asset_id: ETH_ASSET_ID,
        pin: PIN_CODE,
        destination: WITHDRAW_ETH_ADDRESS,
        label: 'BigOne'
      )
      address_id = address['data']['address_id']

      res = MixinBot.api.delete_withdraw_address(address_id, pin: PIN_CODE)

      assert_nil res['error']
    end
  end
end
