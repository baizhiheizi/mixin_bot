# frozen_string_literal: true

require 'test_helper'

module MixinBot
  # Minimal ActiveSupport::Cache-shaped double: read/write/delete only.
  class FakeCache
    attr_reader :calls

    def initialize
      @entries = {}
      @calls = []
    end

    def read(key)
      @entries[key]
    end

    def write(key, value, options = {})
      @calls << [:write, key, options]
      @entries[key] = value
    end

    def delete(key)
      @calls << [:delete, key]
      @entries.delete(key)
    end
  end

  class TestCacheStoreAdapter < Minitest::Test
    include WebMock::API
    include EncryptedMessageStubHelpers

    def setup
      super
      MixinBot.api.remove_instance_variable(:@session_store) if MixinBot.api.instance_variable_defined?(:@session_store)
    end

    def test_requires_a_cache
      assert_raises(ArgumentError) { CacheStoreAdapter.new }
    end

    def test_store_and_fetch_round_trip
      adapter = CacheStoreAdapter.new(FakeCache.new)
      sessions = [{ 'session_id' => 's1' }]

      adapter.store('user-1', sessions)

      assert_equal sessions, adapter.fetch('user-1')
    end

    def test_store_nil_evicts
      cache = FakeCache.new
      adapter = CacheStoreAdapter.new(cache)
      adapter.store('user-1', [{ 'session_id' => 's1' }])

      adapter.store('user-1', nil)

      assert_nil adapter.fetch('user-1')
      assert_equal [:delete, 'mixin_bot/sessions/user-1'], cache.calls.last
    end

    def test_expires_in_is_passed_through_to_writes
      cache = FakeCache.new
      adapter = CacheStoreAdapter.new(cache, expires_in: 600)

      adapter.store('user-1', [{ 'session_id' => 's1' }])

      assert_equal 600, cache.calls.last[2][:expires_in]
    end

    def test_pipeline_caches_sessions_in_the_cache_store_across_calls
      recipient_id = SecureRandom.uuid
      mid1 = SecureRandom.uuid
      mid2 = SecureRandom.uuid
      sessions = make_sessions(recipient_id)
      cache = FakeCache.new
      stub_sessions_fetch(recipient_id => sessions)
      stub_encrypted_messages(
        [response_entry(mid1, recipient_id, 'SUCCESS')],
        [response_entry(mid2, recipient_id, 'SUCCESS')]
      )

      MixinBot.api.post_encrypted_messages(
        [{ recipient_id:, category: 'ENCRYPTED_TEXT', data: '1', message_id: mid1 }],
        session_store: CacheStoreAdapter.new(cache)
      )
      MixinBot.api.post_encrypted_messages(
        [{ recipient_id:, category: 'ENCRYPTED_TEXT', data: '2', message_id: mid2 }],
        session_store: CacheStoreAdapter.new(cache)
      )

      assert_requested :post, 'https://api.mixin.one/sessions/fetch', times: 1
      assert_equal sessions.map(&:stringify_keys), cache.read("mixin_bot/sessions/#{recipient_id}")
    end

    def test_pipeline_evicts_and_refreshes_expired_sessions_in_the_cache_store
      recipient_id = SecureRandom.uuid
      message_id = SecureRandom.uuid
      stale = make_sessions(recipient_id)
      fresh = make_sessions(recipient_id)
      cache = FakeCache.new
      cache.write("mixin_bot/sessions/#{recipient_id}", stale)
      stub_sessions_fetch(recipient_id => fresh)
      stub_encrypted_messages(
        [response_entry(message_id, recipient_id, 'FAILED')],
        [response_entry(message_id, recipient_id, 'SUCCESS')]
      )

      r = MixinBot.api.post_encrypted_messages(
        [{ recipient_id:, category: 'ENCRYPTED_TEXT', data: 'x', message_id: }],
        session_store: CacheStoreAdapter.new(cache)
      )

      assert_equal 'SUCCESS', r['data'].first['state']
      assert_includes cache.calls, [:delete, "mixin_bot/sessions/#{recipient_id}"]
      assert_equal fresh.map(&:stringify_keys), cache.read("mixin_bot/sessions/#{recipient_id}")
      assert_requested :post, 'https://api.mixin.one/sessions/fetch', times: 1
    end
  end
end
