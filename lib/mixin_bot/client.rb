# frozen_string_literal: true

require_relative 'client/error_mapper'

module MixinBot
  ##
  # HTTP client for making requests to the Mixin Network API.
  #
  class Client
    SERVER_SCHEME = 'https'

    attr_reader :config, :conn

    def initialize(config)
      @config = config || MixinBot.config
      @conn = Faraday.new(
        url: "#{SERVER_SCHEME}://#{config.api_host}",
        headers: {
          'Content-Type' => 'application/json',
          'User-Agent' => "mixin_bot/#{MixinBot::VERSION}"
        }
      ) do |f|
        f.request :json
        f.request :retry, max: 2, interval: 0.5, interval_randomness: 0.5, backoff_factor: 2,
                          exceptions: [Faraday::ConnectionFailed, Faraday::TimeoutError]
        f.response :json
        f.response :logger if config.debug
      end
    end

    ##
    # GET request. Remaining keyword arguments are treated as query-string parameters.
    #
    # @return [MixinBot::Models::ApiEnvelope]
    #
    def get(path, **kwargs)
      access_token = kwargs.delete(:access_token)
      exp_in = kwargs.delete(:exp_in) || 600
      scp = kwargs.delete(:scp) || 'FULL'

      kwargs.compact!
      body = ''
      full_path = kwargs.empty? ? path : "#{path}?#{URI.encode_www_form(kwargs.sort_by { |k, _| k.to_s })}"

      token = access_token.presence || sign_token('GET', full_path, body, exp_in:, scp:)
      response = @conn.get(full_path, nil, authorization_headers(token))
      parse_response!(verb: 'GET', path: full_path, body:, response:)
    end

    ##
    # POST with a Hash body (+**kwargs+ merged into JSON object) or an Array body (+*args+).
    #
    # @return [MixinBot::Models::ApiEnvelope]
    #
    def post(path, *args, **kwargs)
      access_token = kwargs.delete(:access_token)
      exp_in = kwargs.delete(:exp_in) || 600
      scp = kwargs.delete(:scp) || 'FULL'

      body =
        if args.present?
          args.to_json
        else
          kwargs.compact.to_json
        end

      token = access_token.presence || sign_token('POST', path, body, exp_in:, scp:)
      response = @conn.post(path, body, authorization_headers(token))
      parse_response!(verb: 'POST', path:, body:, response:)
    end

    ##
    # Explicit query-string GET (preferred for new code).
    #
    def fetch_get(path, query: nil, access_token: nil, exp_in: 600, scp: 'FULL')
      q = (query || {}).dup
      q.compact!
      body = ''
      full_path = q.empty? ? path : "#{path}?#{URI.encode_www_form(q.sort_by { |k, _| k.to_s })}"
      token = access_token.presence || sign_token('GET', full_path, body, exp_in:, scp:)
      response = @conn.get(full_path, nil, authorization_headers(token))
      parse_response!(verb: 'GET', path: full_path, body:, response:)
    end

    ##
    # Explicit JSON-object POST (preferred for new code).
    #
    def fetch_post(path, body:, access_token: nil, exp_in: 600, scp: 'FULL')
      payload = body.is_a?(String) ? body : body.compact.to_json
      token = access_token.presence || sign_token('POST', path, payload, exp_in:, scp:)
      response = @conn.post(path, payload, authorization_headers(token))
      parse_response!(verb: 'POST', path:, body: payload, response:)
    end

    ##
    # Explicit JSON-array POST (e.g. +/users/fetch+, +/safe/keys+).
    #
    def fetch_post_array(path, array_body, access_token: nil, exp_in: 600, scp: 'FULL')
      payload = array_body.to_json
      token = access_token.presence || sign_token('POST', path, payload, exp_in:, scp:)
      response = @conn.post(path, payload, authorization_headers(token))
      parse_response!(verb: 'POST', path:, body: payload, response:)
    end

    private

    def authorization_headers(token)
      return {} if token.blank?

      { Authorization: format('Bearer %<access_token>s', access_token: token) }
    end

    def sign_token(method, uri, body, exp_in:, scp:)
      MixinBot.utils.access_token(
        method,
        uri,
        body,
        exp_in:,
        scp:,
        app_id: config.app_id,
        session_id: config.session_id,
        private_key: config.session_private_key
      )
    end

    def parse_response!(verb:, path:, body:, response:)
      result = response.body
      result = {} unless result.is_a?(Hash)

      if result['error'].blank?
        raise_http_status_error!(verb:, path:, body:, response:) if http_error_status?(response.status)
        return MixinBot::Models::ApiEnvelope.new(result)
      end

      ErrorMapper.raise_for!(verb:, path:, body:, response:, result:)
    end

    def http_error_status?(status)
      [401, 403, 429].include?(status) || status >= 500
    end

    def raise_http_status_error!(verb:, path:, body:, response:)
      klass =
        case response.status
        when 429 then RateLimitError
        when 401 then UnauthorizedError
        when 403 then ForbiddenError
        else ServerError
        end

      raise ErrorMapper.build(klass, verb:, path:, body:, response:, result: {})
    end
  end
end
