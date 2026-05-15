# frozen_string_literal: true

module MixinBot
  class API
    module LegacyTransfer
      TRANSFER_ARGUMENTS = %i[asset_id opponent_id amount].freeze
      def create_legacy_transfer(pin, **kwargs)
        warn_legacy_mixin_api!('LegacyTransfer#create_legacy_transfer')
        raise ArgumentError, "#{TRANSFER_ARGUMENTS.join(', ')} are needed for create transfer" unless TRANSFER_ARGUMENTS.all? do |param|
                                                                                                        kwargs.keys.include? param
                                                                                                      end

        asset_id = kwargs[:asset_id]
        opponent_id = kwargs[:opponent_id]
        amount = format('%.8f', kwargs[:amount].to_d.to_r).gsub(/\.?0+$/, '')
        trace_id = kwargs[:trace_id] || SecureRandom.uuid
        memo = kwargs[:memo] || ''

        payload = {
          asset_id:,
          opponent_id:,
          amount:,
          trace_id:,
          memo:
        }

        payload.update(
          tip_or_legacy_pin_payload(pin, 'TIP:TRANSFER:CREATE:', asset_id, opponent_id, amount, trace_id, memo)
        )

        path = '/transfers'
        client.post path, **payload
      end

      def legacy_transfer(trace_id, access_token: nil)
        warn_legacy_mixin_api!('LegacyTransfer#legacy_transfer')
        path = format('/transfers/trace/%<trace_id>s', trace_id:)
        client.get path, access_token:
      end

      alias transfer legacy_transfer
      alias create_transfer create_legacy_transfer
    end
  end
end
