# frozen_string_literal: true

require 'test_helper'

module MixinBot
  class TestAmountUtils < Minitest::Test
    def test_format_units_basic
      assert_equal '1', MixinBot.utils.format_units(10**18, 18)
      assert_equal '0.1', MixinBot.utils.format_units(10**17, 18)
      assert_equal '12.3456', MixinBot.utils.format_units(123_456, 4)
    end

    def test_format_units_zero_decimals
      assert_equal '5', MixinBot.utils.format_units(5, 0)
      assert_equal '-7', MixinBot.utils.format_units(-7, 0)
    end

    def test_format_units_trims_trailing_zeros
      assert_equal '123.45', MixinBot.utils.format_units(1_234_500, 4)
      assert_equal '1', MixinBot.utils.format_units(1_000, 3)
      assert_equal '0.5', MixinBot.utils.format_units(500, 3)
    end

    def test_format_units_pads_leading_zeros
      assert_equal '0.001', MixinBot.utils.format_units(1, 3)
      assert_equal '-0.001', MixinBot.utils.format_units(-1, 3)
    end

    def test_parse_units_exact_values
      assert_equal 10**17, MixinBot.utils.parse_units('0.1', 18)
      assert_equal 123_456, MixinBot.utils.parse_units('12.3456', 4)
      assert_equal 1, MixinBot.utils.parse_units('1', 0)
      assert_equal(-15, MixinBot.utils.parse_units('-1.5', 1))
    end

    def test_parse_units_floors_excess_precision
      assert_equal 1_234, MixinBot.utils.parse_units('1.2345', 3)
      assert_equal(-2, MixinBot.utils.parse_units('-1.2', 0))
    end

    def test_parse_units_rejects_invalid_strings
      assert_raises(ArgumentError) { MixinBot.utils.parse_units('abc', 18) }
      assert_raises(ArgumentError) { MixinBot.utils.parse_units('', 18) }
    end

    def test_round_trip
      amount = '0.1'
      assert_equal amount, MixinBot.utils.format_units(MixinBot.utils.parse_units(amount, 18), 18)
    end
  end
end
