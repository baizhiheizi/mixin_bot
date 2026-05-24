# frozen_string_literal: true

module MixinBot
  class Transaction
    ##
    # Builds the binary encoding for a {Transaction} instance.
    #
    class Encoder
      def initialize(transaction)
        @tx = transaction
      end

      def encode
        raise InvalidTransactionFormatError, 'asset is required' if @tx.asset.blank?
        raise InvalidTransactionFormatError, 'inputs is required' if @tx.inputs.blank?
        raise InvalidTransactionFormatError, 'outputs is required' if @tx.outputs.blank?

        bytes = []

        bytes += Transaction::MAGIC
        bytes += [0, @tx.version]
        bytes += [@tx.asset].pack('H*').bytes

        bytes += encode_inputs
        bytes += encode_outputs
        bytes += encode_references if @tx.version >= Transaction::REFERENCES_TX_VERSION

        extra_bytes = @tx.extra.bytes
        raise InvalidTransactionFormatError, 'extra is too long' if extra_bytes.size > Transaction::MAX_EXTRA_SIZE

        bytes += MixinBot.utils.encode_uint32 extra_bytes.size
        bytes += extra_bytes

        bytes += if @tx.aggregated.nil?
                   encode_signatures
                 else
                   encode_aggregated_signature
                 end

        @tx.hash = SHA3::Digest::SHA256.hexdigest bytes.pack('C*')
        @tx.hex = bytes.pack('C*').unpack1('H*')

        @tx
      end

      private

      def encode_inputs
        bytes = []

        bytes += MixinBot.utils.encode_uint16(@tx.inputs.size)

        @tx.inputs.each do |input|
          bytes += [input['hash']].pack('H*').bytes
          bytes += MixinBot.utils.encode_uint16(input['index'])

          genesis = input['genesis'] || ''
          if genesis.empty?
            bytes += Transaction::NULL_BYTES
          else
            genesis_bytes = [genesis].pack('H*').bytes
            bytes += MixinBot.utils.encode_uint16 genesis_bytes.size
            bytes += genesis_bytes
          end

          deposit = input['deposit']
          if deposit.nil?
            bytes += Transaction::NULL_BYTES
          else
            bytes += Transaction::MAGIC
            bytes += [deposit['chain']].pack('H*').bytes

            asset_bytes = [deposit['asset']].pack('H*')
            bytes += MixinBot.utils.encode_uint16 asset_bytes.size
            bytes += asset_bytes.bytes

            transaction_bytes = [deposit['transaction']].pack('H*')
            bytes += MixinBot.utils.encode_uint16 transaction_bytes.size
            bytes += transaction_bytes.bytes

            bytes += MixinBot.utils.encode_uint64 deposit['index']

            amount_bytes = MixinBot.utils.bytes_of deposit['amount']
            bytes += MixinBot.utils.encode_uint16 amount_bytes.size
            bytes += amount_bytes
          end

          mint = input['mint']
          if mint.nil?
            bytes += Transaction::NULL_BYTES
          else
            bytes += Transaction::MAGIC

            group = mint['group'] || ''
            if group.empty?
              bytes += Transaction::NULL_BYTES
            else
              group_bytes = [group].pack('H*')
              bytes += MixinBot.utils.encode_uint16 group_bytes.size
              bytes += group_bytes.bytes
            end

            bytes += MixinBot.utils.encode_uint64 mint['batch']

            amount_bytes = MixinBot.utils.encode_int mint['amount']
            bytes += MixinBot.utils.encode_uint16 amount_bytes.size
            bytes += amount_bytes
          end
        end

        bytes
      end

      def encode_outputs
        bytes = []

        bytes += MixinBot.utils.encode_uint16 @tx.outputs.size

        @tx.outputs.each do |output|
          type = output['type'] || 0
          bytes += [0x00, type]

          amount_bytes = MixinBot.utils.encode_int((output['amount'].to_d * 1e8).round)
          bytes += MixinBot.utils.encode_uint16 amount_bytes.size
          bytes += amount_bytes

          bytes += MixinBot.utils.encode_uint16 output['keys'].size
          output['keys'].each do |key|
            bytes += [key].pack('H*').bytes
          end

          bytes += [output['mask']].pack('H*').bytes

          script_bytes = [output['script']].pack('H*').bytes
          bytes += MixinBot.utils.encode_uint16 script_bytes.size
          bytes += script_bytes

          withdrawal = output['withdrawal']
          if withdrawal.nil?
            bytes += Transaction::NULL_BYTES
          else
            bytes += Transaction::MAGIC

            bytes += [withdrawal['chain']].pack('H*').bytes

            asset_bytes = [withdrawal['asset']].pack('H*')
            bytes += MixinBot.utils.encode_uint16 asset_bytes.bytesize
            bytes += asset_bytes.bytes

            address = withdrawal['address'] || ''
            if address.empty?
              bytes += Transaction::NULL_BYTES
            else
              address_bytes = [address].pack('H*').bytes
              bytes += MixinBot.utils.encode_uint16 address_bytes.size
              bytes += address_bytes
            end

            tag = withdrawal['tag'] || ''
            if tag.empty?
              bytes += Transaction::NULL_BYTES
            else
              tag_bytes = [tag].pack('H*').bytes
              bytes += MixinBot.utils.encode_uint16 tag_bytes.size
              bytes += tag_bytes
            end
          end
        end

        bytes
      end

      def encode_references
        bytes = []

        references = Array(@tx.references)
        bytes += MixinBot.utils.encode_uint16 references.size

        references.each do |reference|
          bytes += [reference].pack('H*').bytes
        end

        bytes
      end

      def encode_aggregated_signature
        bytes = []

        bytes += MixinBot.utils.encode_uint16 Transaction::MAX_ENCODE_INT
        bytes += MixinBot.utils.encode_uint16 Transaction::AGGREGATED_SIGNATURE_PREFIX
        bytes += [@tx.aggregated['signature']].pack('H*').bytes

        signers = @tx.aggregated['signers'] || []
        if signers.empty?
          bytes += Transaction::AGGREGATED_SIGNATURE_ORDINAY_MASK
          bytes += Transaction::NULL_BYTES
          return bytes
        end

        signers.each_with_index do |sig, i|
          raise ArgumentError, 'signers not sorted' if i.positive? && sig <= signers[i - 1]
          raise ArgumentError, 'signers not sorted' if sig > Transaction::MAX_ENCODE_INT
        end

        max = signers.last
        sig_byte_len = [@tx.aggregated['signature']].pack('H*').bytes.size
        if ((max / 8) + 1) > sig_byte_len
          bytes += Transaction::AGGREGATED_SIGNATURE_SPARSE_MASK
          bytes += MixinBot.utils.encode_uint16 signers.size
          signers.each { |signer| bytes += MixinBot.utils.encode_uint16(signer) }
        else
          masks_bytes = Array.new((max / 8) + 1, 0)
          signers.each do |signer|
            masks_bytes[signer / 8] ^= (1 << (signer % 8))
          end
          bytes += Transaction::AGGREGATED_SIGNATURE_ORDINAY_MASK
          bytes += MixinBot.utils.encode_uint16 masks_bytes.size
          bytes += masks_bytes
        end

        bytes
      end

      def encode_signatures
        bytes = []

        sl =
          if @tx.signatures.is_a? Array
            @tx.signatures.size
          else
            0
          end

        raise ArgumentError, 'signatures overflow' if sl == Transaction::MAX_ENCODE_INT

        bytes += MixinBot.utils.encode_uint16 sl

        if sl.positive?
          @tx.signatures.each do |signature|
            bytes += MixinBot.utils.encode_uint16 signature.keys.size

            signature.keys.sort.each do |key|
              signature_bytes = [signature[key]].pack('H*').bytes
              raise ArgumentError, 'Signature should be 64 bytes' if signature_bytes.size != 64

              bytes += MixinBot.utils.encode_uint16 key
              bytes += signature_bytes
            end
          end
        end

        bytes
      end
    end
  end
end
