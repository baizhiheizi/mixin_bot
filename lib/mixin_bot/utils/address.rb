# frozen_string_literal: true

module MixinBot
  module Utils
    module Address
      MAIN_ADDRESS_PREFIX = MixinBot::MAIN_ADDRESS_PREFIX
      MIX_ADDRESS_PREFIX = MixinBot::MIX_ADDRESS_PREFIX
      MIX_ADDRESS_VERSION = MixinBot::MIX_ADDRESS_VERSION

      def build_main_address(public_key)
        MainAddress.new(public_key:).address
      end

      def parse_main_address(address)
        MainAddress.new(address:).public_key
      end

      def build_mix_address(members:, threshold:)
        MixAddress.from_members(members:, threshold:).address
      end

      def parse_mix_address(address)
        ma = MixAddress.parse(address)
        {
          members: ma.uuid_members + ma.xin_members,
          threshold: ma.threshold
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
        MainAddress.burning_address.address
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
