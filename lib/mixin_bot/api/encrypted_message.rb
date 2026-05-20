# frozen_string_literal: false

module MixinBot
  class API
    module EncryptedMessage
      def encrypted_text(options)
        options.merge!(category: 'ENCRYPTED_TEXT')
        base_encrypted_message_params(options)
      end

      def encrypted_post(options)
        options.merge!(category: 'ENCRYPTED_POST')
        base_encrypted_message_params(options)
      end

      def encrypted_image(options)
        options.merge!(category: 'ENCRYPTED_IMAGE')
        base_encrypted_message_params(options)
      end

      def encrypted_data(options)
        options.merge!(category: 'ENCRYPTED_DATA')
        base_encrypted_message_params(options)
      end

      def encrypted_sticker(options)
        options.merge!(category: 'ENCRYPTED_STICKER')
        base_encrypted_message_params(options)
      end

      def encrypted_contact(options)
        options.merge!(category: 'ENCRYPTED_CONTACT')
        base_encrypted_message_params(options)
      end

      def encrypted_audio(options)
        options.merge!(category: 'ENCRYPTED_AUDIO')
        base_encrypted_message_params(options)
      end

      def encrypted_video(options)
        options.merge!(category: 'ENCRYPTED_VIDEO')
        base_encrypted_message_params(options)
      end

      # use HTTP to send message
      def send_encrypted_text_message(options)
        send_encrypted_message encrypted_text(options)
      end

      def send_encrypted_post_message(options)
        send_encrypted_message encrypted_post(options)
      end

      def send_encrypted_image_message(options)
        send_encrypted_message encrypted_image(options)
      end

      def send_encrypted_data_message(options)
        send_encrypted_message encrypted_data(options)
      end

      def send_encrypted_sticker_message(options)
        send_encrypted_message encrypted_sticker(options)
      end

      def send_encrypted_contact_message(options)
        send_encrypted_message encrypted_contact(options)
      end

      def send_encrypted_audio_message(options)
        send_encrypted_message encrypted_audio(options)
      end

      def send_encrypted_video_message(options)
        send_encrypted_message encrypted_video(options)
      end

      # base format of message params
      def base_encrypted_message_params(options)
        data = options[:data].is_a?(String) ? options[:data] : options[:data].to_json
        data_base64 = encrypt_message Base64.urlsafe_encode64(data, padding: false), options[:sessions]
        session_ids = options[:sessions].map(&->(s) { s['session_id'] }).sort
        checksum = Digest::MD5.hexdigest session_ids.join

        {
          conversation_id: options[:conversation_id],
          recipient_id: options[:recipient_id],
          representative_id: options[:representative_id],
          category: options[:category],
          quote_message_id: options[:quote_message_id],
          message_id: options[:message_id] || SecureRandom.uuid,
          data_base64:,
          checksum:,
          recipient_sessions: session_ids.map(&->(s) { { session_id: s } }),
          silent: false
        }.compact
      end

      def send_encrypted_messages(messages)
        send_encrypted_message messages
      end

      # http post request
      def send_encrypted_message(payload)
        path = '/encrypted_messages'
        payload = [payload] if payload.is_a? Hash
        raise ArgumentError, 'Wrong payload format!' unless payload.is_a? Array

        client.post path, *payload
      end

      def encrypt_message(data, sessions = [], sk: nil, pk: nil) # rubocop:disable Naming/MethodParameterName
        raise ArgumentError, 'Wrong sessions format!' unless sessions.all?(&->(s) { s.key?('session_id') && s.key?('public_key') })

        sk ||= config.session_private_key[0...32]
        pk ||= config.session_private_key[32...]

        Digest::MD5.hexdigest sessions.map(&->(s) { s['session_id'] }).sort.join
        encrypter = OpenSSL::Cipher.new('AES-128-GCM').encrypt
        key = encrypter.random_key
        nounce = encrypter.random_iv
        encrypter.key = key
        encrypter.iv = nounce
        encrypter.auth_data = ''
        ciphertext = encrypter.update(Base64.urlsafe_decode64(data)) + encrypter.final + encrypter.auth_tag

        bytes = [1]
        bytes += [sessions.size].pack('v*').bytes
        bytes += JOSE::JWA::Ed25519.pk_to_curve25519(pk).bytes

        sessions.each do |session|
          aes_key = JOSE::JWA::X25519.shared_secret(
            Base64.urlsafe_decode64(session['public_key']),
            JOSE::JWA::Ed25519.secret_to_curve25519(sk)
          )

          padding = 16 - (key.size % 16)
          padtext = ([padding] * padding).pack('C*')

          encrypter = OpenSSL::Cipher.new('AES-256-CBC').encrypt
          encrypter.key = aes_key
          iv = encrypter.random_iv
          encrypter.iv = iv

          bytes += (MixinBot::UUID.new(hex: session['session_id']).packed + iv).bytes
          bytes += encrypter.update(key + padtext).bytes
        end

        bytes += nounce.bytes
        bytes += ciphertext.bytes

        Base64.urlsafe_encode64 bytes.pack('C*'), padding: false
      end

      def decrypt_message(data, sk: nil, si: nil) # rubocop:disable Naming/MethodParameterName
        bytes = Base64.urlsafe_decode64(data).bytes

        si ||= config.session_id
        sk ||= config.session_private_key[0...32]

        size = 16 + 48
        return '' if bytes.size < 1 + 2 + 32 + size + 12

        session_length = bytes[1...3].pack('v*').unpack1('C*')
        prefix_size = 35 + (session_length * size)

        i = 35
        key = ''
        while i < prefix_size
          uuid = MixinBot::UUID.new(raw: bytes[i...(i + 16)].pack('C*')).unpacked
          if uuid == si
            pub = bytes[3...35]
            aes_key = JOSE::JWA::X25519.shared_secret(
              pub.pack('C*'),
              JOSE::JWA::Ed25519.secret_to_curve25519(sk)
            )
            iv = bytes[(i + 16)...(i + 16 + 16)].pack('C*')
            encrypted_key = bytes[(i + 16 + 16)...(i + size)].pack('C*')

            decrypter = OpenSSL::Cipher.new('AES-256-CBC').decrypt
            decrypter.iv = iv
            decrypter.key = aes_key
            cipher = decrypter.update(encrypted_key)
            key = cipher[...16]
            break
          end
          i += size
        end

        return '' unless key.size == 16

        decrypter = OpenSSL::Cipher.new('AES-128-GCM').decrypt
        decrypter.key = key
        decrypter.iv = bytes[prefix_size...(prefix_size + 12)].pack('C*')
        decrypter.auth_tag = bytes.last(16).pack('C*')
        decrypted = decrypter.update(bytes[(prefix_size + 12)...-16].pack('C*'))
        decrypter.final

        Base64.urlsafe_encode64 decrypted
      end
    end
  end
end
