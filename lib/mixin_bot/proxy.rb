# frozen_string_literal: true

require 'base64'
require 'uri'

module MixinBot
  ##
  # Immutable HTTP/HTTPS proxy configuration parsed from a String, URI, Hash, or Proxy.
  #
  class Proxy
    SUPPORTED_SCHEMES = %w[http https].freeze
    ALLOWED_HASH_KEYS = %i[uri user password].freeze

    attr_reader :uri, :user, :password

    class << self
      ##
      # Parses a proxy specification into a {MixinBot::Proxy}, or returns +nil+ for +nil+/blank strings.
      #
      # @param value [String, URI, Hash, MixinBot::Proxy, nil]
      # @return [MixinBot::Proxy, nil]
      # @raise [MixinBot::ArgumentError] when the proxy format or scheme is invalid
      #
      def parse(value)
        case value
        when nil
          nil
        when self
          value
        when String
          stripped = value.strip
          return nil if stripped.empty?

          parse_uri_and_build(stripped)
        when URI
          build_from_uri(value)
        when Hash
          parse_hash(value)
        else
          raise ArgumentError, "proxy must be a String, URI, Hash, or MixinBot::Proxy, got #{value.class}"
        end
      end

      private

      def parse_uri_and_build(raw_uri, user_override: nil, password_override: nil)
        parsed = URI.parse(raw_uri)
        build_from_uri(parsed, user_override:, password_override:)
      rescue URI::InvalidURIError => e
        raise ArgumentError, "invalid proxy URI: #{e.message}"
      end

      def build_from_uri(parsed, user_override: nil, password_override: nil)
        scheme = parsed.scheme&.downcase
        unless SUPPORTED_SCHEMES.include?(scheme)
          raise ArgumentError, "unsupported proxy scheme: #{parsed.scheme.inspect} (expected http or https)"
        end

        raise ArgumentError, 'proxy URI must include a host' if parsed.host.nil? || parsed.host.empty?

        normalized = parsed.dup.normalize
        uri_user = normalized.user ? URI::DEFAULT_PARSER.unescape(normalized.user) : nil
        uri_password = normalized.password ? URI::DEFAULT_PARSER.unescape(normalized.password) : nil

        clean_uri = normalized.dup
        clean_uri.user = nil
        clean_uri.password = nil

        new(
          uri: clean_uri,
          user: user_override.nil? ? uri_user : user_override.to_s,
          password: password_override.nil? ? uri_password : password_override.to_s
        )
      end

      def parse_hash(hash)
        symbolized = hash.transform_keys { |k| k.is_a?(Symbol) || k.is_a?(String) ? k.to_sym : k }
        unknown = symbolized.keys - ALLOWED_HASH_KEYS
        raise ArgumentError, "unknown proxy option(s): #{unknown.join(', ')}" unless unknown.empty?

        raw_uri = symbolized[:uri]
        raise ArgumentError, 'proxy hash must include a non-empty :uri' if raw_uri.nil? || (raw_uri.is_a?(String) && raw_uri.strip.empty?)

        user_override = symbolized[:user]
        password_override = symbolized[:password]

        case raw_uri
        when String
          parse_uri_and_build(raw_uri.strip, user_override:, password_override:)
        when URI
          build_from_uri(raw_uri, user_override:, password_override:)
        else
          raise ArgumentError, "proxy :uri must be a String or URI, got #{raw_uri.class}"
        end
      end
    end

    def initialize(uri:, user: nil, password: nil)
      clean = uri.dup
      clean.user = nil
      clean.password = nil
      @uri = clean.freeze
      @user = user.nil? ? nil : user.to_s.freeze
      @password = password.nil? ? nil : password.to_s.freeze
      freeze
    end

    def scheme
      uri.scheme
    end

    def host
      uri.host
    end

    def hostname
      uri.hostname
    end

    def port
      uri.port
    end

    def https?
      scheme == 'https'
    end

    def origin
      "#{scheme}://#{host}:#{port}"
    end

    def basic_auth_header
      return nil if user.nil?

      "Basic #{Base64.strict_encode64("#{user}:#{password}")}"
    end

    def faraday_options
      opts = { uri: uri }
      opts[:user] = user unless user.nil?
      opts[:password] = password unless password.nil?
      opts
    end

    def faye_options
      opts = { origin: origin }
      auth = basic_auth_header
      opts[:headers] = { 'Proxy-Authorization' => auth } if auth
      opts
    end

    def connect_headers(authority)
      headers = { 'Host' => authority }
      auth = basic_auth_header
      headers['Proxy-Authorization'] = auth if auth
      headers
    end

    def ==(other)
      other.is_a?(self.class) && uri == other.uri && user == other.user && password == other.password
    end
    alias eql? ==

    def hash
      [uri, user, password].hash
    end

    def to_s
      origin
    end

    def inspect
      if user && password
        "#<#{self.class} #{scheme}://#{user}:***@#{host}:#{port}>"
      elsif user
        "#<#{self.class} #{scheme}://#{user}@#{host}:#{port}>"
      elsif password
        "#<#{self.class} #{scheme}://:***@#{host}:#{port}>"
      else
        "#<#{self.class} #{origin}>"
      end
    end
  end
end
