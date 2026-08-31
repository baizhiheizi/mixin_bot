# frozen_string_literal: true

require 'bigdecimal'

module MixinBot
  module Utils
    ##
    # Decimal-safe unit conversion between human-readable amounts and decimal
    # strings, mirroring the Node SDK's utils/amount.ts (BigNumber-based).
    #
    module Amount
      DECIMAL_STRING_PATTERN = /\A[+-]?\d+(\.\d+)?\z/

      ##
      # Divide an amount by 10**decimals and return the exact decimal string.
      # Accepts Integers and decimal strings ('7.5'); leading zeros are decimal,
      # never octal. Mirrors BigNumber(amount).dividedBy(10**unit).
      #
      #   MixinBot.utils.format_units(10**17, 18) # => "0.1"
      #   MixinBot.utils.format_units('010', 18)  # => "0.00000000000000001"
      #   MixinBot.utils.format_units('7.5', 2)   # => "0.075"
      #
      def format_units(amount, decimals)
        decimals = validated_decimals(decimals)
        value = validated_amount_string(amount)

        sign = value.start_with?('-') ? '-' : ''
        whole, fraction = value.delete_prefix('-').delete_prefix('+').split('.')
        fraction ||= ''
        digits = "#{whole}#{fraction}".sub(/\A0+(?=\d)/, '')
        shift = fraction.length + decimals

        formatted =
          if shift.zero?
            digits
          elsif digits.size > shift
            "#{digits[0...-shift]}.#{digits[-shift..]}"
          else
            "0.#{'0' * (shift - digits.size)}#{digits}"
          end

        "#{sign}#{formatted}".sub(/(\.\d*?)0+\z/, '\1').sub(/\.\z/, '')
      end

      ##
      # Multiply a decimal amount string by 10**decimals and return integer
      # minor units. Values with more precision than +decimals+ round down
      # (floor), matching the Node SDK; invalid strings raise +ArgumentError+.
      #
      #   MixinBot.utils.parse_units('0.1', 18) # => 100000000000000000
      #
      def parse_units(amount, decimals)
        decimals = validated_decimals(decimals)
        value = validated_amount_string(amount)

        (value.to_d * (10**decimals)).floor
      end

      private

      def validated_amount_string(amount)
        value = amount.to_s.strip
        raise ArgumentError, "invalid amount #{amount.inspect}" unless value.match?(DECIMAL_STRING_PATTERN)

        value
      end

      # accepts Integers and numeric strings (base-10, so '010' is ten, never octal)
      def validated_decimals(decimals)
        decimals = Integer(decimals, 10) if decimals.is_a?(String) && decimals.match?(/\A[+-]?\d+\z/)
        return decimals if decimals.is_a?(Integer) && decimals >= 0

        raise ArgumentError, "decimals must be a non-negative Integer, got #{decimals.inspect}"
      end
    end
  end
end
