# frozen_string_literal: true

module MixinBot
  class API
    module LegacyPayment
      def pay_url(**kwargs)
        warn_legacy_mixin_api!('LegacyPayment#pay_url')
        format(
          'https://mixin.one/pay?recipient=%<recipient_id>s&asset=%<asset>s&amount=%<amount>s&trace=%<trace>s&memo=%<memo>s',
          recipient_id: kwargs[:recipient_id],
          asset: kwargs[:asset_id],
          amount: kwargs[:amount].to_s,
          trace: kwargs[:trace],
          memo: kwargs[:memo]
        )
      end

      # https://developers.mixin.one/api/alpha-mixin-network/verify-payment/
      def verify_payment(**kwargs)
        warn_legacy_mixin_api!('LegacyPayment#verify_payment')
        path = '/payments'
        payload = {
          asset_id: kwargs[:asset_id],
          opponent_id: kwargs[:opponent_id],
          amount: kwargs[:amount].to_s,
          trace_id: kwargs[:trace]
        }

        client.post path, **payload
      end
    end
  end
end
