# frozen_string_literal: true

module MixinBot
  class API
    module LegacyUser
      # Upgrades a legacy RSA keystore user to Ed25519 session keys.
      #
      # @param keystore [Hash] :pin, :session_id, :pin_token (base64), :private_key (PEM)
      def upgrade_legacy_user(keystore)
        kl = keystore.with_indifferent_access
        priv = OpenSSL::PKey::RSA.new(kl[:private_key])
        token = Base64.decode64(kl[:pin_token])
        # Use string keys with the dash form (`'oaep-label'`) for Ruby 4.0
        # compatibility; the underscore form `oaep_label` is no longer
        # recognized by the OpenSSL EVP_PKEY_CTX in Ruby 4.0.
        key_bytes = priv.decrypt(
          token,
          'rsa_padding_mode' => 'oaep',
          'rsa_oaep_md' => 'sha256',
          'rsa_mgf1_md' => 'sha1',
          'oaep-label' => kl[:session_id]
        )

        pin_byte = kl[:pin].to_s.b
        pin_byte += [Time.now.to_i].pack('Q<')
        pin_byte += [0].pack('Q<')
        padding = 16 - (pin_byte.length % 16)
        pin_byte += ([padding].pack('C') * padding)

        cipher = OpenSSL::Cipher.new('AES-256-CBC')
        cipher.encrypt
        iv = cipher.random_iv
        cipher.key = key_bytes
        ciphertext = iv + cipher.update(pin_byte) + cipher.final

        pub_bytes = priv.public_key.to_der
        seed = Digest::SHA512.digest(priv.to_der)[0, 32]
        pub_ed25519 = RbNaCl::Signatures::Ed25519::SigningKey.new(seed).verify_key.to_bytes

        payload = {
          session_secret_legacy: Base64.urlsafe_encode64(pub_bytes, padding: false),
          session_secret: Base64.urlsafe_encode64(pub_ed25519, padding: false),
          session_id: kl[:session_id],
          pin: Base64.urlsafe_encode64(ciphertext, padding: false)
        }

        result = client.post '/legacy/users', **payload, access_token: ''
        data = result['data'] || result.data
        result['data'] = data.merge('session_private_key' => seed.unpack1('H*')) if data.is_a?(Hash)
        result
      end
    end
  end
end
