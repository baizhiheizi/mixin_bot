# frozen_string_literal: true

module MixinBot
  ##
  # In-memory cache of recipient sessions for encrypted-message sending.
  #
  # Mirrors the Go SDK's +MapSessionStore+: +fetch+ returns the cached session
  # list for a recipient user (or nil on a miss) and +store+ overwrites it.
  # Any object answering both calls can be passed as +session_store:+ to
  # API#post_encrypted_messages to plug in custom caching (e.g. Redis, TTLs).
  #
  class SessionStore
    def initialize
      @sessions = {}
    end

    def fetch(user_id)
      @sessions[user_id]
    end

    def store(user_id, sessions)
      @sessions[user_id] = sessions
    end
  end
end
