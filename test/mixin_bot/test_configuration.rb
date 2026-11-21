# frozen_string_literal: true

require 'test_helper'

module MixinBot
  class TestConfiguration < Minitest::Test
    def test_blaze_ack_policy_defaults_to_on_receipt
      assert_equal :on_receipt, Configuration.new.blaze_ack_policy
    end

    def test_blaze_ack_policy_accepts_both_policies
      config = Configuration.new(blaze_ack_policy: :after_handler)
      assert_equal :after_handler, config.blaze_ack_policy

      config.blaze_ack_policy = 'on_receipt'
      assert_equal :on_receipt, config.blaze_ack_policy
    end

    def test_blaze_ack_policy_rejects_unknown_values
      assert_raises(ArgumentError) { Configuration.new(blaze_ack_policy: :whenever) }
      assert_raises(ArgumentError) { Configuration.new(blaze_ack_policy: 'ASAP') }
    end

    def test_blaze_handler_accepts_callables
      handler = ->(_envelope) { envelope }
      config = Configuration.new(blaze_handler: handler)

      assert_equal handler, config.blaze_handler
    end

    def test_blaze_handler_rejects_non_callables
      assert_raises(ArgumentError) { Configuration.new(blaze_handler: 'MyHandler') }
      assert_raises(ArgumentError) { Configuration.new(blaze_handler: 42) }
    end

    def test_blaze_handler_can_be_reset_to_nil
      config = Configuration.new(blaze_handler: ->(_envelope) { envelope })

      assert_nil config.blaze_handler = nil
      assert_nil config.blaze_handler
    end

    def test_proxy_defaults_to_nil
      config = Configuration.new

      assert_nil config.proxy
      assert_nil config.proxy_config
    end

    def test_proxy_accepts_string_uri_and_hash_and_clears_on_nil_or_blank
      config = Configuration.new(proxy: 'http://user:pass@127.0.0.1:7890')
      assert_equal 'http://user:pass@127.0.0.1:7890', config.proxy
      assert_equal 'http://127.0.0.1:7890', config.proxy_config.origin
      assert_equal 'user', config.proxy_config.user
      assert_equal 'pass', config.proxy_config.password

      config.proxy = URI.parse('https://proxy.example.com:8443')
      assert_equal 'https://proxy.example.com:8443', config.proxy_config.origin
      assert_predicate config.proxy, :frozen?

      config.proxy = { uri: 'http://127.0.0.1:8888', user: 'u', password: 'p' }
      assert_equal 'http://127.0.0.1:8888', config.proxy_config.origin
      assert_predicate config.proxy, :frozen?

      config.proxy = ''
      assert_nil config.proxy
      assert_nil config.proxy_config

      config.proxy = 'http://127.0.0.1:7890'
      config.proxy = nil
      assert_nil config.proxy
      assert_nil config.proxy_config
    end

    def test_proxy_rejection_does_not_mutate_existing_value
      config = Configuration.new(proxy: 'http://127.0.0.1:7890')

      assert_raises(ArgumentError) { config.proxy = 'socks5://127.0.0.1:1080' }
      assert_equal 'http://127.0.0.1:7890', config.proxy
      assert_equal 'http://127.0.0.1:7890', config.proxy_config.origin
    end

    def test_frozen_configuration_preserves_proxy_config
      config = Configuration.new(proxy: { uri: 'http://127.0.0.1:7890', user: 'u', password: 'p' })
      config.freeze

      assert_predicate config, :frozen?
      assert_predicate config.proxy, :frozen?
      assert_predicate config.proxy_config, :frozen?
      assert_equal 'http://127.0.0.1:7890', config.proxy_config.origin
    end
  end
end
