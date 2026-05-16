# frozen_string_literal: true

module MixinBot
  class Transaction
    ##
    # Parses raw transaction bytes into a {Transaction} instance.
    #
    class Decoder
      def initialize(transaction)
        @tx = transaction
      end

      def decode
        raw = [@tx.hex].pack('H*').bytes
        @tx.hash = SHA3::Digest::SHA256.hexdigest(raw.pack('C*'))
        @buf = Buffer.new(raw)

        magic = @buf.shift(2)
        raise ArgumentError, 'Not valid raw' unless magic == Transaction::MAGIC

        _version = @buf.shift(2)
        @tx.version = MixinBot.utils.decode_int _version

        asset = @buf.shift(32)
        @tx.asset = asset.pack('C*').unpack1('H*')

        decode_inputs
        decode_outputs
        decode_references if @tx.version >= Transaction::REFERENCES_TX_VERSION && @tx.references.present?

        extra_size = MixinBot.utils.decode_uint32 @buf.shift(4)
        @tx.extra = @buf.shift(extra_size).pack('C*')

        num = MixinBot.utils.decode_uint16 @buf.shift(2)
        if num == Transaction::MAX_ENCODE_INT
          @tx.aggregated = {}

          prefix = MixinBot.utils.decode_uint16(@buf.shift(2))
          raise ArgumentError, 'invalid aggregated' unless prefix == Transaction::AGGREGATED_SIGNATURE_PREFIX

          @tx.aggregated['signature'] = @buf.shift(64).pack('C*').unpack1('H*')

          byte = @buf.shift
          case byte
          when Transaction::AGGREGATED_SIGNATURE_ORDINAY_MASK.first
            @tx.aggregated['signers'] = []
            masks_size = MixinBot.utils.decode_uint16 @buf.shift(2)
            masks = @buf.shift(masks_size)
            masks = Array(masks)

            masks.each_with_index do |mask, i|
              8.times do |j|
                k = 1 << j
                @tx.aggregated['signers'].push((i * 8) + j) if mask & k == k
              end
            end
          when Transaction::AGGREGATED_SIGNATURE_SPARSE_MASK.first
            signers_size = MixinBot.utils.decode_uint16 @buf.shift(2)
            @tx.aggregated['signers'] = []
            unless signers_size.zero?
              signers_size.times do
                @tx.aggregated['signers'].push MixinBot.utils.decode_uint16(@buf.shift(2))
              end
            end
          end
        elsif num.present? && num.positive? && @buf.size.positive?
          @tx.signatures = []
          num.times do
            signature = {}

            keys_size = MixinBot.utils.decode_uint16 @buf.shift(2)

            keys_size.times do
              index = MixinBot.utils.decode_uint16 @buf.shift(2)
              signature[index] = @buf.shift(64).pack('C*').unpack1('H*')
            end

            @tx.signatures << signature
          end
        end

        @tx
      end

      private

      def decode_inputs
        inputs_size = MixinBot.utils.decode_uint16 @buf.shift(2)
        @tx.inputs = []
        inputs_size.times do
          input = {}
          hash = @buf.shift(32)
          input['hash'] = hash.pack('C*').unpack1('H*')

          index = @buf.shift(2)
          input['index'] = MixinBot.utils.decode_uint16 index

          if @buf.peek(2) == Transaction::NULL_BYTES
            @buf.shift(2)
          else
            genesis_size = MixinBot.utils.decode_uint16 @buf.shift(2)
            genesis = @buf.shift genesis_size
            input['genesis'] = genesis.pack('C*').unpack1('H*')
          end

          if @buf.peek(2) == Transaction::NULL_BYTES
            @buf.shift(2)
          else
            magic = @buf.shift(2)
            raise ArgumentError, 'Not valid input' unless magic == Transaction::MAGIC

            deposit = {}
            deposit['chain'] = @buf.shift(32).pack('C*').unpack1('H*')

            asset_size = MixinBot.utils.decode_uint16 @buf.shift(2)
            deposit['asset'] = @buf.shift(asset_size).unpack1('H*')

            transaction_size = MixinBot.utils.decode_uint16 @buf.shift(2)
            deposit['transaction'] = @buf.shift(transaction_size).unpack1('H*')

            deposit['index'] = MixinBot.utils.decode_uint64 @buf.shift(8)

            amount_size = MixinBot.utils.decode_uint16 @buf.shift(2)
            deposit['amount'] = MixinBot.utils.decode_int @buf.shift(amount_size)

            input['deposit'] = deposit
          end

          if @buf.peek(2) == Transaction::NULL_BYTES
            @buf.shift(2)
          else
            magic = @buf.shift(2)
            raise ArgumentError, 'Not valid input' unless magic == Transaction::MAGIC

            mint = {}
            if @buf.peek(2) == Transaction::NULL_BYTES
              @buf.shift(2)
            else
              group_size = MixinBot.utils.decode_uint16 @buf.shift(2)
              mint['group'] = @buf.shift(group_size).unpack1('H*')
            end

            mint['batch'] = MixinBot.utils.decode_uint64 @buf.shift(8)
            _amount_size = MixinBot.utils.decode_uint16 @buf.shift(2)
            mint['amount'] = MixinBot.utils.decode_int @buf.shift(_amount_size)

            input['mint'] = mint
          end

          @tx.inputs.push input
        end

        @tx
      end

      def decode_outputs
        outputs_size = MixinBot.utils.decode_uint16 @buf.shift(2)
        @tx.outputs = []
        outputs_size.times do
          output = {}

          @buf.shift
          type = @buf.shift
          output['type'] = type

          amount_size = MixinBot.utils.decode_uint16 @buf.shift(2)
          output['amount'] = format('%.8f', MixinBot.utils.decode_int(@buf.shift(amount_size)).to_f / 1e8).gsub(/\.?0+$/, '')

          output['keys'] = []
          keys_size = MixinBot.utils.decode_uint16 @buf.shift(2)
          keys_size.times do
            output['keys'].push @buf.shift(32).pack('C*').unpack1('H*')
          end

          output['mask'] = @buf.shift(32).pack('C*').unpack1('H*')

          script_size = MixinBot.utils.decode_uint16 @buf.shift(2)
          output['script'] = @buf.shift(script_size).pack('C*').unpack1('H*')

          if @buf.peek(2) == Transaction::NULL_BYTES
            @buf.shift(2)
          else
            magic = @buf.shift(2)
            raise ArgumentError, 'Not valid output' unless magic == Transaction::MAGIC

            withdrawal = {}
            withdrawal['chain'] = @buf.shift(32).pack('C*').unpack1('H*')

            asset_size = MixinBot.utils.decode_uint16 @buf.shift(2)
            withdrawal['asset'] = @buf.shift(asset_size).unpack1('H*')

            if @buf.peek(2) == Transaction::NULL_BYTES
              @buf.shift(2)
            else
              address_size = MixinBot.utils.decode_uint16 @buf.shift(2)
              withdrawal['address'] = @buf.shift(address_size).pack('C*').unpack1('H*')
            end

            if @buf.peek(2) == Transaction::NULL_BYTES
              @buf.shift(2)
            else
              tag_size = MixinBot.utils.decode_uint16 @buf.shift(2)
              withdrawal['tag'] = @buf.shift(tag_size).pack('C*').unpack1('H*')
            end

            output['withdrawal'] = withdrawal
          end

          @tx.outputs.push output
        end

        @tx
      end

      def decode_references
        references_size = MixinBot.utils.decode_uint16 @buf.shift(2)
        @tx.references = []

        references_size.times do
          @tx.references.push @buf.shift(32).pack('C*').unpack1('H*')
        end

        @tx
      end
    end
  end
end
