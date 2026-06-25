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

        bytes.concat Transaction::MAGIC
        bytes.push(0, @tx.version)
        bytes.concat [@tx.asset].pack('H*').bytes

        bytes.concat encode_inputs
        bytes.concat encode_outputs
        bytes.concat encode_references if @tx.version >= Transaction::REFERENCES_TX_VERSION

        extra_bytes = @tx.extra.bytes
        raise InvalidTransactionFormatError, 'extra is too long' if extra_bytes.size > Transaction::MAX_EXTRA_SIZE

        bytes.concat MixinBot.utils.encode_uint32 extra_bytes.size
        bytes.concat extra_bytes

        bytes.concat(@tx.aggregated.nil? ? encode_signatures : encode_aggregated_signature)

        @tx.hash = SHA3::Digest::SHA3_256.hexdigest bytes.pack('C*')
        @tx.hex = bytes.pack('C*').unpack1('H*')

        @tx
      end

      private

      def encode_inputs
        bytes = []

        bytes.concat MixinBot.utils.encode_uint16(@tx.inputs.size)

        @tx.inputs.each do |input|
          bytes.concat [input['hash']].pack('H*').bytes
          bytes.concat MixinBot.utils.encode_uint16(input['index'])

          genesis = input['genesis'] || ''
          if genesis.empty?
            bytes.concat Transaction::NULL_BYTES
          else
            genesis_bytes = [genesis].pack('H*').bytes
            bytes.concat MixinBot.utils.encode_uint16 genesis_bytes.size
            bytes.concat genesis_bytes
          end

          deposit = input['deposit']
          if deposit.nil?
            bytes.concat Transaction::NULL_BYTES
          else
            bytes.concat Transaction::MAGIC
            bytes.concat [deposit['chain']].pack('H*').bytes

            asset_bytes = [deposit['asset']].pack('H*')
            bytes.concat MixinBot.utils.encode_uint16 asset_bytes.size
            bytes.concat asset_bytes.bytes

            transaction_bytes = [deposit['transaction']].pack('H*')
            bytes.concat MixinBot.utils.encode_uint16 transaction_bytes.size
            bytes.concat transaction_bytes.bytes

            bytes.concat MixinBot.utils.encode_uint64 deposit['index']

            amount_bytes = MixinBot.utils.bytes_of deposit['amount']
            bytes.concat MixinBot.utils.encode_uint16 amount_bytes.size
            bytes.concat amount_bytes
          end

          mint = input['mint']
          if mint.nil?
            bytes.concat Transaction::NULL_BYTES
          else
            bytes.concat Transaction::MAGIC

            group = mint['group'] || ''
            if group.empty?
              bytes.concat Transaction::NULL_BYTES
            else
              group_bytes = [group].pack('H*')
              bytes.concat MixinBot.utils.encode_uint16 group_bytes.size
              bytes.concat group_bytes.bytes
            end

            bytes.concat MixinBot.utils.encode_uint64 mint['batch']

            amount_bytes = MixinBot.utils.encode_int mint['amount']
            bytes.concat MixinBot.utils.encode_uint16 amount_bytes.size
            bytes.concat amount_bytes
          end
        end

        bytes
      end

      def encode_outputs
        bytes = []

        bytes.concat MixinBot.utils.encode_uint16 @tx.outputs.size

        @tx.outputs.each do |output|
          type = output['type'] || 0
          bytes.push(0x00, type)

          amount_bytes = MixinBot.utils.encode_int((output['amount'].to_d * 1e8).round)
          bytes.concat MixinBot.utils.encode_uint16 amount_bytes.size
          bytes.concat amount_bytes

          bytes.concat MixinBot.utils.encode_uint16 output['keys'].size
          output['keys'].each do |key|
            bytes.concat [key].pack('H*').bytes
          end

          bytes.concat [output['mask']].pack('H*').bytes

          script_bytes = [output['script']].pack('H*').bytes
          bytes.concat MixinBot.utils.encode_uint16 script_bytes.size
          bytes.concat script_bytes

          withdrawal = output['withdrawal']
          if withdrawal.nil?
            bytes.concat Transaction::NULL_BYTES
          else
            bytes.concat Transaction::MAGIC

            bytes.concat [withdrawal['chain']].pack('H*').bytes

            asset_bytes = [withdrawal['asset']].pack('H*')
            bytes.concat MixinBot.utils.encode_uint16 asset_bytes.bytesize
            bytes.concat asset_bytes.bytes

            address = withdrawal['address'] || ''
            if address.empty?
              bytes.concat Transaction::NULL_BYTES
            else
              address_bytes = [address].pack('H*').bytes
              bytes.concat MixinBot.utils.encode_uint16 address_bytes.size
              bytes.concat address_bytes
            end

            tag = withdrawal['tag'] || ''
            if tag.empty?
              bytes.concat Transaction::NULL_BYTES
            else
              tag_bytes = [tag].pack('H*').bytes
              bytes.concat MixinBot.utils.encode_uint16 tag_bytes.size
              bytes.concat tag_bytes
            end
          end
        end

        bytes
      end

      def encode_references
        bytes = []

        references = Array(@tx.references)
        bytes.concat MixinBot.utils.encode_uint16 references.size

        references.each do |reference|
          bytes.concat [reference].pack('H*').bytes
        end

        bytes
      end

      def encode_aggregated_signature
        bytes = []

        bytes.concat MixinBot.utils.encode_uint16 Transaction::MAX_ENCODE_INT
        bytes.concat MixinBot.utils.encode_uint16 Transaction::AGGREGATED_SIGNATURE_PREFIX
        bytes.concat [@tx.aggregated['signature']].pack('H*').bytes

        signers = @tx.aggregated['signers'] || []
        if signers.empty?
          bytes.concat Transaction::AGGREGATED_SIGNATURE_ORDINAY_MASK
          bytes.concat Transaction::NULL_BYTES
          return bytes
        end

        signers.each_with_index do |sig, i|
          raise ArgumentError, 'signers not sorted' if i.positive? && sig <= signers[i - 1]
          raise ArgumentError, 'signers not sorted' if sig > Transaction::MAX_ENCODE_INT
        end

        max = signers.last
        sig_byte_len = [@tx.aggregated['signature']].pack('H*').bytes.size
        if ((max / 8) + 1) > sig_byte_len
          bytes.concat Transaction::AGGREGATED_SIGNATURE_SPARSE_MASK
          bytes.concat MixinBot.utils.encode_uint16 signers.size
          signers.each { |signer| bytes.concat MixinBot.utils.encode_uint16(signer) }
        else
          masks_bytes = Array.new((max / 8) + 1, 0)
          signers.each do |signer|
            masks_bytes[signer / 8] ^= (1 << (signer % 8))
          end
          bytes.concat Transaction::AGGREGATED_SIGNATURE_ORDINAY_MASK
          bytes.concat MixinBot.utils.encode_uint16 masks_bytes.size
          bytes.concat masks_bytes
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

        bytes.concat MixinBot.utils.encode_uint16 sl

        if sl.positive?
          @tx.signatures.each do |signature|
            bytes.concat MixinBot.utils.encode_uint16 signature.keys.size

            signature.keys.sort.each do |key|
              signature_bytes = [signature[key]].pack('H*').bytes
              raise ArgumentError, 'Signature should be 64 bytes' if signature_bytes.size != 64

              bytes.concat MixinBot.utils.encode_uint16 key
              bytes.concat signature_bytes
            end
          end
        end

        bytes
      end
    end
  end
end
