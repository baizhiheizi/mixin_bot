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
  end
end
