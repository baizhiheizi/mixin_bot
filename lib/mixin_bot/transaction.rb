# frozen_string_literal: true

module MixinBot
  class Transaction
    REFERENCES_TX_VERSION = 0x04
    SAFE_TX_VERSION = 0x05
    DEAULT_VERSION = 5
    MAGIC = [0x77, 0x77].freeze
    TX_VERSION = 2
    MAX_ENCODE_INT = 0xFFFF
    MAX_EXTRA_SIZE = 512
    NULL_BYTES = [0x00, 0x00].freeze
    AGGREGATED_SIGNATURE_PREFIX = 0xFF01
    AGGREGATED_SIGNATURE_ORDINAY_MASK = [0x00].freeze
    AGGREGATED_SIGNATURE_SPARSE_MASK = [0x01].freeze

    attr_accessor :version, :asset, :inputs, :outputs, :extra, :signatures, :aggregated, :references, :hex, :hash

    def initialize(**kwargs)
      @version = kwargs[:version] || DEAULT_VERSION
      @asset = kwargs[:asset]
      @inputs = kwargs[:inputs]
      @outputs = kwargs[:outputs]
      @extra = kwargs[:extra].to_s
      @hex = kwargs[:hex]
      @signatures = kwargs[:signatures]
      @aggregated = kwargs[:aggregated]
      @references = kwargs[:references]
    end

    def encode
      raise InvalidTransactionFormatError, 'asset is required' if asset.blank?
      raise InvalidTransactionFormatError, 'inputs is required' if inputs.blank?
      raise InvalidTransactionFormatError, 'outputs is required' if outputs.blank?

      bytes = []

      # magic number
      bytes += MAGIC

      # version
      bytes += [0, version]

      # asset
      bytes += [asset].pack('H*').bytes

      # inputs
      bytes += encode_inputs

      # output
      bytes += encode_outputs

      # placeholder for `references`
      bytes += encode_references if version >= REFERENCES_TX_VERSION && references.present?

      # extra
      extra_bytes = extra.bytes
      raise InvalidTransactionFormatError, 'extra is too long' if extra_bytes.size > MAX_EXTRA_SIZE

      bytes += MixinBot.utils.encode_uint32 extra_bytes.size
      bytes += extra_bytes

      # aggregated
      bytes += if aggregated.nil?
                 # signatures
                 encode_signatures
               else
                 encode_aggregated_signature
               end

      @hash = SHA3::Digest::SHA256.hexdigest bytes.pack('C*')
      @hex = bytes.pack('C*').unpack1('H*')

      self
    end

    def decode
      @bytes = [hex].pack('H*').bytes
      @hash = SHA3::Digest::SHA256.hexdigest @bytes.pack('C*')

      magic = @bytes.shift(2)
      raise ArgumentError, 'Not valid raw' unless magic == MAGIC

      _version = @bytes.shift(2)
      @version = MixinBot.utils.decode_int _version

      asset = @bytes.shift(32)
      @asset = asset.pack('C*').unpack1('H*')

      # read inputs
      decode_inputs

      # read outputs
      decode_outputs

      # read references (must mirror +encode+ — only present when references are non-empty)
      decode_references if version >= REFERENCES_TX_VERSION && references.present?

      # read extra
      # unsigned 32 endian for extra size
      extra_size = MixinBot.utils.decode_uint32 @bytes.shift(4)
      @extra = @bytes.shift(extra_size).pack('C*')

      num = MixinBot.utils.decode_uint16 @bytes.shift(2)
      if num == MAX_ENCODE_INT
        # aggregated
        @aggregated = {}

        raise ArgumentError, 'invalid aggregated' unless MixinBot.utils.decode_uint16(@bytes.shift(2)) == AGGREGATED_SIGNATURE_PREFIX

        @aggregated['signature'] = @bytes.shift(64).pack('C*').unpack1('H*')

        byte = @bytes.shift
        case byte
        when AGGREGATED_SIGNATURE_ORDINAY_MASK.first
          @aggregated['signers'] = []
          masks_size = MixinBot.utils.decode_uint16 @bytes.shift(2)
          masks = @bytes.shift(masks_size)
          masks = Array(masks)

          masks.each_with_index do |mask, i|
            8.times do |j|
              k = 1 << j
              @aggregated['signers'].push((i * 8) + j) if mask & k == k
            end
          end
        when AGGREGATED_SIGNATURE_SPARSE_MASK.first
          signers_size = MixinBot.utils.decode_uint16 @bytes.shift(2)
          @aggregated['signers'] = []
          unless signers_size.zero?
            signers_size.times do
              @aggregated['signers'].push MixinBot.utils.decode_uint16(@bytes.shift(2))
            end
          end
        end
      elsif num.present? && num.positive? && @bytes.size.positive?
        @signatures = []
        num.times do
          signature = {}

          keys_size = MixinBot.utils.decode_uint16 @bytes.shift(2)

          keys_size.times do
            index = MixinBot.utils.decode_uint16 @bytes.shift(2)
            signature[index] = @bytes.shift(64).pack('C*').unpack1('H*')
          end

          @signatures << signature
        end
      end

      self
    end

    def to_h
      {
        version:,
        asset:,
        inputs:,
        outputs:,
        extra:,
        signatures:,
        aggregated:,
        hash:,
        references:
      }.compact
    end

    private

    def encode_inputs
      bytes = []

      bytes += MixinBot.utils.encode_uint16(inputs.size)

      inputs.each do |input|
        bytes += [input['hash']].pack('H*').bytes
        bytes += MixinBot.utils.encode_uint16(input['index'])

        # genesis
        genesis = input['genesis'] || ''
        if genesis.empty?
          bytes += NULL_BYTES
        else
          genesis_bytes = [genesis].pack('H*').bytes
          bytes += MixinBot.utils.encode_uint16 genesis_bytes.size
          bytes += genesis_bytes
        end

        # deposit
        deposit = input['deposit']
        if deposit.nil?
          bytes += NULL_BYTES
        else
          bytes += MAGIC
          bytes += [deposit['chain']].pack('H*').bytes

          asset_bytes = [deposit['asset']].pack('H*')
          bytes += MixinBot.utils.encode_uint16 asset_bytes.size
          bytes += asset_bytes

          transaction_bytes = [deposit['transaction']].pack('H*')
          bytes += MixinBot.utils.encode_uint16 transaction_bytes.size
          bytes += transaction_bytes

          bytes += MixinBot.utils.encode_uint64 deposit['index']

          amount_bytes = MixinBot.utils.bytes_of deposit['amount']
          bytes +=  MixinBot.utils.encode_uint16 amount_bytes.size
          bytes +=  amount_bytes
        end

        # mint
        mint = input['mint']
        if mint.nil?
          bytes += NULL_BYTES
        else
          bytes += MAGIC

          # group
          group = mint['group'] || ''
          if group.empty?
            bytes += NULL_BYTES
          else
            group_bytes = [group].pack('H*')
            bytes += MixinBot.utils.encode_uint16 group_bytes.size
            bytes += group_bytes
          end

          bytes += MixinBot.utils.encode_uint64 mint['batch']

          amount_bytes = MixinBot.utils.encode_int mint['amount']
          bytes +=  MixinBot.utils.encode_uint16 amount_bytes.size
          bytes +=  amount_bytes
        end
      end

      bytes
    end

    def encode_outputs
      bytes = []

      bytes += MixinBot.utils.encode_uint16 outputs.size

      outputs.each do |output|
        type = output['type'] || 0
        bytes += [0x00, type]

        # amount
        amount_bytes = MixinBot.utils.encode_int (output['amount'].to_d * 1e8).round
        bytes +=  MixinBot.utils.encode_uint16 amount_bytes.size
        bytes +=  amount_bytes

        # keys
        bytes +=  MixinBot.utils.encode_uint16 output['keys'].size
        output['keys'].each do |key|
          bytes += [key].pack('H*').bytes
        end

        # mask
        bytes += [output['mask']].pack('H*').bytes

        # script
        script_bytes = [output['script']].pack('H*').bytes
        bytes += MixinBot.utils.encode_uint16 script_bytes.size
        bytes += script_bytes

        # withdrawal
        withdrawal = output['withdrawal']
        if withdrawal.nil?
          bytes += NULL_BYTES
        else
          bytes += MAGIC

          # chain
          bytes += [withdrawal['chain']].pack('H*').bytes

          # asset
          asset_bytes = [withdrawal['asset']].pack('H*')
          bytes += MixinBot.utils.encode_uint16 asset_bytes.bytesize
          bytes += asset_bytes.bytes

          # address
          address = withdrawal['address'] || ''
          if address.empty?
            bytes += NULL_BYTES
          else
            address_bytes = [address].pack('H*').bytes
            bytes += MixinBot.utils.encode_uint16 address_bytes.size
            bytes += address_bytes
          end

          # tag
          tag = withdrawal['tag'] || ''
          if tag.empty?
            bytes += NULL_BYTES
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

      bytes += MixinBot.utils.encode_uint16 references.size

      references.each do |reference|
        bytes += [reference].pack('H*').bytes
      end

      bytes
    end

    def encode_aggregated_signature
      bytes = []

      bytes += MixinBot.utils.encode_uint16 MAX_ENCODE_INT
      bytes += MixinBot.utils.encode_uint16 AGGREGATED_SIGNATURE_PREFIX
      bytes += [aggregated['signature']].pack('H*').bytes

      signers = aggregated['signers'] || []
      if signers.empty?
        bytes += AGGREGATED_SIGNATURE_ORDINAY_MASK
        bytes += NULL_BYTES
        return bytes
      end

      signers.each_with_index do |sig, i|
        raise ArgumentError, 'signers not sorted' if i.positive? && sig <= signers[i - 1]
        raise ArgumentError, 'signers not sorted' if sig > MAX_ENCODE_INT
      end

      max = signers.last
      sig_byte_len = [aggregated['signature']].pack('H*').bytes.size
      if ((max / 8) + 1) > sig_byte_len
        bytes += AGGREGATED_SIGNATURE_SPARSE_MASK
        bytes += MixinBot.utils.encode_uint16 signers.size
        signers.each { |signer| bytes += MixinBot.utils.encode_uint16(signer) }
      else
        masks_bytes = Array.new((max / 8) + 1, 0)
        signers.each do |signer|
          masks_bytes[signer / 8] ^= (1 << (signer % 8))
        end
        bytes += AGGREGATED_SIGNATURE_ORDINAY_MASK
        bytes += MixinBot.utils.encode_uint16 masks_bytes.size
        bytes += masks_bytes
      end

      bytes
    end

    def encode_signatures
      bytes = []

      sl =
        if signatures.is_a? Array
          signatures.size
        else
          0
        end

      raise ArgumentError, 'signatures overflow' if sl == MAX_ENCODE_INT

      bytes += MixinBot.utils.encode_uint16 sl

      if sl.positive?
        signatures.each do |signature|
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

    def decode_inputs
      inputs_size = MixinBot.utils.decode_uint16 @bytes.shift(2)
      @inputs = []
      inputs_size.times do
        input = {}
        hash = @bytes.shift(32)
        input['hash'] = hash.pack('C*').unpack1('H*')

        index = @bytes.shift(2)
        input['index'] = MixinBot.utils.decode_uint16 index

        if @bytes[...2] == NULL_BYTES
          @bytes.shift 2
        else
          genesis_size = MixinBot.utils.decode_uint16 @bytes.shift(2)
          genesis = @bytes.shift genesis_size
          input['genesis'] = genesis.pack('C*').unpack1('H*')
        end

        if @bytes[...2] == NULL_BYTES
          @bytes.shift 2
        else
          magic = @bytes.shift(2)
          raise ArgumentError, 'Not valid input' unless magic == MAGIC

          deposit = {}
          deposit['chain'] = @bytes.shift(32).pack('C*').unpack1('H*')

          asset_size = MixinBot.utils.decode_uint16 @bytes.shift(2)
          deposit['asset'] = @bytes.shift(asset_size).unpack1('H*')

          transaction_size = MixinBot.utils.decode_uint16 @bytes.shift(2)
          deposit['transaction'] = @bytes.shift(transaction_size).unpack1('H*')

          deposit['index'] = MixinBot.utils.decode_uint64 @bytes.shift(8)

          amount_size = MixinBot.utils.decode_uint16 @bytes.shift(2)
          deposit['amount'] = MixinBot.utils.decode_int @bytes.shift(amount_size)

          input['deposit'] = deposit
        end

        if @bytes[...2] == NULL_BYTES
          @bytes.shift 2
        else
          magic = @bytes.shift(2)
          raise ArgumentError, 'Not valid input' unless magic == MAGIC

          mint = {}
          if @bytes[...2] == NULL_BYTES
            @bytes.shift 2
          else
            group_size = MixinBot.utils.decode_uint16 @bytes.shift(2)
            mint['group'] = @bytes.shift(group_size).unpack1('H*')
          end

          mint['batch'] = MixinBot.utils.decode_uint64 @bytes.shift(8)
          _amount_size = MixinBot.utils.decode_uint16 @bytes.shift(2)
          mint['amount'] = MixinBot.utils.decode_int @bytes.shift(_amount_size)

          input['mint'] = mint
        end

        @inputs.push input
      end

      self
    end

    def decode_outputs
      outputs_size = MixinBot.utils.decode_uint16 @bytes.shift(2)
      @outputs = []
      outputs_size.times do
        output = {}

        @bytes.shift
        type = @bytes.shift
        output['type'] = type

        amount_size = MixinBot.utils.decode_uint16 @bytes.shift(2)
        output['amount'] = format('%.8f', MixinBot.utils.decode_int(@bytes.shift(amount_size)).to_f / 1e8).gsub(/\.?0+$/, '')

        output['keys'] = []
        keys_size = MixinBot.utils.decode_uint16 @bytes.shift(2)
        keys_size.times do
          output['keys'].push @bytes.shift(32).pack('C*').unpack1('H*')
        end

        output['mask'] = @bytes.shift(32).pack('C*').unpack1('H*')

        script_size = MixinBot.utils.decode_uint16 @bytes.shift(2)
        output['script'] = @bytes.shift(script_size).pack('C*').unpack1('H*')

        if @bytes[...2] == NULL_BYTES
          @bytes.shift 2
        else
          magic = @bytes.shift(2)
          raise ArgumentError, 'Not valid output' unless magic == MAGIC

          withdrawal = {}
          withdrawal['chain'] = @bytes.shift(32).pack('C*').unpack1('H*')

          asset_size = MixinBot.utils.decode_uint16 @bytes.shift(2)
          withdrawal['asset'] = @bytes.shift(asset_size).unpack1('H*')

          if @bytes[...2] == NULL_BYTES
            @bytes.shift 2
          else
            address_size = MixinBot.utils.decode_uint16 @bytes.shift(2)
            withdrawal['address'] = @bytes.shift(address_size).pack('C*').unpack1('H*')
          end

          if @bytes[...2] == NULL_BYTES
            @bytes.shift 2
          else
            tag_size = MixinBot.utils.decode_uint16 @bytes.shift(2)
            withdrawal['tag'] = @bytes.shift(tag_size).pack('C*').unpack1('H*')
          end

          output['withdrawal'] = withdrawal
        end

        @outputs.push output
      end

      self
    end

    def decode_references
      references_size = MixinBot.utils.decode_uint16 @bytes.shift(2)
      @references = []

      references_size.times do
        @references.push @bytes.shift(32).pack('C*').unpack1('H*')
      end

      self
    end
  end
end
