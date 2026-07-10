# frozen_string_literal: true

require 'test_helper'

module MixinBot
  ##
  # Offline unit tests for +MixinBot::BotAuth+ — the small module that holds
  # the platform request-signing primitives mirrored from the Go +BotAuthClient+.
  #
  # Coverage here intentionally stays offline. The two test classes have
  # intentionally narrow surface areas:
  #
  # * +BotAuth::MapCache+ — a tiny in-memory key/value store (3 public methods).
  # * +BotAuth::Client+   — wraps an +api+ and a +cache+ to produce HMAC-signed
  #   request tokens for the Mixin bot platform. Its only public method is
  #   +sign_request+, which is exercised here both via the fast-cache and the
  #   slow-cache (session fetch) paths.
  #
  # The cache short-circuit (32-byte cached +shared_key+) is fully tested by
  # pre-populating the +MapCache+ and then calling +sign_request+. The slow
  # path is verified only on the "no session" failure case — that exercises
  # +fetch_user_sessions+ without depending on a real Curve25519 agreement.
  class TestBotAuth < Minitest::Test
    include WebMock::API

    # ===== BotAuth::MapCache ==============================================

    def test_map_cache_put_and_get_round_trips
      cache = MixinBot::BotAuth::MapCache.new
      cache.put('user-1', 'value-1')

      assert_equal 'value-1', cache.get('user-1')
    end

    def test_map_cache_get_returns_nil_for_missing_key
      cache = MixinBot::BotAuth::MapCache.new

      assert_nil cache.get('not-there')
    end

    def test_map_cache_delete_removes_entry
      cache = MixinBot::BotAuth::MapCache.new
      cache.put('user-1', 'value-1')
      cache.delete('user-1')

      assert_nil cache.get('user-1')
    end

    def test_map_cache_delete_is_a_no_op_for_missing_key
      cache = MixinBot::BotAuth::MapCache.new

      cache.delete('not-there') # must not raise
      assert_nil cache.get('not-there')
    end

    def test_map_cache_overwrite_replaces_value
      cache = MixinBot::BotAuth::MapCache.new
      cache.put('user-1', 'first')
      cache.put('user-1', 'second')

      assert_equal 'second', cache.get('user-1')
    end

    # ===== BotAuth module-level factories =================================

    def test_new_map_cache_returns_a_fresh_instance
      a = MixinBot::BotAuth.new_map_cache
      b = MixinBot::BotAuth.new_map_cache

      assert_kind_of MixinBot::BotAuth::MapCache, a
      refute_same a, b
    end

    def test_new_client_returns_a_client_wrapping_the_api
      client = MixinBot::BotAuth.new_client(MixinBot.api)

      assert_kind_of MixinBot::BotAuth::Client, client
    end

    def test_new_default_client_is_an_alias_for_new_client
      a = MixinBot::BotAuth.new_default_client(MixinBot.api)
      b = MixinBot::BotAuth.new_client(MixinBot.api)

      assert_kind_of MixinBot::BotAuth::Client, a
      assert_kind_of MixinBot::BotAuth::Client, b
    end

    def test_new_client_uses_provided_cache_when_supplied
      cache = MixinBot::BotAuth::MapCache.new
      client = MixinBot::BotAuth.new_client(MixinBot.api, cache: cache)

      assert_same cache, client.instance_variable_get(:@cache)
    end

    # ===== BotAuth::Client#sign_request — fast path (cache populated) ======

    def test_sign_request_uses_cached_shared_key_when_present
      cache = MixinBot::BotAuth::MapCache.new
      cached_shared_key = ([0xAA].pack('C*') * 32).b # 32 bytes raw
      cache.put(TEST_UID, cached_shared_key)

      client = MixinBot::BotAuth::Client.new(MixinBot.api, cache: cache)
      token = client.sign_request(
        '1700000000000',
        TEST_UID,
        'GET',
        '/bot/users/me'
      )

      # The token is +Base64.urlsafe_encode64(app_id.b + HMAC-SHA256)+,
      # padding-free and url-safe. +app_id+ is stored as a UTF-8 string
      # (typically a 36-byte UUID), so the decoded buffer length depends on
      # the configured app_id.
      decoded = Base64.urlsafe_decode64(token)
      app_id_bytes = MixinBot.api.config.app_id.b
      assert_equal app_id_bytes.bytesize + 32, decoded.bytesize,
                   "expected app_id.b (#{app_id_bytes.bytesize} B) + HMAC-SHA256 (32 B)"
      assert_equal app_id_bytes, decoded[0, app_id_bytes.bytesize]
    end

    def test_sign_request_signature_changes_with_each_input_field
      cache = MixinBot::BotAuth::MapCache.new
      cache.put(TEST_UID, ([0xBB].pack('C*') * 32).b)
      cache.put(TEST_UID_2, ([0xCC].pack('C*') * 32).b)
      client = MixinBot::BotAuth::Client.new(MixinBot.api, cache: cache)

      base = client.sign_request('100', TEST_UID, 'GET', '/u')
      diff_method = client.sign_request('100', TEST_UID, 'POST', '/u')
      diff_uri = client.sign_request('100', TEST_UID, 'GET', '/v')
      diff_ts = client.sign_request('101', TEST_UID, 'GET', '/u')
      diff_uid = client.sign_request('100', TEST_UID_2, 'GET', '/u')
      diff_body = client.sign_request('100', TEST_UID, 'GET', '/u', 'payload')

      tokens = [base, diff_method, diff_uri, diff_ts, diff_uid, diff_body]
      assert_equal tokens.uniq.size, tokens.size,
                   'expected every varying input to produce a distinct signature'
    end

    def test_sign_request_includes_body_in_signature_payload
      cache = MixinBot::BotAuth::MapCache.new
      cache.put(TEST_UID, ([0xCC].pack('C*') * 32).b)
      client = MixinBot::BotAuth::Client.new(MixinBot.api, cache: cache)

      without_body = client.sign_request('100', TEST_UID, 'POST', '/u')
      with_empty_body = client.sign_request('100', TEST_UID, 'POST', '/u', '')
      with_body = client.sign_request('100', TEST_UID, 'POST', '/u', 'hello')

      refute_equal without_body, with_body
      refute_equal with_empty_body, with_body
      # An empty/nil body is treated identically — both omit body content.
      assert_equal without_body, with_empty_body
    end

    def test_sign_request_token_is_urlsafe_base64_without_padding
      cache = MixinBot::BotAuth::MapCache.new
      cache.put(TEST_UID, ([0xDD].pack('C*') * 32).b)
      client = MixinBot::BotAuth::Client.new(MixinBot.api, cache: cache)

      token = client.sign_request('100', TEST_UID, 'GET', '/u')

      assert_match(/\A[A-Za-z0-9_-]+\z/, token)
      refute_match(/=/, token, 'expected urlsafe_base64 WITHOUT padding')
    end

    def test_sign_request_recomputes_signature_when_only_cached_value_is_short
      # Cached shared_keys shorter than 32 bytes are *not* trusted — the
      # module falls through to fetch_user_sessions in that case.
      cache = MixinBot::BotAuth::MapCache.new
      cache.put(TEST_UID, 'short') # only 5 bytes

      stub_request(:post, 'https://api.mixin.one/sessions/fetch')
        .to_return(status: 200, body: '{"data":[]}', headers: { 'Content-Type' => 'application/json' })

      client = MixinBot::BotAuth::Client.new(MixinBot.api, cache: cache)

      assert_raises(MixinBot::NotFoundError) do
        client.sign_request('100', TEST_UID, 'GET', '/u')
      end
    end

    # ===== BotAuth::Client#sign_request — slow path (no session) ===========

    def test_sign_request_raises_not_found_when_no_session_exists
      stub_request(:post, 'https://api.mixin.one/sessions/fetch')
        .to_return(status: 200, body: '{"data":[]}', headers: { 'Content-Type' => 'application/json' })

      client = MixinBot::BotAuth::Client.new(MixinBot.api) # fresh empty cache
      err = assert_raises(MixinBot::NotFoundError) do
        client.sign_request('100', TEST_UID, 'GET', '/u')
      end

      assert_match(/no session for #{Regexp.escape(TEST_UID)}/, err.message)
    end

    def test_sign_request_after_slow_path_failure_does_not_overwrite_short_cache
      # A short cached value (below the 32-byte minimum) is not trusted.
      # When the session-fetch fallback also fails, the original short
      # value should remain in the cache — the failed lookup must NOT
      # overwrite it with a partial (or zero-length) shared key.
      stub_request(:post, 'https://api.mixin.one/sessions/fetch')
        .to_return(status: 200, body: '{"data":[]}', headers: { 'Content-Type' => 'application/json' })

      cache = MixinBot::BotAuth::MapCache.new
      cache.put(TEST_UID, 'short') # 5 bytes — below the 32-byte threshold
      client = MixinBot::BotAuth::Client.new(MixinBot.api, cache: cache)

      assert_raises(MixinBot::NotFoundError) do
        client.sign_request('100', TEST_UID, 'GET', '/u')
      end

      assert_equal 'short', cache.get(TEST_UID),
                   'failed session fetch must not overwrite the cache'
    end
  end
end
