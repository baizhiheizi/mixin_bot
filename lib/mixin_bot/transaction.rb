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
      Encoder.new(self).encode
    end

    def decode
      Decoder.new(self).decode
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
  end
end

require_relative 'transaction/buffer'
require_relative 'transaction/encoder'
require_relative 'transaction/decoder'
