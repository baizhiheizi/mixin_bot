# frozen_string_literal: true

require_relative '../mixin_bot/proxy'

module MVM
  ##
  # HTTP client for MVM services.
  #
  # Handles HTTP communication with MVM services including:
  # - Bridge service
  # - NFT service
  # - Registry service
  # - Scan service
  #
  # == Features
  #
  # - Automatic JSON encoding/decoding
  # - Request retry on failures
  # - Error handling with exceptions
  # - Debug logging
  #
  # == Usage
  #
  #   client = MVM::Client.new('bridge.mvm.dev')
  #   response = client.get('/info')
  #   response = client.post('/users', public_key: '0x...')
  #
  class Client
    ##
    # The HTTPS scheme for all MVM requests.
    SERVER_SCHEME = 'https'

    ##
    # @return [String] the service host
    attr_reader :host

    ##
    # Initializes a new MVM Client.
    #
    # Sets up HTTP connection with:
    # - JSON request/response handling
    # - Automatic retry on failures
    # - Error raising on HTTP errors
    # - Debug logging
    #
    # @param host [String] the service hostname
    # @param proxy [String, URI, Hash, MixinBot::Proxy, nil] optional HTTP/HTTPS proxy override
    #
    # @example
    #   client = MVM::Client.new('bridge.mvm.dev')
    #
    def initialize(host, proxy: nil)
      @host = host
      @proxy = proxy
      @conn_mutex = Mutex.new
      rebuild_connection!
    end

    ##
    # Returns the Faraday connection, rebuilding it when effective proxy changes.
    #
    # @return [Faraday::Connection]
    #
    def conn
      effective = effective_proxy_config
      return @conn if @conn && @conn_proxy == effective

      @conn_mutex.synchronize do
        effective = effective_proxy_config
        rebuild_connection!(effective) if @conn.nil? || @conn_proxy != effective
        @conn
      end
    end

    ##
    # Performs a GET request.
    #
    # @param path [String] the request path
    # @param kwargs [Hash] query parameters
    # @return [Hash] the parsed response body
    #
    # @example
    #   response = client.get('/info')
    #
    def get(path, **)
      conn.get(path, **).body
    end

    ##
    # Performs a POST request.
    #
    # @param path [String] the request path
    # @param kwargs [Hash] request body parameters
    # @return [Hash] the parsed response body
    #
    # @example
    #   response = client.post('/users', public_key: '0x...')
    #
    def post(path, **)
      conn.post(path, **).body
    end

    private

    def effective_proxy_config
      @proxy.nil? ? MixinBot.config.proxy_config : MixinBot::Proxy.parse(@proxy)
    end

    def rebuild_connection!(proxy_config = effective_proxy_config)
      conn_opts = { url: "#{SERVER_SCHEME}://#{host}" }
      conn_opts[:proxy] = proxy_config.faraday_options if proxy_config

      @conn = Faraday.new(**conn_opts) do |f|
        f.request :json
        f.request :retry
        f.response :raise_error
        f.response :logger
        f.response :json
      end
      @conn_proxy = proxy_config
    end
  end
end
