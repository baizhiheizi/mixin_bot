# frozen_string_literal: true

require 'test_helper'

module MixinBot
  class TestClient < Minitest::Test
    def test_default_configuration_applies_no_http_timeout
      client = Client.new(Configuration.new)

      assert_nil client.conn.options.timeout
    end

    def test_configured_http_timeout_reaches_the_faraday_connection
      config = Configuration.new(http_timeout: 5)
      client = Client.new(config)

      assert_equal 5, client.conn.options.timeout
    end

    def test_http_timeout_must_be_a_positive_number
      assert_raises(ArgumentError) { Configuration.new(http_timeout: 0) }
      assert_raises(ArgumentError) { Configuration.new(http_timeout: -3) }
      assert_raises(ArgumentError) { Configuration.new(http_timeout: 'five') }
    end

    def test_global_configuration_timeout_is_applied
      previous = MixinBot.config.http_timeout
      MixinBot.config.http_timeout = 7

      client = Client.new(nil)

      assert_equal 7, client.conn.options.timeout
    ensure
      MixinBot.config.http_timeout = previous
    end

    def test_default_configuration_applies_no_manual_proxy
      with_cleared_proxy_env do
        client = Client.new(Configuration.new)

        assert_nil client.conn.proxy
      end
    end

    def test_configured_proxy_reaches_faraday_and_net_http
      config = Configuration.new(proxy: 'https://alice:s3cr3t@127.0.0.1:7890')
      client = Client.new(config)

      assert_equal '127.0.0.1', client.conn.proxy.host
      assert_equal 7890, client.conn.proxy.port
      assert_equal 'alice', client.conn.proxy.user
      assert_equal 's3cr3t', client.conn.proxy.password

      env = client.conn.build_request(:get) do |req|
        req.options.proxy = client.conn.proxy_for_request('/me')
        req.url('/me')
      end.to_env(client.conn)
      http = Faraday::Adapter::NetHttp.new.net_http_connection(env)

      assert_equal '127.0.0.1', http.proxy_address
      assert_equal 7890, http.proxy_port
      assert_equal 'alice', http.proxy_user
      assert_equal 's3cr3t', http.proxy_pass
      assert http.instance_variable_get(:@proxy_use_ssl)
    end

    def test_global_configuration_proxy_changes_rebuild_connection_dynamically
      previous = MixinBot.config.proxy
      with_cleared_proxy_env do
        MixinBot.config.proxy = nil
        client = Client.new(nil)
        assert_nil client.conn.proxy

        MixinBot.config.proxy = 'http://127.0.0.1:7890'
        assert_equal '127.0.0.1', client.conn.proxy.host
        assert_equal 7890, client.conn.proxy.port

        MixinBot.config.proxy = nil
        assert_nil client.conn.proxy
      end
    ensure
      MixinBot.config.proxy = previous
    end

    def test_isolated_api_proxy_does_not_mutate_global_config
      previous = MixinBot.config.proxy
      MixinBot.config.proxy = nil

      api = MixinBot::API.new(proxy: 'http://127.0.0.1:8888')

      assert_equal 8888, api.client.conn.proxy.port
      assert_nil MixinBot.config.proxy
    ensure
      MixinBot.config.proxy = previous
    end

    def test_mvm_client_routes_through_global_and_instance_proxy
      previous = MixinBot.config.proxy
      with_cleared_proxy_env do
        MixinBot.config.proxy = nil
        global_client = MVM::Client.new('bridge.mvm.dev')
        assert_nil global_client.conn.proxy

        MixinBot.config.proxy = 'http://127.0.0.1:7890'
        assert_equal 7890, global_client.conn.proxy.port

        override_client = MVM::Client.new('bridge.mvm.dev', proxy: 'http://127.0.0.1:9999')
        assert_equal 9999, override_client.conn.proxy.port

        MixinBot.config.proxy = nil
        assert_nil global_client.conn.proxy
        assert_equal 9999, override_client.conn.proxy.port
      end
    ensure
      MixinBot.config.proxy = previous
    end

    private

    def with_cleared_proxy_env
      keys = %w[http_proxy HTTP_PROXY https_proxy HTTPS_PROXY all_proxy ALL_PROXY]
      saved = keys.to_h { |k| [k, ENV.fetch(k, nil)] }
      keys.each { |k| ENV.delete(k) }
      yield
    ensure
      saved.each { |k, v| ENV[k] = v }
    end
  end
end
