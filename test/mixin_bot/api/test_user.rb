# frozen_string_literal: true

require 'test_helper'

module MixinBot
  class TestUser < Minitest::Test
    include WebMock::API

    def setup
      WebMock.reset!
      MixinApiStubs.register!
    end

    def test_user
      r = MixinBot.api.user TEST_UID

      assert_equal r['data']['user_id'], TEST_UID
    end

    def test_search_user
      r = MixinBot.api.search_user TEST_MIXIN_ID

      assert_equal r['data']['identity_number'], TEST_MIXIN_ID
    end

    def test_fetch_users
      r = MixinBot.api.fetch_users([TEST_UID, MixinBot.config.app_id])

      assert r['data'].is_a?(Array)
    end

    def test_create_user_sufficient_headroom
      AppBillingStubState.configure credit: '100', cost_users: '50', cost_resources: '10', price: '0.5'

      r = MixinBot.api.create_user 'Bot User'

      assert_equal 'Bot User', r['data']['full_name']
      assert r[:private_key].present?
      assert_requested :post, %r{api\.mixin\.one/users\z}
    end

    def test_create_user_insufficient_headroom
      AppBillingStubState.configure credit: '60', cost_users: '50', cost_resources: '10', price: '0.5'

      err = assert_raises InsufficientAppBillingError do
        MixinBot.api.create_user 'Bot User'
      end

      assert_equal MixinBot.config.app_id, err.app_id
      assert_equal BigDecimal('60'), BigDecimal(err.credit)
      assert_equal BigDecimal('60'), BigDecimal(err.cost)
      assert_equal BigDecimal('0.5'), BigDecimal(err.increment)
      assert_not_requested :post, %r{api\.mixin\.one/users\z}
    end

    def test_create_user_free_tier_zero_increment
      AppBillingStubState.configure credit: '10', cost_users: '5', cost_resources: '4'

      r = MixinBot.api.create_user 'Free Tier User', increment: 0

      assert_equal 'Free Tier User', r['data']['full_name']
      assert_requested :post, %r{api\.mixin\.one/users\z}
    end

    def test_create_user_edge_equality_blocked
      AppBillingStubState.configure credit: '60.5', cost_users: '50', cost_resources: '10', price: '0.5'

      assert_raises InsufficientAppBillingError do
        MixinBot.api.create_user 'Edge User'
      end
      assert_not_requested :post, %r{api\.mixin\.one/users\z}
    end

    def test_create_user_force_skips_preflight
      AppBillingStubState.configure credit: '0', cost_users: '100', cost_resources: '0', price: '0.5'

      r = MixinBot.api.create_user 'Forced User', force: true

      assert_equal 'Forced User', r['data']['full_name']
      assert_requested :post, %r{api\.mixin\.one/users\z}
    end
  end
end
