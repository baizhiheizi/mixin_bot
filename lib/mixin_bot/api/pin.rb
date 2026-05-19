# frozen_string_literal: true

module MixinBot
  class API
    module Pin
      # https://developers.mixin.one/api/alpha-mixin-network/verify-pin/
      def verify_pin(pin = nil)
        pin ||= MixinBot.config.pin
        raise ArgumentError, 'invalid pin' if pin.blank?

        path = '/pin/verify'

        payload =
          if pin.length > 6
            timestamp = (Time.now.utc.to_f * 1e9).to_i
            pin_base64 = encrypt_tip_pin pin, 'TIP:VERIFY:', timestamp.to_s.rjust(32, '0')

            {
              pin_base64:,
              timestamp:
            }
          else
            {
              pin: encrypt_pin(pin)
            }
          end

        client.post path, **payload
      end
      alias verify_pin_tip verify_pin

      # https://developers.mixin.one/api/alpha-mixin-network/create-pin/
      def update_pin(pin:, old_pin: nil)
        # old_pin ||= MixinBot.config.pin
        raise ArgumentError, 'invalid old pin' if old_pin.present? && old_pin.length != 6

        path = '/pin/update'
        encrypted_old_pin = old_pin.nil? ? '' : encrypt_pin(old_pin, iterator: Time.now.utc.to_i)

        encrypted_pin = encrypt_pin(pin, iterator: Time.now.utc.to_i + 1)
        payload = {
          old_pin_base64: encrypted_old_pin,
          pin_base64: encrypted_pin
        }

        client.post path, **payload
      end

      def update_tip_pin(pin, pub_tip)
        old_encrypted = encrypt_pin(pin, iterator: (Time.now.utc.to_f * 1e9).to_i)
        pub_buf = [pub_tip].pack('H*')
        raise ArgumentError, 'invalid public key' unless pub_buf.bytesize == 32

        pub_tip_buf = pub_buf + [1].pack('Q>')
        encrypted_pin = encrypt_pin(pub_tip_buf.unpack1('H*'), iterator: (Time.now.utc.to_f * 1e9).to_i + 1)
        path = '/pin/update'
        client.post path, old_pin_base64: old_encrypted, pin_base64: encrypted_pin
      end

      def prepare_tip_key(counter = 0)
        ed25519_key = JOSE::JWA::Ed25519.keypair

        private_key = ed25519_key[1].unpack1('H*')
        public_key = (ed25519_key[0].bytes + MixinBot::Utils.encode_uint64(counter + 1)).pack('c*').unpack1('H*')

        {
          private_key:,
          public_key:
        }
      end

      def encrypt_pin(pin, iterator: nil, shared_key: nil)
        sk = shared_key.presence || generate_shared_key_with_server
        MixinBot.utils.encrypt_pin(pin, iterator:, shared_key: sk)
      end

      def decrypt_pin(msg)
        MixinBot.utils.decrypt_pin msg, shared_key: generate_shared_key_with_server
      end

      def generate_shared_key_with_server
        if config.server_public_key.size == 32
          JOSE::JWA::X25519.x25519(
            config.session_private_key_curve25519,
            config.server_public_key_curve25519
          )
        else
          JOSE::JWA::PKCS1.rsaes_oaep_decrypt(
            'SHA256',
            config.server_public_key,
            OpenSSL::PKey::RSA.new(config.session_private_key),
            session_id
          )
        end
      end
    end
  end
end
