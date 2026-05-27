# frozen_string_literal: true

require 'test_helper'

module MixinBot
  class TestMonitor < Minitest::Test
    def test_check_retryable_error_delegates_to_mixin_bot_retryable
      refute Monitor.check_retryable_error(InsufficientBalanceError.new('balance'))
      assert Monitor.check_retryable_error(TransientError.new(code: 10_105, description: 'locked'))
      assert Monitor.check_retryable_error(ServerError.new(code: 500, description: 'error'))
      refute Monitor.check_retryable_error(RateLimitError.new(code: 429, description: 'limit'))
      assert Monitor.check_retryable_error(Faraday::TimeoutError.new('timeout'))
    end
  end
end
