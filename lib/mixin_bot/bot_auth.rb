# frozen_string_literal: true

module MixinBot
  # Bot platform request signing (parity with Go BotAuthClient).
  class BotAuth
    class MapCache
      def initialize
        @store = {}
      end

      def get(key)
        @store[key]
      end

      def put(key, value)
        @store[key] = value
      end

      def delete(key)
        @store.delete(key)
      end
    end

    class Client
      PLATFORM_PREFIX = 'up_'

      def initialize(api, cache: MapCache.new)
        @api = api
        @cache = cache
      end

      def sign_request(timestamp, bot_user_id, method, uri, body = nil)
        shared_key = shared_key_for(bot_user_id)
        data = "#{timestamp}#{method}#{uri}"
        data += body.to_s if body.present?
        digest = OpenSSL::HMAC.digest('SHA256', shared_key, data)
        Base64.urlsafe_encode64(@api.config.app_id.b + digest, padding: false)
      end

      private

      def shared_key_for(user_id)
        cached = @cache.get(user_id)
        return cached if cached.present? && cached.bytesize >= 32

        sessions = @api.fetch_user_sessions([user_id])['data']
        session = Array(sessions).first
        raise MixinBot::NotFoundError, "no session for #{user_id}" if session.nil?

        u_pk = Base64.urlsafe_decode64(session['public_key'])
        sk = @api.config.session_private_key_curve25519
        shared = JOSE::JWA::X25519.x25519(sk, u_pk[0, 32])
        @cache.put(user_id, shared)
        @cache.put("#{PLATFORM_PREFIX}#{user_id}", session['platform'].to_s.b) if session['platform']
        shared
      end
    end

    def self.new_map_cache
      MapCache.new
    end

    def self.new_client(api, cache: MapCache.new)
      Client.new(api, cache:)
    end

    def self.new_default_client(api, cache: MapCache.new)
      new_client(api, cache:)
    end
  end
end
