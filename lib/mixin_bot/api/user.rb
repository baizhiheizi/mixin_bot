# frozen_string_literal: true

module MixinBot
  class API
    ##
    # User-related API endpoints: bot/network user lookup, plain network-user
    # creation, and the full Safe Network registration flow.
    #
    # The Safe-network registration mirrors the official Go SDK reference
    # implementation in +RegisterSafeWithSetupPin+ / +RegisterSafeBareUser+:
    # https://github.com/MixinNetwork/bot-api-go-client/blob/master/safe_user.go
    #
    module User
      # Maximum number of times to retry +safe_register+ when the freshly-set
      # TIP PIN has not yet propagated through the Mixin server.
      SAFE_REGISTER_MAX_RETRIES = 3

      # Base seconds to wait between +safe_register+ retries. The wait grows
      # linearly with the attempt number.
      SAFE_REGISTER_RETRY_BASE_DELAY = 1

      # Seconds to wait after +update_pin+ before calling +safe_register+, so
      # the new TIP PIN has time to propagate on the server side.
      TIP_PIN_PROPAGATION_DELAY = 1

      # Billed cost per network user created via {#create_user} (USD), after
      # the free tier. Pass +increment: 0+ to skip headroom for the new user.
      CREATE_USER_BILLING_INCREMENT = '0.5'

      def user(user_id, access_token: nil)
        path = format('/users/%<user_id>s', user_id:)
        client.get path, access_token:
      end

      ##
      # Creates a Mixin network user.
      #
      # When +key+ is omitted a fresh Ed25519 keypair is generated. The
      # response is merged with the hex-encoded session private key under
      # +:private_key+.
      #
      # @param full_name [String] display name for the new user
      # @param key [String, nil] optional 32-byte Ed25519 seed
      # @param force [Boolean] when false (default), verify app billing credit
      #   headroom before calling the API; when true, skip the preflight
      # @param increment [Numeric, String] billing headroom for the new user
      #   (defaults to {CREATE_USER_BILLING_INCREMENT}; use +0+ on free tier)
      # @return [Hash] Mixin response merged with the hex-encoded private key
      # @raise [InsufficientAppBillingError] when billing credit lacks headroom
      #
      def create_user(full_name, key: nil, force: false, increment: CREATE_USER_BILLING_INCREMENT)
        ensure_app_billing_credit!(force:, increment:)

        keypair = JOSE::JWA::Ed25519.keypair key
        session_secret = Base64.urlsafe_encode64 keypair[0], padding: false
        private_key = keypair[1].unpack1('H*')

        path = '/users'
        payload = {
          full_name:,
          session_secret:
        }

        res = client.post path, **payload
        res.merge(private_key:).with_indifferent_access
      end

      def search_user(query, access_token: nil)
        path = format('/search/%<query>s', query:)

        client.get path, access_token:
      end

      def fetch_users(user_ids)
        path = '/users/fetch'
        user_ids = [user_ids] if user_ids.is_a? String
        payload = user_ids

        client.post path, *payload
      end

      ##
      # Creates a Safe-network user end-to-end.
      #
      # Mirrors +RegisterSafeWithSetupPin+ in the Go SDK:
      #
      # 1. generate (or accept) a session keypair and a spend keypair
      # 2. create the network user via {#create_user}
      # 3. set the user's PIN to the TIP public key derived from the spend key
      # 4. wait briefly for propagation, then register on the Safe network
      #    (retrying transient failures)
      #
      # The returned keystore is suitable for instantiating a new
      # +MixinBot::API+ that authenticates as the freshly-registered user.
      #
      # @param name [String] display name for the new user
      # @param private_key [String, nil] optional 32-byte session Ed25519 seed
      # @param spend_key [String, nil] optional 32-byte spend Ed25519 seed
      # @param force [Boolean] forwarded to {#create_user}; see billing preflight
      #   there
      # @param increment [Numeric, String] forwarded to {#create_user}
      # @return [Hash] keystore with +:app_id+, +:session_id+,
      #   +:session_private_key+, +:server_public_key+ and +:spend_key+
      # @raise [MixinBot::Error] when registration ultimately fails. Transient
      #   PIN/response errors are retried up to {SAFE_REGISTER_MAX_RETRIES}
      #   times; other errors bubble up immediately.
      # @raise [InsufficientAppBillingError] when {#create_user} billing
      #   preflight fails
      #
      def create_safe_user(name, private_key: nil, spend_key: nil, force: false, increment: CREATE_USER_BILLING_INCREMENT)
        session_keypair = JOSE::JWA::Ed25519.keypair private_key
        spend_keypair = JOSE::JWA::Ed25519.keypair spend_key

        spend_key_hex = spend_keypair[1].unpack1('H*')

        user = create_user name, key: session_keypair[1][...32], force: force, increment: increment
        data = user.fetch('data')

        keystore = {
          app_id: data['user_id'],
          session_id: data['session_id'],
          session_private_key: session_keypair[1].unpack1('H*'),
          server_public_key: data['pin_token_base64'],
          spend_key: spend_key_hex
        }

        user_api = MixinBot::API.new(**keystore)

        tip_pin = MixinBot.utils.tip_public_key spend_keypair[0], counter: data['tip_counter']
        user_api.update_pin pin: tip_pin

        # Allow the freshly-set TIP PIN to propagate before registering.
        sleep TIP_PIN_PROPAGATION_DELAY

        with_safe_register_retries do
          user_api.safe_register spend_key_hex
        end

        keystore
      end

      ##
      # Registers an existing user on the Safe network.
      #
      # +spend_key+ may be supplied as raw bytes, a hex string, or a
      # Base64-encoded string. It must encode the user's full Ed25519 spend
      # private key (or a 32-byte seed).
      #
      # @param spend_key [String] the user's spend Ed25519 private key
      # @return [Hash] Mixin response
      # @raise [ArgumentError] when +spend_key+ cannot be decoded into at
      #   least 32 bytes
      #
      def safe_register(spend_key)
        path = '/safe/users'

        spend_key_bytes = MixinBot.utils.decode_key spend_key
        raise ArgumentError, 'invalid spend_key' if spend_key_bytes.nil? || spend_key_bytes.size < 32

        keypair = JOSE::JWA::Ed25519.keypair spend_key_bytes[...32]
        public_key = keypair[0].unpack1('H*')
        # Normalize to a 64-byte signing key in hex so that callers may pass a
        # 32-byte seed without crashing the downstream signer.
        signing_key_hex = keypair[1].unpack1('H*')

        # NOTE: the Go SDK's +crypto.Sha256Hash+ is misleadingly named — it
        # actually computes SHA3-256, so +SHA3::Digest::SHA3_256+ is the correct
        # match. See bot-api-go-client safe_user.go +RegisterSafeBareUser+.
        app_id_hash = SHA3::Digest::SHA3_256.hexdigest config.app_id
        signature = Base64.urlsafe_encode64(
          JOSE::JWA::Ed25519.sign([app_id_hash].pack('H*'), keypair[1]),
          padding: false
        )

        pin_base64 = encrypt_tip_pin signing_key_hex, 'SEQUENCER:REGISTER:', config.app_id, public_key

        payload = {
          public_key:,
          signature:,
          pin_base64:
        }

        client.post path, **payload
      end

      ##
      # Migrates an existing legacy user to the Safe network.
      #
      # When the user has not yet upgraded to a TIP PIN, +pin+ must be the
      # user's current 6-digit PIN so {#update_pin} can rotate it to a TIP
      # PIN derived from +spend_key+. When the user already has a TIP PIN,
      # +pin+ may be omitted.
      #
      # @param spend_key [String] the user's spend Ed25519 seed or full key
      # @param pin [String, nil] the user's current PIN (only required when
      #   the user has not yet upgraded to a TIP PIN)
      # @return [TrueClass, Hash] +true+ if the user already has Safe enabled,
      #   otherwise +{ spend_key: <hex> }+
      # @raise [MixinBot::Error] when registration ultimately fails. Transient
      #   PIN/response errors are retried up to {SAFE_REGISTER_MAX_RETRIES}
      #   times; other errors bubble up immediately.
      #
      def migrate_to_safe(spend_key:, pin: nil)
        profile = me['data']
        return true if profile['has_safe']

        spend_keypair = JOSE::JWA::Ed25519.keypair spend_key
        spend_key_hex = spend_keypair[1].unpack1('H*')

        if profile['tip_key_base64'].blank?
          new_pin = MixinBot.utils.tip_public_key spend_keypair[0], counter: profile['tip_counter']
          update_pin pin: new_pin, old_pin: pin
        end

        # Allow the freshly-set TIP PIN to propagate before registering.
        sleep TIP_PIN_PROPAGATION_DELAY

        with_safe_register_retries do
          safe_register spend_key_hex
        end

        { spend_key: spend_key_hex }.with_indifferent_access
      end

      private

      # Errors that are typically caused by the freshly-set TIP PIN not yet
      # being visible to the Safe-network sequencer. Anything else (auth,
      # missing user, validation, balance, ...) should bubble up immediately.
      RETRIABLE_SAFE_REGISTER_ERRORS = [MixinBot::PinError, MixinBot::ResponseError].freeze
      private_constant :RETRIABLE_SAFE_REGISTER_ERRORS

      # Yields to the block, retrying transient errors up to
      # {SAFE_REGISTER_MAX_RETRIES} times with linear backoff. The TIP PIN
      # set by {#update_pin} can take a moment to propagate, so the first
      # +safe_register+ attempts often fail.
      def with_safe_register_retries
        attempt = 0
        begin
          yield
        rescue *RETRIABLE_SAFE_REGISTER_ERRORS
          attempt += 1
          raise if attempt > SAFE_REGISTER_MAX_RETRIES

          sleep(SAFE_REGISTER_RETRY_BASE_DELAY + attempt)
          retry
        end
      end
    end
  end
end
