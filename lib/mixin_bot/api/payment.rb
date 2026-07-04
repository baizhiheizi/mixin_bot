# frozen_string_literal: true

module MixinBot
  class API
    module Payment
      def safe_pay_url(**kwargs)
        members = kwargs[:members]
        threshold = kwargs[:threshold]
        asset_id = kwargs[:asset_id]
        amount = kwargs[:amount]
        memo = kwargs[:memo] || ''
        trace_id = kwargs[:trace_id] || SecureRandom.uuid

        mix_address = MixinBot.utils.build_mix_address(members:, threshold:)
        # Format amount without scientific notation so the Mixin web UI's URL
        # parser accepts it. Mirrors `MixinBot::Utils::Address#build_safe_recipient`.
        amount = format('%.8f', amount.to_d.to_r).gsub(/\.?0+\z/, '')

        "https://mixin.one/pay/#{mix_address}?amount=#{amount}&asset=#{asset_id}&memo=#{memo}&trace=#{trace_id}"
      end
    end
  end
end
