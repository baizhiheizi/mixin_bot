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
        session_ids = options[:sessions].map { |s| s['session_id'] || s[:session_id] }.compact.sort
        checksum = MixinBot.utils.generate_user_checksum(options[:sessions])

        {
          conversation_id: options[:conversation_id],
          recipient_id: options[:recipient_id],
          representative_id: options[:representative_id],
          category: options[:category],
          quote_message_id: options[:quote_message_id],
          message_id: options[:message_id] || SecureRandom.uuid,
          data_base64:,
          checksum:,
          recipient_sessions: session_ids.map { |session_id| { session_id: } },
          # Go's MessageRequest always serializes `silent`; default stays false
          silent: (options[:silent] ? true : false)
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

      ##
      # Encrypt and send messages using each recipient's current sessions.
      #
      # Accepts a single options hash or an array of them (same shapes as
      # +send_encrypted_*_message+). Sessions are resolved through the session
      # store - +session_store:+, or the per-API-instance default store - and
      # fetched via +POST /sessions/fetch+ on a cache miss. Messages the server
      # rejects because a recipient's sessions changed have their sessions
      # evicted, refreshed, and are retried once. The returned envelope carries
      # every message's final +state+ (SUCCESS/FAILED).
      #
      # @param messages [Hash, Array<Hash>] unencrypted message options
      # @param session_store [#fetch, #store] session cache; +store(id, nil)+ evicts
      # @return [MixinBot::Models::ApiEnvelope] per-message responses (+state+ SUCCESS/FAILED)
      #
      def post_encrypted_messages(messages = nil, session_store: nil, **kwargs)
        messages = kwargs.delete(:messages) if messages.nil? && kwargs.key?(:messages)
        messages = [messages] unless messages.is_a? Array
        raise ArgumentError, 'messages must not be empty' if messages.empty?

        token_keys = %i[access_token exp_in scp]
        unknown = kwargs.keys - token_keys
        raise ArgumentError, "unsupported options: #{unknown.join(', ')}" if unknown.any?

        original = messages.map { |message| message.to_h.transform_keys(&:to_sym) }
        seen_ids = []
        pending = original.map do |message|
          raise ArgumentError, 'recipient_id is required' if message[:recipient_id].blank?
          if message[:message_id] && seen_ids.include?(message[:message_id])
            raise ArgumentError,
                  "duplicate message_id #{message[:message_id]}"
          end

          message[:message_id] ||= SecureRandom.uuid
          seen_ids << message[:message_id]
          message
        end

        store = session_store || (@session_store ||= MixinBot::SessionStore.new)
        final_results = {}
        responses = nil

        2.times do |attempt|
          recipient_ids = pending.map { |message| message[:recipient_id] }.uniq
          missing = recipient_ids.reject { |recipient_id| cached_encrypted_sessions(store, recipient_id).present? }
          fetched = missing.any? ? fetch_encrypted_message_sessions!(missing, store, **kwargs) : {}

          requests = pending.map do |message|
            sessions = cached_encrypted_sessions(store, message[:recipient_id]) || fetched[message[:recipient_id]]
            raise ArgumentError, "no sessions found for recipient #{message[:recipient_id]}" if sessions.blank?

            encrypted_message_request(message, sessions)
          end
          responses = client.post '/encrypted_messages', *requests, **kwargs

          data = responses['data']
          data = [data] if data.is_a?(Hash)
          raise ArgumentError, 'unexpected /encrypted_messages response format' unless data.is_a? Array

          results, failures = encrypted_message_results(pending, data)
          final_results.merge!(results)
          break if failures.empty? || attempt.positive?

          pending = failures
          # the FAILED recipients' sessions are assumed expired: evict + refresh
          pending.map { |message| message[:recipient_id] }.uniq.each { |recipient_id| store.store recipient_id, nil }
        end

        responses.to_h['data'] = original.filter_map { |message| final_results[message[:message_id]] }
        responses
      end

      # Read a recipient's sessions from the store. Stores that raise (a Redis
      # outage) or return non-list values count as a cache miss, mirroring the
      # Go SDK's `if sessions, err := store.Get(...); err == nil` tolerance.
      def cached_encrypted_sessions(store, recipient_id)
        cached = begin
          # block form keeps 1-arity duck-typed stores (Hash included) working
          store.fetch(recipient_id) { nil } # rubocop:disable Style/RedundantFetchBlock
        rescue StandardError
          nil
        end

        sessions = Array(cached)
        return nil unless sessions.all?(Hash)
        return nil if sessions.empty?

        sessions.map(&:stringify_keys)
      end

      # Fetch sessions for the given recipients and write them to the store.
      # Returns { recipient_id => sessions } for the resolved recipients.
      def fetch_encrypted_message_sessions!(recipient_ids, store, **kwargs)
        return {} if recipient_ids.empty?

        response = fetch_user_sessions(recipient_ids, **kwargs.slice(:access_token, :exp_in, :scp))
        grouped = {}
        Array(response['data']).each do |session|
          owner = session['user_id'].presence
          owner = recipient_ids.first if owner.blank? && recipient_ids.one?
          grouped[owner] = (grouped[owner] || []) + [session] if owner.present?
        end

        recipient_ids.each_with_object({}) do |recipient_id, resolved|
          sessions = grouped[recipient_id]
          raise ArgumentError, "no sessions found for recipient #{recipient_id}" if sessions.blank?

          store.store recipient_id, sessions.map(&:stringify_keys)
          resolved[recipient_id] = sessions.map(&:stringify_keys)
        end
      end

      def encrypted_message_request(message, sessions)
        base_encrypted_message_params message.merge(sessions:, silent: (message[:silent] ? true : false))
      end

      # Maps each pending message to its server response. Returns
      # [results_by_message_id, failed_messages]; raises on malformed responses.
      def encrypted_message_results(messages, responses)
        by_message_id = responses.to_h { |response| [response['message_id'], response] }

        results = {}
        failures = []
        messages.each do |message|
          response = by_message_id[message[:message_id]]
          raise ArgumentError, "encrypted message response missing for #{message[:message_id]}" if response.nil?

          results[message[:message_id]] = response
          case response['state']
          when 'SUCCESS' then nil
          when 'FAILED' then failures << message
          else raise ArgumentError, "encrypted message #{message[:message_id]} returned unknown state #{response['state']}"
          end
        end
        [results, failures]
      end

      def encrypt_message(data, sessions = [], sk: nil, pk: nil) # rubocop:disable Naming/MethodParameterName
        raise ArgumentError, 'Wrong sessions format!' unless sessions.all?(&->(s) { s.key?('session_id') && s.key?('public_key') })

        sk ||= config.session_private_key[0...32]
        pk ||= config.session_private_key[32...]

        encrypter = OpenSSL::Cipher.new('AES-128-GCM').encrypt
        key = encrypter.random_key
        nounce = encrypter.random_iv
        encrypter.key = key
        encrypter.iv = nounce
        encrypter.auth_data = ''
        ciphertext = encrypter.update(Base64.urlsafe_decode64(data)) + encrypter.final + encrypter.auth_tag

        bytes = [1]
        bytes.concat([sessions.size].pack('v*').bytes)
        bytes.concat(JOSE::JWA::Ed25519.pk_to_curve25519(pk).bytes)

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

          bytes.concat((MixinBot::UUID.new(hex: session['session_id']).packed + iv).bytes)
          bytes.concat(encrypter.update(key + padtext).bytes)
        end

        bytes.concat(nounce.bytes)
        bytes.concat(ciphertext.bytes)

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
