# frozen_string_literal: true

module MixinBot
  MAIN_ADDRESS_PREFIX = 'XIN'
  MIX_ADDRESS_PREFIX = 'MIX'
  MIX_ADDRESS_VERSION = 2
  UUID_ADDRESS_LENGTH = 16
  MAIN_ADDRESS_LENGTH = 64

  class MixAddress
    attr_accessor :version, :uuid_members, :xin_members, :threshold, :address, :payload

    def self.parse(string)
      new(address: string)
    end

    def self.from_members(members:, threshold:)
      new(members:, threshold:)
    end

    def initialize(**args)
      args = args.with_indifferent_access

      if args[:address]
        @address = args[:address]
        decode
      elsif args[:payload]
        @payload = args[:payload]
        decode
      else
        @version = args[:version] || MIX_ADDRESS_VERSION

        if args[:members].present?
          @xin_members, @uuid_members = args[:members].partition do |member|
            member.start_with?(MAIN_ADDRESS_PREFIX)
          end
        else
          @uuid_members = args[:uuid_members] || []
          @xin_members = args[:xin_members] || []
        end

        @uuid_members = @uuid_members.sort
        @xin_members = @xin_members.sort

        @threshold = args[:threshold]
        encode
      end

      raise ArgumentError, 'invalid address' unless valid?
    end

    def valid?
      address.present? && (uuid_members.present? || xin_members.present?) && threshold.present?
    end

    def to_safe_recipient
      {
        members: uuid_members + xin_members,
        threshold:,
        amount:,
        mix_address: address
      }
    end

    def request_or_generate_ghost_keys(output_index = 0, api: MixinBot.api)
      if xin_members.present?
        key = JOSE::JWA::Ed25519.keypair
        gk = { 'mask' => key[0].unpack1('H*'), 'keys' => [] }
        xin_members.each do |member|
          payload = MixinBot.utils.parse_main_address(member)
          spend_key = payload[0...32]
          view_key = payload[-32..]
          ghost = MixinBot.utils.derive_ghost_public_key(key[1], view_key, spend_key, output_index)
          gk['keys'] << ghost.unpack1('H*')
        end
        gk
      else
        hint = SecureRandom.uuid
        api.create_safe_keys(
          { receivers: (uuid_members + xin_members).sort, index: output_index, hint: }
        )['data'].first
      end
    end

    def encode
      raise ArgumentError, 'members should be an array' unless uuid_members.is_a?(Array) || xin_members.is_a?(Array)
      raise ArgumentError, 'members should not be empty' if uuid_members.empty? && xin_members.empty?
      raise ArgumentError, 'members length should less than 256' if uuid_members.length + xin_members.length > 255

      member_count = uuid_members.length + xin_members.length
      # UUID mix (Go NewUUIDMixAddress): threshold must be in 1..len(members).
      # XIN-only mix (Go NewMainnetMixAddress): threshold may exceed member count (sparse), e.g. storage 1-of-64 style.
      if uuid_members.present? && xin_members.empty?
        raise ArgumentError, "invalid threshold: #{threshold}" unless threshold.positive? && threshold <= member_count
      elsif xin_members.present? && uuid_members.empty?
        raise ArgumentError, "invalid threshold: #{threshold}" unless threshold.positive?
        raise ArgumentError, 'too many XIN members' if member_count > 64
      elsif threshold > member_count
        raise ArgumentError, "invalid threshold: #{threshold}"
      end

      prefix =
        [version].pack('C*') +
        [threshold].pack('C*') +
        [uuid_members.length + xin_members.length].pack('C*')
      msg =
        uuid_members&.map(&->(member) { MixinBot::UUID.new(hex: member).packed })&.join.to_s +
        xin_members&.map(&->(member) { MainAddress.new(address: member).public_key })&.join.to_s

      self.payload = prefix + msg

      checksum = SHA3::Digest::SHA256.digest(MIX_ADDRESS_PREFIX + payload)
      data = payload + checksum[0...4]
      data = Base58.binary_to_base58 data, :bitcoin
      self.address = "#{MIX_ADDRESS_PREFIX}#{data}"

      address
    end

    def decode
      if address.present?
        raise ArgumentError, 'invalid address' unless address&.start_with? MIX_ADDRESS_PREFIX

        data = address[MIX_ADDRESS_PREFIX.length..]
        data = Base58.base58_to_binary data, :bitcoin
        raise ArgumentError, 'invalid address, length invalid' if data.length < 3 + 16 + 4

        self.payload = data[...-4]
        checksum = SHA3::Digest::SHA256.digest(MIX_ADDRESS_PREFIX + payload)[0...4]
        raise ArgumentError, 'invalid address, checksum invalid' unless checksum == data[-4..]
      else
        checksum = SHA3::Digest::SHA256.digest(MIX_ADDRESS_PREFIX + payload)[0...4]
        data = payload + checksum
        data = Base58.binary_to_base58 data, :bitcoin
        self.address = "#{MIX_ADDRESS_PREFIX}#{data}"
      end

      self.version = payload[0].ord
      raise ArgumentError, 'invalid address, version invalid' unless version.is_a?(Integer)

      self.threshold = payload[1].ord
      raise ArgumentError, 'invalid address, threshold invalid' unless threshold.is_a?(Integer)

      members_count = payload[2].ord
      raise ArgumentError, 'invalid address, members count invalid' unless members_count.is_a?(Integer)

      if payload[3...].length == members_count * UUID_ADDRESS_LENGTH
        uuid_members = payload[3...].chars.each_slice(UUID_ADDRESS_LENGTH).map(&:join)
        self.uuid_members = uuid_members.map(&->(member) { MixinBot::UUID.new(raw: member).unpacked })
        self.xin_members = []
      else
        xin_members = payload[3...].chars.each_slice(MAIN_ADDRESS_LENGTH).map(&:join)
        self.xin_members = xin_members.map(&->(member) { MainAddress.new(public_key: member).address })
        self.uuid_members = []
      end
    end
  end

  class MainAddress
    attr_accessor :public_key, :address

    def initialize(**args)
      if args[:address]
        @address = args[:address]
        decode
      else
        @public_key = args[:public_key]
        encode
      end
    end

    def encode
      msg = MAIN_ADDRESS_PREFIX + public_key
      checksum = SHA3::Digest::SHA256.digest msg
      data = public_key + checksum[0...4]
      base58 = Base58.binary_to_base58 data, :bitcoin
      self.address = "#{MAIN_ADDRESS_PREFIX}#{base58}"

      address
    end

    def decode
      raise ArgumentError, 'invalid address' unless address.start_with? MAIN_ADDRESS_PREFIX

      data = address[MAIN_ADDRESS_PREFIX.length..]
      data = Base58.base58_to_binary data, :bitcoin

      payload = data[...-4]

      msg = MAIN_ADDRESS_PREFIX + payload
      checksum = SHA3::Digest::SHA256.digest msg

      raise ArgumentError, 'invalid address' unless checksum[0...4] == data[-4..]

      self.public_key = payload

      public_key
    end

    def self.burning_address
      seed = "\0" * 64

      digest1 = SHA3::Digest::SHA256.digest seed
      digest2 = SHA3::Digest::SHA256.digest digest1
      src = digest1 + digest2

      spend_key = MixinBot::Utils.shared_public_key(seed)
      view_key = MixinBot::Utils.shared_public_key(src)

      MainAddress.new(public_key: spend_key + view_key)
    end
  end
end
