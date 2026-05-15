# frozen_string_literal: true

module MixinBot
  module Utils
    module Address
      MAIN_ADDRESS_PREFIX = 'XIN'
      MIX_ADDRESS_PREFIX = 'MIX'
      MIX_ADDRESS_VERSION = 2

      def build_main_address(public_key)
        msg = MAIN_ADDRESS_PREFIX + public_key
        checksum = SHA3::Digest::SHA256.digest msg
        data = public_key + checksum[0...4]
        base58 = Base58.binary_to_base58 data, :bitcoin
        "#{MAIN_ADDRESS_PREFIX}#{base58}"
      end

      def parse_main_address(address)
        raise ArgumentError, 'invalid address' unless address.start_with? MAIN_ADDRESS_PREFIX

        data = address[MAIN_ADDRESS_PREFIX.length..]
        data = Base58.base58_to_binary data, :bitcoin

        payload = data[...-4]

        msg = MAIN_ADDRESS_PREFIX + payload
        checksum = SHA3::Digest::SHA256.digest msg

        raise ArgumentError, 'invalid address' unless checksum[0...4] == data[-4..]

        payload
      end

      def build_mix_address(members:, threshold:)
        raise ArgumentError, 'members should be an array' unless members.is_a? Array
        raise ArgumentError, 'members should not be empty' if members.empty?
        raise ArgumentError, 'members length should less than 256' if members.length > 255

        # raise ArgumentError, "invalid threshold: #{threshold}" if threshold > members.length

        prefix = [MIX_ADDRESS_VERSION].pack('C*') + [threshold].pack('C*') + [members.length].pack('C*')

        members = members.sort
        msg =
          if members.all?(&->(member) { member.start_with? MAIN_ADDRESS_PREFIX })
            members.map(&->(member) { parse_main_address(member) }).join
          elsif members.none?(&->(member) { member.start_with? MAIN_ADDRESS_PREFIX })
            members.map(&->(member) { MixinBot::UUID.new(hex: member).packed }).join
          else
            raise ArgumentError, 'invalid members'
          end

        checksum = SHA3::Digest::SHA256.digest(MIX_ADDRESS_PREFIX + prefix + msg)

        data = prefix + msg + checksum[0...4]
        data = Base58.binary_to_base58 data, :bitcoin
        "#{MIX_ADDRESS_PREFIX}#{data}"
      end

      def parse_mix_address(address)
        raise ArgumentError, 'invalid address' unless address.start_with? MIX_ADDRESS_PREFIX

        data = address[MIX_ADDRESS_PREFIX.length..]
        data = Base58.base58_to_binary data, :bitcoin
        raise ArgumentError, 'invalid address, length invalid' if data.length < 3 + 16 + 4

        msg = data[...-4]
        checksum = SHA3::Digest::SHA256.digest((MIX_ADDRESS_PREFIX + msg))[0...4]

        raise ArgumentError, 'invalid address, checksum invalid' unless checksum[0...4] == data[-4..]

        version = data[0].ord
        raise ArgumentError, 'invalid address, version invalid' unless version == MIX_ADDRESS_VERSION

        threshold = data[1].ord
        members_count = data[2].ord

        if data[3...-4].length == members_count * 16
          members = data[3...-4].chars.each_slice(16).map(&:join)
          members = members.map(&->(member) { MixinBot::UUID.new(raw: member).unpacked })
        else
          members = data[3...-4].chars.each_slice(64).map(&:join)
          members = members.map(&->(member) { build_main_address(member) })
        end

        {
          members:,
          threshold:
        }
      end

      def build_safe_recipient(**kwargs)
        members = kwargs[:members]
        threshold = kwargs[:threshold]
        amount = kwargs[:amount]

        members = [members] if members.is_a? String
        amount = format('%.8f', amount.to_d.to_r).gsub(/\.?0+$/, '')

        {
          members:,
          threshold:,
          amount:,
          mix_address: build_mix_address(members:, threshold:)
        }
      end

      def burning_address
        seed = "\0" * 64

        digest1 = SHA3::Digest::SHA256.digest seed
        digest2 = SHA3::Digest::SHA256.digest digest1
        src = digest1 + digest2

        spend_key = MixinBot::Utils.shared_public_key(seed)
        view_key = MixinBot::Utils.shared_public_key(src)

        MixinBot::Utils.build_main_address spend_key + view_key
      end

      ##
      # Sorted-member hash used by Safe outputs and legacy collectible listing (Go +HashMembers+).
      #
      def hash_members(ids)
        list = Array(ids).flatten.compact.map(&:to_s).sort
        SHA3::Digest::SHA256.hexdigest(list.join)
      end
    end
  end
end
