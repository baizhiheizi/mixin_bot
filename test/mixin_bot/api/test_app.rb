# frozen_string_literal: true

require 'test_helper'

module MixinBot
  class TestApp < Minitest::Test
    def setup
      @opponent_app_id = 'c1412f68-6152-40ad-a193-f7fadf9328a1'
    end

    def test_add_favorite_app
      r = MixinBot.api.add_favorite_app @opponent_app_id

      refute_nil r['data']
    end

    def test_remove_favorite_app
      r = MixinBot.api.remove_favorite_app @opponent_app_id

      refute_nil r['data']
    end

    def test_favorite_apps
      r = MixinBot.api.favorite_apps

      assert r['data'].is_a?(Array)
    end

    def test_app
      r = MixinBot.api.app(MixinBot.config.app_id)
      assert_equal MixinBot.config.app_id, r['data']['app_id']
    end

    def test_apps
      r = MixinBot.api.apps
      assert r['data'].is_a?(Array)
    end

    def test_app_properties
      r = MixinBot.api.app_properties
      refute_nil r['data']['count']
    end

    def test_app_billing
      r = MixinBot.api.app_billing(MixinBot.config.app_id)
      assert_equal MixinBot.config.app_id, r['data']['app_id']
    end

    def test_create_and_update_app
      created = MixinBot.api.create_app(name: 'New App', redirect_uri: 'https://example.com', home_uri: 'https://example.com')
      app_id = created['data']['app_id']
      refute_nil app_id

      updated = MixinBot.api.update_app(app_id, name: 'Updated App')
      assert_equal 'Updated App', updated['data']['name']
    end

    def test_rotate_app_secret
      r = MixinBot.api.rotate_app_secret(MixinBot.config.app_id)
      refute_nil r['data']['app_secret']
    end

    def test_update_app_safe_session
      r = MixinBot.api.update_app_safe_session(MixinBot.config.app_id, session_public_key: 'aa' * 32)
      refute_nil r['data']['session_id']
    end

    def test_register_app_safe
      r = MixinBot.api.register_app_safe(
        MixinBot.config.app_id,
        spend_public_key: 'bb' * 32,
        signature_base64: 'cc'
      )
      refute_nil r['data']['spend_public_key']
    end
  end
end
