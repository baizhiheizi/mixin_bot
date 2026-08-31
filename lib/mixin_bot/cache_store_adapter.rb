# frozen_string_literal: true

module MixinBot
  ##
  # Adapter that lets any ActiveSupport::Cache-style store (Rails.cache with a
  # Redis/Memcached/solid_cache backend, or a hand-rolled read/write/delete
  # object) back the encrypted-message session cache.
  #
  # API#post_encrypted_messages expects a store answering +fetch(user_id)+ and
  # +store(user_id, sessions)+, where storing +nil+ evicts. ActiveSupport
  # caches speak read/write/delete instead, so this adapter translates:
  #
  #   session_store: MixinBot::CacheStoreAdapter.new(Rails.cache, expires_in: 12.hours)
  #
  # The +expires_in:+ option is passed through to +cache.write+ as a TTL; the
  # pipeline's one-shot expiry retry covers entries that lapse between fetch
  # and send.
  #
  class CacheStoreAdapter
    KEY_PREFIX = 'mixin_bot/sessions'

    def initialize(cache = nil, expires_in: nil)
      cache ||= Rails.cache if defined?(Rails)
      raise ArgumentError, 'a cache store is required' if cache.nil?

      @cache = cache
      @expires_in = expires_in
    end

    # Returns the cached session list for the recipient, or nil on a miss.
    # A block passed by the caller is intentionally ignored: the block form of
    # Rails' fetch means read-through caching, which is not wanted here.
    def fetch(user_id)
      @cache.read("#{KEY_PREFIX}/#{user_id}")
    end

    # Writes the session list for the recipient; +nil+ evicts the entry.
    def store(user_id, sessions)
      key = "#{KEY_PREFIX}/#{user_id}"
      if sessions.nil?
        @cache.delete(key)
      elsif @expires_in
        @cache.write(key, sessions, expires_in: @expires_in)
      else
        @cache.write(key, sessions)
      end
    end
  end
end
