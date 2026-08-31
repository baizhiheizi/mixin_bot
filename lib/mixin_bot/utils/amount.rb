# frozen_string_literal: true

require 'bigdecimal'

module MixinBot
  module Utils
    ##
    # Decimal-safe unit conversion between human-readable amounts and integer
    # minor units, mirroring the Node SDK's utils/amount.ts (BigNumber-based).
    #
    module Amount
      ##
      # Convert integer minor units to a decimal string.
      #
      #   MixinBot.utils.format_units(10**17, 18) # => "0.1"
      #   MixinBot.utils.format_units(1_234_500, 4) # => "123.45"
      #
      def format_units(amount, decimals)
        n = Integer(amount)
        sign = n.negative? ? '-' : ''
        digits = n.abs.to_s

        return "#{sign}#{digits}" if decimals.zero?

        whole, fraction =
          if digits.size > decimals
            [digits[0...-decimals], digits[-decimals..]]
          else
            ['0', "#{'0' * (decimals - digits.size)}#{digits}"]
          end

        value = "#{sign}#{whole}.#{fraction}"
        value.sub(/(\.\d*?)0+\z/, '\1').sub(/\.\z/, '')
      end

      ##
      # Convert a decimal amount string to integer minor units.
      # Values with more precision than +decimals+ round down (floor),
      # matching the Node SDK; invalid strings raise +ArgumentError+.
      #
      #   MixinBot.utils.parse_units('0.1', 18) # => 100000000000000000
      #
      def parse_units(amount, decimals)
        value = amount.to_s.strip
        raise ArgumentError, "invalid amount #{amount.inspect}" unless value.match?(/\A[+-]?\d+(\.\d+)?\z/)

        (value.to_d * (10**decimals)).floor
      end
    end
  end
end
