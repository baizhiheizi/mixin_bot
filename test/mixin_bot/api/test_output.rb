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

    def test_build_threshold_script_pads_single_hex_digit
      # 1 → "1" → padded to "01" → "fffe01"
      assert_equal 'fffe01', MixinBot.api.build_threshold_script(1)
    end

    def test_build_threshold_script_two_digit_hex_unchanged
      # 2 → "2" → padded to "02" → "fffe02"
      assert_equal 'fffe02', MixinBot.api.build_threshold_script(2)
    end

    def test_build_threshold_script_ten
      # 10 → "a" → padded to "0a" → "fffe0a"
      assert_equal 'fffe0a', MixinBot.api.build_threshold_script(10)
    end

    def test_build_threshold_script_fifteen
      # 15 → "f" → padded to "0f" → "fffe0f"
      assert_equal 'fffe0f', MixinBot.api.build_threshold_script(15)
    end

    def test_build_threshold_script_sixteen
      # 16 → "10" (two hex digits) → "fffe10"
      assert_equal 'fffe10', MixinBot.api.build_threshold_script(16)
    end

    def test_build_threshold_script_for_max_byte
      # 255 → "ff" (max two-digit hex) → "fffeff"
      assert_equal 'fffeff', MixinBot.api.build_threshold_script(255)
    end

    def test_build_threshold_script_raises_for_threshold_above_byte
      assert_raises(RuntimeError) { MixinBot.api.build_threshold_script(256) }
    end

    def test_build_threshold_script_raises_for_large_threshold
      assert_raises(RuntimeError) { MixinBot.api.build_threshold_script(4096) }
    end

    def test_build_threshold_script_prefix_is_always_fffe
      [1, 2, 16, 100, 255].each do |t|
        assert MixinBot.api.build_threshold_script(t).start_with?('fffe'),
               "expected threshold #{t} to start with 'fffe'"
      end
    end
  end
end
