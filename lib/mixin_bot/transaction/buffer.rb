# frozen_string_literal: true

module MixinBot
  class Transaction
    ##
    # Byte cursor for decoding raw transaction bytes.
    #
    class Buffer
      attr_reader :bytes

      def initialize(bytes)
        @bytes = bytes
      end

      def shift(byte_count = nil)
        return @bytes.shift if byte_count.nil?

        @bytes.shift(byte_count)
      end

      def peek(byte_count)
        @bytes[0, byte_count]
      end

      def size
        @bytes.size
      end

      def empty?
        @bytes.empty?
      end
    end
  end
end
