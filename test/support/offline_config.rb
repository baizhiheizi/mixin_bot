# frozen_string_literal: true

require 'digest'
require 'jose'

module OfflineConfig
  module_function

  def app_id
    'aaaaaaaa-bbbb-4ccc-dddd-eeeeeeeeeeee'
  end

  def session_id
    'bbbbbbbb-bbbb-4ccc-dddd-ffffffffffff'
  end

  def session_private_key_hex
    seed = Digest::SHA256.digest('mixin_bot:test:session:v2')[0, 32]
    kp = JOSE::JWA::Ed25519.keypair(seed)
    kp[1].unpack1('H*')
  end

  def server_public_key_hex
    seed = Digest::SHA256.digest('mixin_bot:test:session:v2')[0, 32]
    kp = JOSE::JWA::Ed25519.keypair(seed)
    kp[0].unpack1('H*')
  end

  def spend_key_hex
    seed = Digest::SHA256.digest('mixin_bot:test:spend:v2')[0, 32]
    kp = JOSE::JWA::Ed25519.keypair(seed)
    kp[1].unpack1('H*')
  end

  def apply!
    MixinBot.configure do
      self.app_id = OfflineConfig.app_id
      self.session_id = OfflineConfig.session_id
      self.session_private_key = OfflineConfig.session_private_key_hex
      self.server_public_key = OfflineConfig.server_public_key_hex
      self.client_secret = 'offline-test-client-secret'
      self.spend_key = OfflineConfig.spend_key_hex
      self.pin = '123456'
    end
  end
end
