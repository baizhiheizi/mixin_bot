# frozen_string_literal: true

require 'test_helper'

module MixinBot
  class TestSessionStore < Minitest::Test
    def test_fetch_returns_nil_on_cache_miss
      store = SessionStore.new

      assert_nil store.fetch('user-1')
    end

    def test_fetch_returns_stored_sessions_on_hit
      store = SessionStore.new
      sessions = [{ 'session_id' => 's1' }]
      store.store('user-1', sessions)

      assert_equal sessions, store.fetch('user-1')
    end

    def test_store_overwrites_previous_sessions
      store = SessionStore.new
      store.store('user-1', [{ 'session_id' => 'stale' }])
      fresh = [{ 'session_id' => 'fresh' }]
      store.store('user-1', fresh)

      assert_equal fresh, store.fetch('user-1')
    end

    def test_users_are_isolated
      store = SessionStore.new
      store.store('user-1', [{ 'session_id' => 's1' }])
      store.store('user-2', [{ 'session_id' => 's2' }])

      assert_equal 's1', store.fetch('user-1').first['session_id']
      assert_equal 's2', store.fetch('user-2').first['session_id']
    end
  end
end
