# frozen_string_literal: true

module MixinBot
  class Nfo
    NFT_MEMO_PREFIX = 'NFO'
    NFT_MEMO_VERSION = 0x00
    NFT_MEMO_DEFAULT_CHAIN = '43d61dcd-e413-450d-80b8-101d5e903357'
    NFT_MEMO_DEFAULT_CLASS = '3c8c161a18ae2c8b14fda1216fff7da88c419b5d'
    NULL_UUID = '00000000-0000-0000-0000-000000000000'

    attr_reader :prefix, :version, :raw
    attr_accessor :mask, :chain, :nm_class, :collection, :token, :extra, :memo, :hex

    def initialize(**kwargs)
      @prefix = NFT_MEMO_PREFIX
      @version = NFT_MEMO_VERSION
      @mask = kwargs[:mask] || 0
      @chain = kwargs[:chain] || NFT_MEMO_DEFAULT_CHAIN
      @nm_class = kwargs[:nm_class] || NFT_MEMO_DEFAULT_CLASS
      @collection = kwargs[:collection] || NULL_UUID
      @token = kwargs[:token].presence&.to_i
      @extra = kwargs[:extra]
      @memo = kwargs[:memo]
      @hex = kwargs[:hex]
    end

    def mint_memo
      raise MixinBot::InvalidNfoFormatError, 'token is required' if token.blank?
      raise MixinBot::InvalidNfoFormatError, 'extra must be 256-bit string' if extra.blank? || extra.size != 64

      @collection = NULL_UUID if collection.blank?
      @chain = NFT_MEMO_DEFAULT_CHAIN
      @nm_class = NFT_MEMO_DEFAULT_CLASS
      mark 0
      encode

      memo
    end

    def unique_token_id
      bytes = []
      bytes.concat MixinBot::UUID.new(hex: chain).packed.bytes
      bytes.concat [nm_class].pack('H*').bytes
      bytes.concat MixinBot::UUID.new(hex: collection).packed.bytes
      bytes.concat MixinBot.utils.encode_int token

      md5 = Digest::MD5.new
      md5.update bytes.pack('c*')
      digest = [md5.hexdigest].pack('H*').bytes

      digest[6] = (digest[6] & 0x0f) | 0x30
      digest[8] = (digest[8] & 0x3f) | 0x80

      hex = digest.pack('c*').unpack1('H*')

      MixinBot::UUID.new(hex:).unpacked
    end

    def mark(*indexes)
      indexes.map do |index|
        raise ArgumentError, "invalid NFO memo index #{index}" if index >= 64 || index.negative?

        @mask = mask ^ (1 << index)
      end
    end

    def encode
      bytes = []

      bytes.concat prefix.bytes
      bytes.push(version)

      if mask.zero?
        bytes << 0
      else
        bytes << 1
        bytes.concat MixinBot.utils.encode_uint64 mask
        bytes.concat MixinBot::UUID.new(hex: chain).packed.bytes

        class_bytes = [nm_class].pack('H*').bytes
        bytes.concat MixinBot.utils.encode_int class_bytes.size
        bytes.concat class_bytes

        collection_bytes = collection.split('-').pack('H* H* H* H* H*').bytes
        bytes.concat MixinBot.utils.encode_int collection_bytes.size
        bytes.concat collection_bytes

        # token_bytes = memo[:token].split('-').pack('H* H* H* H* H*').bytes
        token_bytes = MixinBot.utils.encode_int token
        bytes.concat MixinBot.utils.encode_int token_bytes.size
        bytes.concat token_bytes
      end

      extra_bytes = [extra].pack('H*').bytes
      bytes.concat MixinBot.utils.encode_int extra_bytes.size
      bytes.concat extra_bytes

      @raw = bytes.pack('C*')
      @hex = raw.unpack1('H*')
      @memo = Base64.urlsafe_encode64 raw, padding: false

      self
    end

    def decode
      @raw =
        if memo.present?
          Base64.urlsafe_decode64 memo
        elsif hex.present?
          [hex].pack('H*')
        else
          raise InvalidNfoFormatError, 'memo or hex is required'
        end

      @hex = raw.unpack1('H*') if hex.blank?
      @memo = Base64.urlsafe_encode64 raw, padding: false if memo.blank?

      decode_bytes
      self
    end

    def decode_bytes
      bytes = raw.bytes

      _prefix = bytes.shift(3).pack('C*')
      raise MixinBot::InvalidNfoFormatError, "NFO prefix #{_prefix}" if _prefix != prefix

      _version = bytes.shift
      raise MixinBot::InvalidNfoFormatError, "NFO version #{prefix}" if _version != version

      hint = bytes.shift
      if hint == 1
        @mask = bytes.shift(8).reverse.pack('C*').unpack1('Q*')

        @chain = MixinBot::UUID.new(hex: bytes.shift(16).pack('C*').unpack1('H*')).unpacked

        class_length = bytes.shift
        @nm_class = bytes.shift(class_length).pack('C*').unpack1('H*')

        collection_length = bytes.shift
        @collection = MixinBot::UUID.new(hex: bytes.shift(collection_length).pack('C*').unpack1('H*')).unpacked

        token_length = bytes.shift
        @token = MixinBot.utils.decode_int bytes.shift(token_length)
      end

      extra_length = bytes.shift
      @extra = bytes.shift(extra_length).pack('C*').unpack1('H*')

      self
    end

    def to_h
      hash = {
        prefix:,
        version:,
        mask:,
        chain:,
        class: nm_class,
        collection:,
        token:,
        extra:,
        memo:,
        hex:
      }

      hash.each do |key, value|
        hash.delete key if value.blank?
      end

      hash
    end
  end
end
