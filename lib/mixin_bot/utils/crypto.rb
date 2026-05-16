# frozen_string_literal: true

module MixinBot
  module Utils
    ##
    # Cryptographic utility methods for Mixin Network operations.
    #
    # This module provides essential cryptographic functions including:
    # - JWT token generation for API authentication
    # - Ed25519 and RSA key generation
    # - PIN encryption/decryption
    # - Transaction signing
    # - UUID generation and derivation
    # - Ghost key derivation for Safe API
    #
    # == Key Types
    #
    # Mixin Network uses several types of cryptographic keys:
    #
    # [Session Key] Ed25519 or RSA key for API authentication
    # [Spend Key] Ed25519 key for signing transactions (Safe API)
    # [View Key] Ed25519 key for viewing transactions
    # [PIN Key] For legacy PIN operations
    #
    # == Signature Algorithm
    #
    # Safe API uses Ed25519 with Blake3 hashing for transaction signing.
    # This provides quantum-resistant security with compact signatures.
    #
    module Crypto
      ##
      # Generates a JWT access token for API authentication.
      #
      # Creates a signed JWT token containing request details and credentials.
      # The token is used in the Authorization header for API requests.
      #
      # Token payload includes:
      # - uid: user/bot ID
      # - sid: session ID
      # - iat: issued at timestamp
      # - exp: expiration timestamp
      # - jti: unique token ID
      # - sig: SHA-256 hash of request (method + uri + body)
      # - scp: scope (usually 'FULL')
      #
      # @param method [String] HTTP method (GET, POST, etc.)
      # @param uri [String] request URI path
      # @param body [String] request body (empty for GET)
      # @param kwargs [Hash] additional options
      # @option kwargs [Integer] :exp_in (600) token lifetime in seconds
      # @option kwargs [String] :scp ('FULL') token scope
      # @option kwargs [String] :app_id bot application ID
      # @option kwargs [String] :session_id session ID
      # @option kwargs [String] :private_key session private key
      #
      # @return [String] JWT token
      #
      # @raise [ConfigurationNotValidError] if private_key is missing
      #
      # @example
      #   token = MixinBot.utils.access_token('GET', '/me', '')
      #   # Use in request: Authorization: Bearer #{token}
      #
      def access_token(method, uri, body = '', **kwargs)
        sig = Digest::SHA256.hexdigest(method + uri + body.to_s)
        iat = Time.now.utc.to_i
        exp = (Time.now.utc + (kwargs[:exp_in] || 600)).to_i
        scp = kwargs[:scp] || 'FULL'
        jti = SecureRandom.uuid
        uid = kwargs[:app_id] || MixinBot.config.app_id
        sid = kwargs[:session_id] || MixinBot.config.session_id
        private_key = kwargs[:private_key] || MixinBot.config.session_private_key

        payload = {
          uid:,
          sid:,
          iat:,
          exp:,
          jti:,
          sig:,
          scp:
        }

        if private_key.blank?
          raise ConfigurationNotValidError, 'private_key is required'
        elsif private_key.size == 64
          jwk = JOSE::JWK.from_okp [:Ed25519, private_key]
          jws = JOSE::JWS.from({ 'alg' => 'EdDSA' })
        else
          jwk = JOSE::JWK.from_pem private_key
          jws = JOSE::JWS.from({ 'alg' => 'RS512' })
        end

        jwt = JOSE::JWT.from payload
        JOSE::JWT.sign(jwk, jws, jwt).compact
      end

      ##
      # Generates a new Ed25519 keypair.
      #
      # Ed25519 is the recommended key type for Mixin Network.
      # It provides strong security with compact keys and signatures.
      #
      # @return [Hash] hash containing :private_key and :public_key (Base64-encoded)
      #
      # @example
      #   keys = MixinBot.utils.generate_ed25519_key
      #   puts "Private: #{keys[:private_key]}"
      #   puts "Public: #{keys[:public_key]}"
      #
      def generate_ed25519_key
        ed25519_key = JOSE::JWA::Ed25519.keypair
        {
          private_key: Base64.urlsafe_encode64(ed25519_key[1], padding: false),
          public_key: Base64.urlsafe_encode64(ed25519_key[0], padding: false)
        }
      end

      ##
      # Generates a new RSA keypair.
      #
      # RSA keys are supported for backward compatibility but
      # Ed25519 is recommended for new applications.
      #
      # @return [Hash] hash containing :private_key and :public_key (PEM format)
      #
      # @example
      #   keys = MixinBot.utils.generate_rsa_key
      #   puts keys[:private_key]
      #
      def generate_rsa_key
        rsa_key = OpenSSL::PKey::RSA.new 1024
        {
          private_key: rsa_key.to_pem,
          public_key: rsa_key.public_key.to_pem
        }
      end

      ##
      # Derives a public key from a private key.
      #
      # Used internally for cryptographic operations.
      #
      # @param key [String] the private key (64 bytes)
      # @return [String] the derived public key
      #
      def shared_public_key(key)
        (JOSE::JWA::Edwards25519Point.stdbase * scalar_from_bytes(key[...64]).x.to_i).encode
      end

      ##
      # Converts raw bytes to a scalar for Ed25519 operations.
      #
      # Used internally for cryptographic calculations.
      #
      # @param raw [String] raw bytes
      # @return [JOSE::JWA::FieldElement] the scalar value
      #
      def scalar_from_bytes(raw)
        JOSE::JWA::FieldElement.new(
          # https://github.com/potatosalad/ruby-jose/blob/e1be589b889f1e59ac233a5d19a3fa13f1e4b8a0/lib/jose/jwa/x25519.rb#L122C14-L122C48
          OpenSSL::BN.new(raw.reverse, 2),
          JOSE::JWA::Edwards25519Point::L
        )
      end

      def sign(msg, key:)
        msg = Digest::Blake3.digest msg

        pub = shared_public_key key

        y_scalar = scalar_from_bytes key

        key_digest = Digest::SHA512.digest key
        msg_digest = Digest::SHA512.digest(key_digest[-32...] + msg)

        z_scalar = scalar_from_bytes msg_digest[...64]

        r_point = JOSE::JWA::Edwards25519Point.stdbase * z_scalar.x.to_i

        hram_digest = Digest::SHA512.digest(r_point.encode + pub + msg)

        x_scalar = scalar_from_bytes hram_digest[...64]

        s_scalar = (x_scalar * y_scalar) + z_scalar

        r_point.encode + s_scalar.to_bytes(32).ljust(32, "\x00")
      end

      def generate_unique_uuid(uuid1, uuid2)
        md5 = Digest::MD5.new
        md5 << [uuid1, uuid2].min
        md5 << [uuid1, uuid2].max
        digest = md5.digest
        digest6 = ((digest[6].ord & 0x0f) | 0x30).chr
        digest8 = ((digest[8].ord & 0x3f) | 0x80).chr
        cipher = digest[0...6] + digest6 + digest[7] + digest8 + digest[9..]

        MixinBot::UUID.new(raw: cipher).unpacked
      end

      ##
      # Generates a unique UUID from multiple UUIDs.
      #
      # Creates a deterministic UUID by combining multiple UUIDs.
      # The result is always the same for the same set of input UUIDs,
      # regardless of order (after sorting).
      #
      # This is used for:
      # - Creating conversation IDs
      # - Generating multisig addresses
      # - Creating deterministic identifiers
      #
      # @param uuids [Array<String>] array of UUIDs to combine
      # @return [String] the unique combined UUID
      #
      # @example
      #   uuid = MixinBot.utils.unique_uuid(
      #     'user1-uuid',
      #     'user2-uuid',
      #     'user3-uuid'
      #   )
      #   puts uuid  # Always the same for these inputs
      #
      def unique_uuid(*uuids)
        uuids = uuids.flatten.compact
        uuids.sort
        r = uuids.first
        uuids.each_with_index do |uuid, i|
          r = generate_unique_uuid(r, uuid) if i.positive?
        end

        r
      end

      ##
      # Generates a group conversation ID.
      #
      # Creates a deterministic conversation ID for a group based on:
      # - Owner ID
      # - Group name
      # - Participant IDs
      # - Random ID (optional, for creating different groups with same members)
      #
      # @param user_ids [Array<String>] array of participant user IDs
      # @param name [String] the group name
      # @param owner_id [String] the group owner's user ID
      # @param random_id [String, nil] optional random ID for uniqueness
      # @return [String] the conversation UUID
      #
      # @example
      #   conv_id = MixinBot.utils.generate_group_conversation_id(
      #     user_ids: ['user1', 'user2', 'user3'],
      #     name: 'My Group',
      #     owner_id: 'owner-id'
      #   )
      #
      def generate_group_conversation_id(user_ids:, name:, owner_id:, random_id: nil)
        random_id ||= SecureRandom.uuid

        # Start with owner_id and group name
        gid = unique_uuid(owner_id, name)

        # Combine with random_id
        gid = unique_uuid(gid, random_id)

        # Sort participants and combine with each one
        sorted_participants = user_ids.sort
        sorted_participants.each do |participant|
          gid = unique_uuid(gid, participant)
        end

        gid
      end

      def generate_trace_from_hash(hash, output_index = 0)
        md5 = Digest::MD5.new
        md5 << hash
        md5 << [output_index].pack('c*') if output_index.positive? && output_index < 256
        digest = md5.digest
        digest[6] = ((digest[6].ord & 0x0f) | 0x30).chr
        digest[8] = ((digest[8].ord & 0x3f) | 0x80).chr

        MixinBot::UUID.new(raw: digest).unpacked
      end

      # decrypt the encrpted pin, just for test
      def decrypt_pin(msg, shared_key:)
        msg = Base64.urlsafe_decode64 msg
        iv = msg[0..15]
        cipher = msg[16..47]
        alg = 'AES-256-CBC'
        decode_cipher = OpenSSL::Cipher.new(alg)
        decode_cipher.decrypt
        decode_cipher.iv = iv
        decode_cipher.key = shared_key
        decode_cipher.update(cipher)
      end

      # use timestamp(timestamp) for iterator as default: must be bigger than the previous,
      # the first time must be greater than 0. After a new session created, it will be reset to 0.
      def encrypt_pin(pin, **kwargs)
        pin = MixinBot.utils.decode_key pin

        shared_key = kwargs[:shared_key]
        raise ArgumentError, 'shared_key is required' if shared_key.blank?

        iterator ||= kwargs[:iterator] || Time.now.utc.to_i
        tszero = iterator % 0x100
        tsone = (iterator % 0x10000) >> 8
        tstwo = (iterator % 0x1000000) >> 16
        tsthree = (iterator % 0x100000000) >> 24
        tsstring = "#{tszero.chr}#{tsone.chr}#{tstwo.chr}#{tsthree.chr}\u0000\u0000\u0000\u0000"
        encrypt_content = pin + tsstring + tsstring
        pad_count = 16 - (encrypt_content.length % 16)
        padded_content =
          if pad_count.positive?
            encrypt_content + (pad_count.chr * pad_count)
          else
            encrypt_content
          end

        alg = 'AES-256-CBC'
        aes = OpenSSL::Cipher.new(alg)
        iv = OpenSSL::Cipher.new(alg).random_iv
        aes.encrypt
        aes.key = shared_key
        aes.iv = iv
        cipher = aes.update(padded_content)
        msg = iv + cipher
        Base64.urlsafe_encode64 msg, padding: false
      end

      def tip_public_key(key, counter: 0)
        raise ArgumentError, 'invalid key' if key.size < 32

        (key[0...32].bytes + MixinBot::Utils.encode_uint64(counter + 1)).pack('c*').unpack1('H*')
      end

      def hash_scalar(pkey, output_index)
        tmp = [output_index].pack('Q<').reverse

        hash1 = Digest::Blake3.digest(pkey + tmp)
        hash2 = Digest::Blake3.digest hash1

        hash3 = Digest::Blake3.digest(hash1 + hash2)
        hash4 = Digest::Blake3.digest hash3

        hash3 + hash4
      end

      def multiply_keys(public_key:, private_key:)
        public_point = JOSE::JWA::Edwards25519Point.stdbase.decode public_key
        private_scalar = scalar_from_bytes private_key
        (public_point * private_scalar.x.to_i).encode
      end

      def derive_ghost_public_key(private_key, view_key, spend_key, index)
        mult_value = multiply_keys(public_key: view_key, private_key:)

        x = hash_scalar mult_value, index

        p1 = JOSE::JWA::Edwards25519Point.stdbase.decode spend_key
        p2 = JOSE::JWA::Edwards25519Point.stdbase * scalar_from_bytes(x).x.to_i

        (p1 + p2).encode
      end

      def derive_ghost_private_key(public_key, view_key, spend_key, index)
        mult_value = multiply_keys(public_key:, private_key: view_key)

        x = hash_scalar mult_value, index

        x_scalar = scalar_from_bytes x
        y_scalar = scalar_from_bytes spend_key

        (x_scalar + y_scalar).to_bytes(32)
      end
    end
  end
end
