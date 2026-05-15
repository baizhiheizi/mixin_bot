# frozen_string_literal: true

require 'test_helper'

module MixinBot
  class TestOutput < Minitest::Test
    def setup
      MixinBot.config.debug = true
    end

    def test_safe_outputs
      res = MixinBot.api.safe_outputs

      assert_equal res['data'].class, Array
    end

    def test_safe_output
      outputs = MixinBot.api.safe_outputs
      res = MixinBot.api.safe_output outputs['data'].first['output_id']
      assert_equal outputs['data'].first['output_id'], res['data']['output_id']
    end
  end
end
