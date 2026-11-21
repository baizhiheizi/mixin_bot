# frozen_string_literal: true

require 'test_helper'
require 'base64'

module MixinBot
  class TestProxy < Minitest::Test
    def test_parse_returns_nil_for_nil_or_blank_string
      assert_nil Proxy.parse(nil)
      assert_nil Proxy.parse('')
      assert_nil Proxy.parse("  \t\n ")
    end

    def test_parse_string_without_credentials
      proxy = Proxy.parse('  http://127.0.0.1:7890  ')

      assert_instance_of Proxy, proxy
      assert_equal 'http', proxy.scheme
      assert_equal '127.0.0.1', proxy.host
      assert_equal '127.0.0.1', proxy.hostname
      assert_equal 7890, proxy.port
      assert_nil proxy.user
      assert_nil proxy.password
      assert_equal false, proxy.https?
      assert_equal 'http://127.0.0.1:7890', proxy.origin
      assert_equal 'http://127.0.0.1:7890', proxy.to_s
      assert_nil proxy.basic_auth_header
      assert_equal({ uri: proxy.uri }, proxy.faraday_options)
      assert_equal({ origin: 'http://127.0.0.1:7890' }, proxy.faye_options)
      assert_equal({ 'Host' => 'api.mixin.one:443' }, proxy.connect_headers('api.mixin.one:443'))
      assert_predicate proxy, :frozen?
    end

    def test_parse_string_with_encoded_credentials_and_https_default_port
      proxy = Proxy.parse('HTTPS://alice%40example:p%3Ass%21@proxy.example.com')

      assert_equal 'https', proxy.scheme
      assert_equal 'proxy.example.com', proxy.host
      assert_equal 443, proxy.port
      assert_equal true, proxy.https?
      assert_equal 'alice@example', proxy.user
      assert_equal 'p:ss!', proxy.password
      assert_nil proxy.uri.userinfo
      assert_equal 'https://proxy.example.com:443', proxy.origin

      expected_auth = "Basic #{Base64.strict_encode64('alice@example:p:ss!')}"
      assert_equal expected_auth, proxy.basic_auth_header
      assert_equal({ uri: proxy.uri, user: 'alice@example', password: 'p:ss!' }, proxy.faraday_options)
      assert_equal(
        { origin: 'https://proxy.example.com:443', headers: { 'Proxy-Authorization' => expected_auth } },
        proxy.faye_options
      )
      assert_equal(
        { 'Host' => 'blaze.mixin.one:443', 'Proxy-Authorization' => expected_auth },
        proxy.connect_headers('blaze.mixin.one:443')
      )
    end

    def test_parse_user_without_password_preserves_nil_password
      proxy = Proxy.parse('http://alice@127.0.0.1:7890')

      assert_equal 'alice', proxy.user
      assert_nil proxy.password
      assert_equal "Basic #{Base64.strict_encode64('alice:')}", proxy.basic_auth_header
      assert_equal({ uri: proxy.uri, user: 'alice' }, proxy.faraday_options)
    end

    def test_parse_uri_and_proxy_passthrough
      uri = URI.parse('http://127.0.0.1').freeze
      proxy = Proxy.parse(uri)

      assert_equal 80, proxy.port
      assert_equal 'http://127.0.0.1:80', proxy.origin
      assert_same proxy, Proxy.parse(proxy)
    end

    def test_parse_ipv6_literal_host
      proxy = Proxy.parse('http://[::1]:7890')

      assert_equal '[::1]', proxy.host
      assert_equal '::1', proxy.hostname
      assert_equal 7890, proxy.port
      assert_equal 'http://[::1]:7890', proxy.origin
    end

    def test_parse_hash_with_symbol_and_string_keys_and_overrides
      proxy = Proxy.parse('uri' => 'http://old:oldpass@127.0.0.1:7890', 'user' => 'new_user', 'password' => 'new_pass')

      assert_equal 'new_user', proxy.user
      assert_equal 'new_pass', proxy.password
      assert_equal 'http://127.0.0.1:7890', proxy.origin

      partial = Proxy.parse(uri: URI.parse('http://alice:old@127.0.0.1:7890'), password: 'updated')
      assert_equal 'alice', partial.user
      assert_equal 'updated', partial.password
    end

    def test_value_equality_and_hash
      a = Proxy.parse('http://user:pass@127.0.0.1:7890')
      b = Proxy.parse(uri: 'HTTP://127.0.0.1:7890/', user: 'user', password: 'pass')
      c = Proxy.parse('http://user:other@127.0.0.1:7890')

      assert_equal a, b
      assert_operator a, :eql?, b
      assert_equal a.hash, b.hash
      refute_equal a, c
    end

    def test_inspect_masks_password
      with_pass = Proxy.parse('http://alice:supersecret@127.0.0.1:7890')
      refute_includes with_pass.inspect, 'supersecret'
      assert_equal '#<MixinBot::Proxy http://alice:***@127.0.0.1:7890>', with_pass.inspect

      without_creds = Proxy.parse('http://127.0.0.1:7890')
      assert_equal '#<MixinBot::Proxy http://127.0.0.1:7890>', without_creds.inspect
    end

    def test_rejects_invalid_inputs
      assert_raises(ArgumentError) { Proxy.parse('socks5://127.0.0.1:1080') }
      assert_raises(ArgumentError) { Proxy.parse('ftp://127.0.0.1:21') }
      assert_raises(ArgumentError) { Proxy.parse('127.0.0.1:7890') }
      assert_raises(ArgumentError) { Proxy.parse('proxy.local:7890') }
      assert_raises(ArgumentError) { Proxy.parse('http://') }
      assert_raises(ArgumentError) { Proxy.parse('http://bad host:7890') }
      assert_raises(ArgumentError) { Proxy.parse({}) }
      assert_raises(ArgumentError) { Proxy.parse(uri: '') }
      assert_raises(ArgumentError) { Proxy.parse(uri: 'http://127.0.0.1:7890', extra: true) }
      assert_raises(ArgumentError) { Proxy.parse(uri: 12_345) }
      assert_raises(ArgumentError) { Proxy.parse(12_345) }
    end
  end
end
