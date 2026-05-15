# frozen_string_literal: true

require 'test_helper'

module MixinBot
  class TestUser < Minitest::Test
    def setup
    end

    def test_user
      r = MixinBot.api.user TEST_UID

      assert_equal r['data']['user_id'], TEST_UID
    end

    # def test_create_user
    #   r = MixinBot.api.create_user('Bot User')

    #   assert_equal r['data']['full_name'], 'Bot User'
    # end

    def test_search_user
      r = MixinBot.api.search_user(TEST_MIXIN_ID)

      assert_equal r['data']['identity_number'], TEST_MIXIN_ID
    end

    def test_fetch_users
      r = MixinBot.api.fetch_users([TEST_UID, MixinBot.config.app_id])

      assert r['data'].is_a?(Array)
    end

    # def test_create_safe_user
    #   keystore = MixinBot.api.create_safe_user('Bot User')

    #   # save keystore
    #   File.write("./tmp/#{keystore[:app_id]}-keystore.json", keystore.to_json)

    #   assert keystore.key?(:spend_key)
    # end

    # def test_migrate_to_safe
    #   user = MixinBot.api.create_user 'Test Bot User'

    #   keystore = {
    #     app_id: user['data']['user_id'],
    #     session_id: user['data']['session_id'],
    #     private_key: user[:private_key],
    #     pin_token: user['data']['pin_token_base64']
    #   }

    #   user_api = MixinBot::API.new(**keystore)

    #   spend_keypair = JOSE::JWA::Ed25519.keypair
    #   r = user_api.migrate_to_safe spend_key: spend_keypair[1][0...32]

    #   refute_nil r[:spend_key] = spend_keypair[1].unpack1('H*')
    # end
  end
end
