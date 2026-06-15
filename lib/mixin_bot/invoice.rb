# frozen_string_literal: true

module MixinBot
  class Invoice
    INVOICE_PREFIX = 'MIN'
    INVOICE_VERSION = 0x00

    attr_accessor :version, :recipient, :entries, :address

    def initialize(**args)
      args = args.with_indifferent_access

      if args[:address]
        @address = args[:address]
        decode
      else
        @version = args[:version] || INVOICE_VERSION
        @recipient = args[:recipient]
        @entries = args[:entries] || []
        encode
      end
    end

    def to_hash
      {
        version:,
        address:,
        recipient: recipient.address,
        entries: entries.map(&:to_hash)
      }
    end

    def encode
      # Start with empty payload
      payload = []

      # Add version
      payload += MixinBot.utils.encode_int(version)

      # Add recipient - ensure we're using the raw payload bytes
      recipient_payload = recipient.payload
      recipient_bytes = recipient_payload.is_a?(String) ? recipient_payload.bytes : recipient_payload
      payload += MixinBot.utils.encode_uint16(recipient_bytes.size)

      payload += recipient_bytes

      # Add entries
      payload += MixinBot.utils.encode_int(entries.size)
      entries.each do |entry|
        payload += entry.encode
      end

      # Convert payload to binary string
      payload = payload.pack('C*')

      # Calculate checksum
      checksum = SHA3::Digest::SHA3_256.digest(INVOICE_PREFIX + payload)[0...4]

      # Combine everything and encode to base64
      self.address = INVOICE_PREFIX + Base64.urlsafe_encode64(payload + checksum, padding: false)
    end

    def decode
      prefix = address[0..2]
      raise MixinBot::InvalidInvoiceFormatError, 'invalid invoice prefix' unless prefix == INVOICE_PREFIX

      data = Base64.urlsafe_decode64(address[3..])
      raise MixinBot::InvalidInvoiceFormatError, 'invalid invoice payload size' if data.size < 3 + 23 + 1

      payload = data[...-4]
      checksum = SHA3::Digest::SHA3_256.digest(INVOICE_PREFIX + payload)[0...4]
      raise MixinBot::InvalidInvoiceFormatError, 'invalid invoice checksum' unless checksum == data[-4..]

      payload = payload.bytes

      # Read version
      self.version = MixinBot.utils.decode_int payload.shift(1)
      raise MixinBot::InvalidInvoiceFormatError, 'invalid invoice version' unless version == INVOICE_VERSION

      # Read recipient with proper size handling
      recipient_size = MixinBot.utils.decode_uint16 payload.shift(2)
      recipient_bytes = payload.shift(recipient_size)
      self.recipient = MixinBot::MixAddress.new(payload: recipient_bytes.pack('C*'))

      # decode entries
      entries_size = MixinBot.utils.decode_int payload.shift(1)
      entries = []
      entries_size.times do
        next if payload.empty?

        trace_id_bytes = payload.shift(16)
        trace_id = MixinBot::UUID.new(raw: trace_id_bytes.pack('C*')).unpacked

        asset_id_bytes = payload.shift(16)
        asset_id = MixinBot::UUID.new(raw: asset_id_bytes.pack('C*')).unpacked

        amount_size = MixinBot.utils.decode_int payload.shift(1)
        amount_bytes = payload.shift(amount_size)
        amount = amount_bytes.pack('C*').to_d

        extra_size = MixinBot.utils.decode_int payload.shift(2)
        extra = payload.shift(extra_size).pack('C*')

        references_count = MixinBot.utils.decode_int payload.shift(1)
        hash_references = []
        index_references = []

        references_count.times do
          rv = MixinBot.utils.decode_int payload.shift(1)
          case rv
          when 0
            hash_references << payload.shift(32).pack('C*').unpack1('H*')
          when 1
            index_references << MixinBot.utils.decode_int(payload.shift(1))
          else
            raise MixinBot::InvalidInvoiceFormatError, "invalid invoice reference type: #{rv}"
          end
        end

        entries << InvoiceEntry.new(trace_id:, asset_id:, amount:, extra:, index_references:, hash_references:)
      end

      self.entries = entries
    end
  end

  class InvoiceEntry
    attr_accessor :trace_id, :asset_id, :amount, :extra, :index_references, :hash_references

    def initialize(**args)
      args = args.with_indifferent_access

      @trace_id = args[:trace_id]
      @asset_id = args[:asset_id]
      @amount = args[:amount].to_d
      @extra = args[:extra]
      @index_references = args[:index_references]
      @hash_references = args[:hash_references]
    end

    def encode
      bytes = []

      bytes += MixinBot::UUID.new(hex: trace_id).packed.bytes
      bytes += MixinBot::UUID.new(hex: asset_id).packed.bytes

      amount_string = amount.to_d.to_s('F')
      amount_bytes = amount_string.bytes
      bytes += MixinBot.utils.encode_int(amount_bytes.size)
      bytes += amount_bytes

      extra_bytes = extra.bytes
      bytes += MixinBot.utils.encode_uint16(extra_bytes.size)
      bytes += extra_bytes

      references_count = (index_references || []).size + (hash_references || []).size
      bytes += MixinBot.utils.encode_int(references_count)

      index_references&.each do |index|
        bytes += MixinBot.utils.encode_int(1)
        bytes += MixinBot.utils.encode_int(index)
      end

      hash_references&.each do |hash|
        bytes += MixinBot.utils.encode_int(0)
        bytes += [hash].pack('H*').bytes
      end

      bytes
    end

    def to_hash
      {
        trace_id:,
        asset_id:,
        amount:,
        extra:,
        index_references:,
        hash_references:
      }
    end
  end
end
