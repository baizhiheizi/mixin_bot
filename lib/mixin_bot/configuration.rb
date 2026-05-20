# frozen_string_literal: true

module MixinBot
  ##
  # Configuration class for storing Mixin bot credentials and settings.
  #
  # This class handles the configuration of bot credentials including:
  # - Application ID and secret
  # - Session ID and private key
  # - Server public key
  # - Spend key and PIN
  # - API and Blaze host settings
  #
  # == Usage
  #
  # Configure globally:
  #
  #   MixinBot.configure do
  #     app_id = 'your-app-id'
  #     session_id = 'your-session-id'
  #     session_private_key = 'your-private-key'
  #     server_public_key = 'server-public-key'
  #     spend_key = 'your-spend-key'
  #   end
  #
  # Or create a specific configuration instance:
  #
  #   config = MixinBot::Configuration.new(
  #     app_id: 'your-app-id',
  #     session_id: 'your-session-id',
  #     session_private_key: 'your-private-key',
  #     server_public_key: 'server-public-key'
  #   )
  #
  # == Key Conversion
  #
  # The configuration automatically handles key format conversions:
  # - Ed25519 keys are converted from seed format (32 bytes) to full format (64 bytes)
  # - Keys are converted to Curve25519 format when needed
  # - Keys can be provided in various encodings (Base64, hex, etc.)
  #
  class Configuration
    ##
    # List of configurable attributes.
    CONFIGURABLE_ATTRS = %i[
      app_id
      client_secret
      session_id
      session_private_key
      server_public_key
      spend_key
      pin
      api_host
      blaze_host
      session_private_key_curve25519
      server_public_key_curve25519
      debug
    ].freeze
    attr_accessor(*CONFIGURABLE_ATTRS)

    ##
    # Initializes a new Configuration instance.
    #
    # @param kwargs [Hash] configuration options
    # @option kwargs [String] :app_id the application ID (or :client_id)
    # @option kwargs [String] :client_secret the client secret
    # @option kwargs [String] :session_id the session ID
    # @option kwargs [String] :session_private_key the session private key (or :private_key)
    # @option kwargs [String] :server_public_key the server public key (or :pin_token)
    # @option kwargs [String] :spend_key the spend private key
    # @option kwargs [String] :pin the PIN (defaults to spend_key if not provided)
    # @option kwargs [String] :api_host ('api.mixin.one') the API host
    # @option kwargs [String] :blaze_host ('blaze.mixin.one') the Blaze WebSocket host
    # @option kwargs [Boolean] :debug (false) enable debug logging
    #
    # @example
    #   config = MixinBot::Configuration.new(
    #     app_id: '25696f85-b7b4-4509-8c3f-2684a8fc4a2a',
    #     session_id: '25696f85-b7b4-4509-8c3f-2684a8fc4a2a',
    #     session_private_key: 'base64_encoded_key',
    #     server_public_key: 'base64_encoded_key'
    #   )
    #
    def initialize(**kwargs)
      @app_id = kwargs[:app_id] || kwargs[:client_id]
      @client_secret = kwargs[:client_secret]
      @session_id = kwargs[:session_id]
      @api_host = kwargs[:api_host] || 'api.mixin.one'
      @blaze_host = kwargs[:blaze_host] || 'blaze.mixin.one'
      @debug = kwargs[:debug] || false

      self.session_private_key = kwargs[:session_private_key] || kwargs[:private_key]
      self.server_public_key = kwargs[:server_public_key] || kwargs[:pin_token]
      self.spend_key = kwargs[:spend_key]
      self.pin = kwargs[:pin] || spend_key
    end

    ##
    # Validates if the configuration has all required credentials.
    #
    # Required fields are:
    # - app_id
    # - session_id
    # - session_private_key
    # - server_public_key
    #
    # @return [Boolean] true if all required fields are present
    #
    def valid?
      %i[app_id session_id session_private_key server_public_key].all? do |attr|
        send(attr).present?
      end
    end

    ##
    # Sets the session private key with automatic format conversion.
    #
    # Handles Ed25519 key conversion:
    # - If key is 32 bytes (seed), converts to 64-byte keypair
    # - Automatically converts to Curve25519 format for encryption
    #
    # @param key [String] the session private key in various formats
    #
    def session_private_key=(key)
      return if key.blank?

      _private_key = decode_key key
      @session_private_key =
        if _private_key.size == 32
          JOSE::JWA::Ed25519.keypair(_private_key).last
        else
          _private_key
        end

      @session_private_key_curve25519 = JOSE::JWA::Ed25519.sk_to_curve25519(@session_private_key) if @session_private_key.size == 64
    end

    ##
    # Sets the server public key with automatic format conversion.
    #
    # Converts Ed25519 public key to Curve25519 format when needed.
    # Handles both hex-encoded and Base64-encoded keys.
    #
    # @param key [String] the server public key
    #
    def server_public_key=(key)
      return if key.blank?

      @server_public_key = decode_key key
      # HEX encoded
      @server_public_key_curve25519 =
        if key.match?(/\A\h{32,}\z/i)
          JOSE::JWA::Ed25519.pk_to_curve25519 @server_public_key
        else
          server_public_key
        end
    end

    ##
    # Sets the spend key with automatic format conversion.
    #
    # Used for signing transactions in the Safe API.
    # Converts from seed format to full keypair if needed.
    #
    # @param key [String] the spend private key
    #
    def spend_key=(key)
      return if key.blank?

      _private_key = decode_key key
      @spend_key =
        if _private_key.size == 32
          JOSE::JWA::Ed25519.keypair(_private_key).last
        else
          _private_key
        end
    end

    ##
    # Sets the PIN with automatic format conversion.
    #
    # The PIN is used for certain operations requiring additional authorization.
    # Defaults to the spend_key if not explicitly set.
    #
    # @param key [String] the PIN key
    #
    def pin=(key)
      return if key.blank?

      _private_key = decode_key key
      @pin =
        if _private_key.size == 32
          JOSE::JWA::Ed25519.keypair(_private_key).last
        else
          _private_key
        end
    end

    private

    def decode_key(key)
      MixinBot.utils.decode_key key
    end
  end
end
