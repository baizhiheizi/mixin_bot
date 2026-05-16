# frozen_string_literal: true

module MixinBot
  module Utils
    module Encoder
      def encode_raw_transaction(txn)
        if txn.is_a? String
          begin
            txn = JSON.parse txn
          rescue JSON::ParserError
            txn
          end
        end

        raise ArgumentError, "#{txn} is not a valid json" unless txn.is_a? Hash

        txn = txn.with_indifferent_access

        MixinBot::Transaction.new(**txn).encode.hex
      end

      def encode_uint16(int)
        raise ArgumentError, "only support int #{int}" unless int.is_a?(Integer)

        [int].pack('S*').bytes.reverse
      end

      def encode_uint32(int)
        raise ArgumentError, "only support int #{int}" unless int.is_a?(Integer)

        [int].pack('L*').bytes.reverse
      end

      def encode_uint64(int)
        raise ArgumentError, "only support int #{int}" unless int.is_a?(Integer)

        [int].pack('Q*').bytes.reverse
      end

      ##
      # Big-endian varint-style encoding for deposit amounts (integer or decimal string).
      #
      def bytes_of(amount)
        int =
          case amount
          when Integer then amount
          when String then Integer(amount, 10)
          else amount.to_i
          end
        encode_int(int)
      end

      def encode_int(int)
        raise ArgumentError, 'not integer' unless int.is_a?(Integer)

        bytes = []
        if int.zero?
          bytes.push(0)
        else
          loop do
            break if int.zero?

            bytes.push int & 255
            int = (int / (2**8)) | 0
          end
        end

        bytes.reverse
      end

      def nft_memo(collection, token, extra)
        MixinBot::Nfo.new(
          collection:,
          token:,
          extra:
        ).mint_memo
      end
    end
  end
end
