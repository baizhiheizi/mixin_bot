# frozen_string_literal: true

require 'test_helper'
require 'digest'
require 'jose'

module MixinBot
  class RegistryTest < Minitest::Test
    def setup
      MixinBot.bots.clear
    end

    def teardown
      MixinBot.bots.clear
    end

    def test_registers_frozen_config_api_under_name
      api = MixinBot.register_bot(:shop, **shop_credentials)

      assert_instance_of MixinBot::API, api
      assert_same api, MixinBot.bot(:shop)
      assert_equal 'shop-app-id', api.config.app_id
      assert_predicate api.config, :frozen?
    end

    def test_registered_bots_hold_separate_configs
      shop = MixinBot.register_bot(:shop, **shop_credentials)
      vault = MixinBot.register_bot(:vault, **vault_credentials)

      refute_equal shop.config.app_id, vault.config.app_id
      refute_same shop.config, vault.config
      assert_equal 'vault-app-id', MixinBot.bot(:vault).config.app_id
    end

    def test_default_api_singleton_is_unchanged
      default_config = MixinBot.config

      MixinBot.register_bot(:shop, **shop_credentials)

      assert_same default_config, MixinBot.config
      refute_same MixinBot.bot(:shop).config, default_config
      refute_predicate default_config, :frozen?
      assert_equal OfflineConfig.app_id, MixinBot.config.app_id
    end

    def test_accepts_string_names
      api = MixinBot.register_bot('shop', **shop_credentials)

      assert_same api, MixinBot.bot(:shop)
    end

    def test_duplicate_registration_raises
      MixinBot.register_bot(:shop, **shop_credentials)

      error = assert_raises(MixinBot::ArgumentError) do
        MixinBot.register_bot(:shop, **vault_credentials)
      end

      assert_match(/already registered/, error.message)
    end

    def test_empty_credentials_are_rejected
      error = assert_raises(MixinBot::ArgumentError) do
        MixinBot.register_bot(:ghost)
      end

      assert_match(/requires bot credentials/, error.message)
    end

    def test_unknown_bot_raises_key_error
      error = assert_raises(KeyError) do
        MixinBot.bot(:nowhere)
      end

      assert_match(/nowhere/, error.message)
    end

    private

    def credentials_for(app_id, seed_suffix)
      session_seed = Digest::SHA256.digest("mixin_bot:test:registry:#{seed_suffix}:session")[0, 32]
      spend_seed = Digest::SHA256.digest("mixin_bot:test:registry:#{seed_suffix}:spend")[0, 32]
      session_kp = JOSE::JWA::Ed25519.keypair(session_seed)
      spend_kp = JOSE::JWA::Ed25519.keypair(spend_seed)

      {
        app_id:,
        session_id: app_id,
        session_private_key: session_kp[1].unpack1('H*'),
        server_public_key: session_kp[0].unpack1('H*'),
        spend_key: spend_kp[1].unpack1('H*')
      }
    end

    def shop_credentials
      credentials_for 'shop-app-id', 'shop'
    end

    def vault_credentials
      credentials_for 'vault-app-id', 'vault'
    end
  end
end
