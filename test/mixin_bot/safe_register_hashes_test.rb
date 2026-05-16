# frozen_string_literal: true

require 'test_helper'

module MixinBot
  class SafeRegisterHashesTest < Minitest::Test
    FIXTURE = File.expand_path('../fixtures/golden/safe_register_hashes.json', __dir__)

    def setup
      @j = JSON.parse(File.read(FIXTURE))
    end

    def test_app_id_digest_is_sha3_256_not_sha256
      app_id = @j['app_id']
      sha3 = SHA3::Digest::SHA256.hexdigest(app_id)
      sha256 = Digest::SHA256.hexdigest(app_id)

      assert_equal @j['expected_app_id_sha3_hex'], sha3
      assert_equal @j['expected_sha256_of_app_id_hex'], sha256
      refute_equal sha3, sha256
    end

    def test_sequencer_register_tip_body_uses_sha256_of_concatenated_string
      app_id = @j['app_id']
      pub = @j['expected_public_key_hex']
      preimage = "SEQUENCER:REGISTER:#{app_id}#{pub}"
      tip_digest = Digest::SHA256.hexdigest(preimage)

      assert_equal @j['expected_sequencer_register_tip_sha256_hex'], tip_digest
      refute_equal @j['expected_app_id_sha3_hex'], tip_digest
    end

    def test_fixture_public_key_matches_ed25519_keypair_from_seed
      seed = [@j['spend_key_seed_hex']].pack('H*')
      kp = JOSE::JWA::Ed25519.keypair(seed[...32])
      assert_equal @j['expected_public_key_hex'], kp[0].unpack1('H*')
    end
  end
end
