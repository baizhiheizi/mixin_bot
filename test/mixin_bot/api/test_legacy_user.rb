# frozen_string_literal: true

require 'test_helper'
require 'openssl'

module MixinBot
  class TestLegacyUser < Minitest::Test
    include WebMock::API

    def setup
      WebMock.reset!
      MixinApiStubs.register!

      @rsa = OpenSSL::PKey::RSA.new(2048)
      @session_id = SecureRandom.uuid
      # 32 bytes of "random" key material — large enough to be a real AES-256 key.
      @plaintext = SecureRandom.random_bytes(32)
      @pin = '123456'

      # Encrypt with the same OAEP parameters the production code uses to decrypt.
      # In Ruby 4.0, the keyword form `public_encrypt(..., rsa_padding_mode:)`
      # and `oaep_label:` (underscore) are no longer recognized. Use the
      # modern `encrypt` method with string keys; the OAEP label is passed as
      # `'oaep-label'` (dash, not underscore) which the underlying OpenSSL
      # EVP_PKEY_CTX accepts.
      @pin_token = Base64.strict_encode64(
        @rsa.encrypt(
          @plaintext,
          'rsa_padding_mode' => 'oaep',
          'rsa_oaep_md' => 'sha256',
          'rsa_mgf1_md' => 'sha1',
          'oaep-label' => @session_id
        )
      )

      @keystore = {
        pin: @pin,
        session_id: @session_id,
        pin_token: @pin_token,
        private_key: @rsa.to_pem
      }

      @captured_request = nil
      stub_legacy_users_with_capture
    end

    def test_upgrade_legacy_user_posts_to_legacy_users_path
      MixinBot.api.upgrade_legacy_user(@keystore)

      refute_nil @captured_request, 'expected POST to /legacy/users'
      assert_equal '/legacy/users', @captured_request.uri.path
    end

    def test_upgrade_legacy_user_uses_post_method
      MixinBot.api.upgrade_legacy_user(@keystore)

      refute_nil @captured_request
      assert_equal :post, @captured_request.method
    end

    def test_upgrade_legacy_user_sends_session_id_in_payload
      MixinBot.api.upgrade_legacy_user(@keystore)

      body = captured_payload
      assert_equal @session_id, body['session_id']
    end

    def test_upgrade_legacy_user_sends_required_payload_keys
      MixinBot.api.upgrade_legacy_user(@keystore)

      body = captured_payload
      assert_kind_of String, body['session_secret_legacy']
      assert_kind_of String, body['session_secret']
      assert_kind_of String, body['pin']
    end

    def test_upgrade_legacy_user_session_secret_is_43_char_urlsafe_base64
      MixinBot.api.upgrade_legacy_user(@keystore)

      body = captured_payload
      # urlsafe-base64 without padding of 32-byte Ed25519 verify key => 43 chars.
      assert_equal 43, body['session_secret'].length
      assert_match(/\A[A-Za-z0-9_-]+\z/, body['session_secret'])
    end

    def test_upgrade_legacy_user_pin_payload_is_urlsafe_base64
      MixinBot.api.upgrade_legacy_user(@keystore)

      assert_match(/\A[A-Za-z0-9_-]+\z/, captured_payload['pin'])
    end

    def test_upgrade_legacy_user_pin_ciphertext_decrypts_to_pin_plus_timestamp
      before = Time.now.to_i
      MixinBot.api.upgrade_legacy_user(@keystore)
      after = Time.now.to_i

      raw = Base64.urlsafe_decode64(captured_payload['pin'])

      # IV (16 bytes) + AES-256-CBC ciphertext. Plaintext is 6-byte PIN + 8-byte
      # timestamp + 8-byte zero + PKCS#7 padding to a 16-byte boundary (32 bytes),
      # then OpenSSL CBC adds another padding block => 48-byte ciphertext + IV.
      assert raw.length.between?(48, 64),
             "expected pin ciphertext to be 48..64 bytes, got #{raw.length}"

      cipher = OpenSSL::Cipher.new('AES-256-CBC')
      cipher.decrypt
      cipher.key = @plaintext
      cipher.iv = raw[0, 16]
      plaintext = cipher.update(raw[16..]) + cipher.final

      # First 6 bytes are the PIN; next 8 bytes are the timestamp (Q<).
      assert_equal @pin.b, plaintext[0, 6]
      ts = plaintext[6, 8].unpack1('Q<')
      assert ts.between?(before, after), "expected timestamp between #{before} and #{after}, got #{ts}"

      # Next 8 bytes are a zero counter.
      assert_equal [0].pack('Q<'), plaintext[14, 8]

      # Last N bytes are PKCS#7 padding (1..16).
      pad = plaintext[-1].ord
      assert pad.between?(1, 16)
      assert_equal pad.chr * pad, plaintext[-pad..]
    end

    def test_upgrade_legacy_user_returns_session_private_key
      result = MixinBot.api.upgrade_legacy_user(@keystore)

      assert_kind_of String, result['data']['session_private_key']
      assert_equal 64, result['data']['session_private_key'].length
      assert_match(/\A[0-9a-f]{64}\z/, result['data']['session_private_key'])
    end

    def test_upgrade_legacy_user_session_private_key_matches_ed25519_seed
      result = MixinBot.api.upgrade_legacy_user(@keystore)

      seed = [result['data']['session_private_key']].pack('H*')
      assert_equal 32, seed.length
      # SHA-512 of the RSA private key DER, first 32 bytes.
      expected_seed = Digest::SHA512.digest(@rsa.to_der)[0, 32]
      assert_equal expected_seed, seed
    end

    def test_upgrade_legacy_user_session_secret_matches_ed25519_verify_key
      result = MixinBot.api.upgrade_legacy_user(@keystore)

      seed = [result['data']['session_private_key']].pack('H*')
      derived_pub = RbNaCl::Signatures::Ed25519::SigningKey.new(seed).verify_key.to_bytes
      encoded_pub = Base64.urlsafe_encode64(derived_pub, padding: false)

      assert_equal encoded_pub, captured_payload['session_secret']
    end

    def test_upgrade_legacy_user_session_secret_legacy_is_der_public_key
      MixinBot.api.upgrade_legacy_user(@keystore)

      decoded = Base64.urlsafe_decode64(captured_payload['session_secret_legacy'])
      # The decoded bytes are the SubjectPublicKeyInfo DER for the RSA key.
      assert_equal @rsa.public_key.to_der, decoded
    end

    def test_upgrade_legacy_user_merges_session_private_key_into_response_data
      result = MixinBot.api.upgrade_legacy_user(@keystore)

      # The production code mutates `result['data']` to include the session
      # private key — this test pins that behaviour so callers can rely on it.
      assert result['data'].key?('session_private_key'),
             'expected result[data] to include session_private_key'
    end

    private

    def stub_legacy_users_with_capture
      WebMock.stub_request(:post, 'https://api.mixin.one/legacy/users').to_return do |request|
        @captured_request = request
        {
          status: 200,
          headers: { 'Content-Type' => 'application/json' },
          body: JSON.generate('data' => { 'user_id' => 'new-user-id', 'session_id' => SecureRandom.uuid },
                              'error' => nil)
        }
      end
    end

    def captured_payload
      refute_nil @captured_request, 'no request was captured'
      JSON.parse(@captured_request.body)
    end
  end
end
