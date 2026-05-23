# frozen_string_literal: true

require_relative 'client'
require_relative 'configuration'
require_relative 'api/address'
require_relative 'api/app'
require_relative 'api/asset'
require_relative 'api/attachment'
require_relative 'api/auth'
require_relative 'api/blaze'
require_relative 'api/chain'
require_relative 'api/code'
require_relative 'api/circle'
require_relative 'api/computer_api'
require_relative 'api/conversation'
require_relative 'api/deposit'
require_relative 'api/encrypted_message'
require_relative 'api/external'
require_relative 'api/fiat'
require_relative 'api/inscription'
require_relative 'api/legacy_collectible'
require_relative 'api/legacy_user'
require_relative 'api/legacy_multisig'
require_relative 'api/legacy_output'
require_relative 'api/legacy_payment'
require_relative 'api/legacy_snapshot'
require_relative 'api/legacy_transaction'
require_relative 'api/legacy_transfer'
require_relative 'api/me'
require_relative 'api/message'
require_relative 'api/multisig'
require_relative 'api/network'
require_relative 'api/network_asset'
require_relative 'api/output'
require_relative 'api/payment'
require_relative 'api/pin_payload'
require_relative 'api/pin'
require_relative 'api/rpc'
require_relative 'api/session'
require_relative 'api/snapshot'
require_relative 'api/tip'
require_relative 'api/transaction'
require_relative 'api/transfer'
require_relative 'api/turn'
require_relative 'api/user'
require_relative 'api/withdraw'

module MixinBot
  ##
  # Main API interface for interacting with Mixin Network.
  #
  # The API class provides access to all Mixin Network endpoints including:
  # - User and bot profile management
  # - Asset management (read assets, check balances)
  # - Transfers and payments (Safe API and legacy)
  # - Messaging (send/receive messages via Blaze)
  # - Conversations and encrypted messages
  # - Multisig operations
  # - NFT and collectible operations
  # - Transaction building and signing
  # - Withdrawal operations
  #
  # == Usage
  #
  # === Using Global Configuration
  #
  #   MixinBot.configure do
  #     self.app_id = 'your-app-id'
  #     self.session_id = 'your-session-id'
  #     self.session_private_key = 'your-private-key'
  #     self.server_public_key = 'server-public-key'
  #   end
  #
  #   # Access via global instance
  #   MixinBot.api.me
  #   MixinBot.api.assets
  #
  # === Creating Dedicated Instances
  #
  #   api = MixinBot::API.new(
  #     app_id: 'your-app-id',
  #     session_id: 'your-session-id',
  #     session_private_key: 'your-private-key',
  #     server_public_key: 'server-public-key'
  #   )
  #
  #   api.me
  #   api.assets
  #
  # == API Categories
  #
  # === Profile & Users
  # - me, safe_me, update_me - Bot profile operations
  # - read_user, read_users, search_user - User lookup
  # - friends - List bot friends
  #
  # === Assets & Balance
  # - assets, asset - Read asset information
  # - ticker - Get asset ticker data
  # - safe_assets - Read Safe API assets
  #
  # === Transfers & Payments
  # - create_transfer, create_safe_transfer - Send payments
  # - build_safe_transaction - Build raw transactions
  # - sign_safe_transaction - Sign transactions
  # - send_safe_transaction - Submit signed transactions
  #
  # === Messaging
  # - start_blaze_connect - Connect to Blaze WebSocket
  # - send_message - Send text/data messages
  # - send_encrypted_messages - Send encrypted messages
  #
  # === Multisig & UTXOs
  # - safe_outputs - Read unspent outputs
  # - multisig_payments - Multisig payment operations
  # - safe_ghost_keys - Generate ghost keys
  #
  # === NFT & Collectibles
  # - create_collectible_request - Create NFT requests
  # - read_collectibles - Read collectible tokens
  # - inscriptions - Inscription operations
  #
  # == Examples
  #
  # Get bot information:
  #
  #   profile = MixinBot.api.me
  #   puts profile['full_name']
  #
  # Read assets:
  #
  #   assets = MixinBot.api.assets
  #   assets.each do |asset|
  #     puts "#{asset['symbol']}: #{asset['balance']}"
  #   end
  #
  # Send a transfer:
  #
  #   result = MixinBot.api.create_transfer(
  #     members: ['recipient-user-id'],
  #     threshold: 1,
  #     asset_id: 'asset-uuid',
  #     amount: '0.01',
  #     memo: 'Payment for services',
  #     trace_id: SecureRandom.uuid
  #   )
  #
  class API
    ##
    # @return [MixinBot::Configuration] the configuration for this API instance
    attr_reader :config

    ##
    # @return [MixinBot::Client] the HTTP client for making API requests
    attr_reader :client

    ##
    # Initializes a new API instance.
    #
    # If no parameters are provided, uses the global MixinBot configuration.
    # Otherwise, creates a new configuration with the provided parameters.
    #
    # @param kwargs [Hash] configuration options (see Configuration#initialize)
    # @option kwargs [String] :app_id the application ID
    # @option kwargs [String] :session_id the session ID
    # @option kwargs [String] :session_private_key the session private key
    # @option kwargs [String] :server_public_key the server public key
    # @option kwargs [String] :spend_key the spend private key (for Safe API)
    #
    # @example Using global configuration
    #   api = MixinBot::API.new
    #
    # @example With custom configuration
    #   api = MixinBot::API.new(
    #     app_id: 'your-app-id',
    #     session_id: 'your-session-id',
    #     session_private_key: 'your-private-key',
    #     server_public_key: 'server-public-key'
    #   )
    #
    def initialize(**kwargs)
      @config =
        if kwargs.present?
          MixinBot::Configuration.new(**kwargs)
        else
          MixinBot.config
        end

      @client = Client.new(@config)
    end

    ##
    # Provides access to utility methods.
    #
    # @return [Module] the Utils module
    #
    def utils
      MixinBot::Utils
    end

    ##
    # Returns the client ID (same as app_id).
    #
    # @return [String] the client ID
    #
    def client_id
      config.app_id
    end

    ##
    # Generates an access token for API authentication.
    #
    # Creates a JWT token signed with the bot's private key for authenticating
    # API requests. The token includes request details and has a limited lifetime.
    #
    # @param method [String] the HTTP method (GET, POST, etc.)
    # @param uri [String] the request URI path
    # @param body [String] the request body
    # @param kwargs [Hash] additional options
    # @option kwargs [Integer] :exp_in (600) token expiration time in seconds
    # @option kwargs [String] :scp ('FULL') token scope
    #
    # @return [String] the JWT access token
    #
    # @example
    #   token = api.access_token('GET', '/me', '')
    #
    def access_token(method, uri, body, **kwargs)
      utils.access_token(
        method,
        uri,
        body,
        exp_in: kwargs.delete(:exp_in) || 600,
        scp: kwargs.delete(:scp) || 'FULL',
        app_id: config.app_id,
        session_id: config.session_id,
        private_key: config.session_private_key
      )
    end
    alias sign_authentication_token access_token
    alias sign_authentication_token_without_body access_token
    alias sign_authentication_token_with_request_id access_token

    ##
    # Encodes a transaction hash to raw transaction format.
    #
    # @param txn [Hash] the transaction hash with keys: version, asset, inputs, outputs, extra
    # @return [String] the hex-encoded raw transaction
    #
    # @example
    #   raw = api.encode_raw_transaction(
    #     version: 5,
    #     asset: 'asset-id',
    #     inputs: [...],
    #     outputs: [...],
    #     extra: 'memo'
    #   )
    #
    def encode_raw_transaction(txn)
      utils.encode_raw_transaction txn
    end

    ##
    # Decodes a raw transaction to a hash.
    #
    # @param raw [String] the hex-encoded raw transaction
    # @return [Hash] the decoded transaction
    #
    # @example
    #   txn = api.decode_raw_transaction(raw_hex)
    #   puts txn['asset']
    #   puts txn['inputs']
    #
    def decode_raw_transaction(raw)
      utils.decode_raw_transaction raw
    end

    ##
    # Generates a trace ID from a transaction hash.
    #
    # Creates a deterministic UUID trace ID from a transaction hash,
    # useful for tracking outputs from a transaction.
    #
    # @param hash [String] the transaction hash
    # @param output_index [Integer] the output index (default: 0)
    # @return [String] the generated trace UUID
    #
    # @example
    #   trace_id = api.generate_trace_from_hash(tx_hash, 0)
    #
    def generate_trace_from_hash(hash, output_index = 0)
      utils.generate_trace_from_hash hash, output_index
    end

    ##
    # Encodes a raw transaction using native mixin command-line tool.
    #
    # Requires the 'mixin' command to be installed and available in PATH.
    # This is an alternative to the Ruby implementation.
    #
    # @param json [String] the transaction JSON
    # @return [String] the encoded raw transaction
    # @raise [RuntimeError] if mixin command is not available
    #
    def encode_raw_transaction_native(json)
      ensure_mixin_command_exist
      command = format("mixin signrawtransaction --raw '%<arg>s'", arg: json)

      output, error = Open3.capture3(command)
      raise error unless error.empty?

      output.chomp
    end

    ##
    # Decodes a raw transaction using native mixin command-line tool.
    #
    # Requires the 'mixin' command to be installed and available in PATH.
    # This is an alternative to the Ruby implementation.
    #
    # @param raw [String] the hex-encoded raw transaction
    # @return [Hash] the decoded transaction
    # @raise [RuntimeError] if mixin command is not available
    #
    def decode_raw_transaction_native(raw)
      ensure_mixin_command_exist
      command = format("mixin decoderawtransaction --raw '%<arg>s'", arg: raw)

      output, error = Open3.capture3(command)
      raise error unless error.empty?

      JSON.parse output.chomp
    end

    include MixinBot::API::Address
    include MixinBot::API::App
    include MixinBot::API::Asset
    include MixinBot::API::Attachment
    include MixinBot::API::Auth
    include MixinBot::API::Blaze
    include MixinBot::API::Chain
    include MixinBot::API::Code
    include MixinBot::API::Circle
    include MixinBot::API::ComputerApi
    include MixinBot::API::Conversation
    include MixinBot::API::Deposit
    include MixinBot::API::EncryptedMessage
    include MixinBot::API::External
    include MixinBot::API::Fiat
    include MixinBot::API::Inscription
    include MixinBot::API::LegacyCollectible
    include MixinBot::API::LegacyUser
    include MixinBot::API::LegacyMultisig
    include MixinBot::API::LegacyOutput
    include MixinBot::API::LegacyPayment
    include MixinBot::API::LegacySnapshot
    include MixinBot::API::LegacyTransaction
    include MixinBot::API::LegacyTransfer
    include MixinBot::API::Me
    include MixinBot::API::Message
    include MixinBot::API::Multisig
    include MixinBot::API::Network
    include MixinBot::API::NetworkAsset
    include MixinBot::API::Output
    include MixinBot::API::Payment
    include MixinBot::API::Pin
    include MixinBot::API::Rpc
    include MixinBot::API::Session
    include MixinBot::API::Snapshot
    include MixinBot::API::Tip
    include MixinBot::API::PinPayload
    include MixinBot::API::Transaction
    include MixinBot::API::Transfer
    include MixinBot::API::Turn
    include MixinBot::API::User
    include MixinBot::API::Withdraw

    private

    def warn_legacy_mixin_api!(api_label)
      MixinBot.deprecator.warn(
        "MixinBot legacy API #{api_label} is deprecated; migrate to the Safe API. See CHANGELOG for 2.0.0."
      )
    end

    def ensure_mixin_command_exist
      return if command?('mixin')

      raise '`mixin` command is not valid!'
    end

    def command?(name)
      `which #{name}`
      $CHILD_STATUS.success?
    end
  end
end
