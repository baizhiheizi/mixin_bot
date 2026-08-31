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
  end
end
