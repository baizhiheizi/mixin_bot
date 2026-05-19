# frozen_string_literal: true

module MixinBot
  class API
    module Withdraw
      def create_withdraw_address(**kwargs)
        path = '/addresses'
        pin = kwargs[:pin]
        payload =
          {
            asset_id: kwargs[:asset_id],
            destination: kwargs[:destination],
            tag: kwargs[:tag],
            label: kwargs[:label]
          }

        payload.update(
          tip_or_legacy_pin_payload(pin, 'TIP:ADDRESS:ADD:', payload[:asset_id], payload[:destination], payload[:tag], payload[:label])
        )

        client.post path, **payload
      end
      alias create_address create_withdraw_address

      def get_withdraw_address(address, access_token: nil)
        path = format('/addresses/%<address>s', address:)

        client.get path, access_token:
      end
      alias read_address get_withdraw_address

      def delete_withdraw_address(address, **kwargs)
        pin = kwargs[:pin]

        path = format('/addresses/%<address>s/delete', address:)
        payload = tip_or_legacy_pin_payload(pin, 'TIP:ADDRESS:REMOVE:', address)

        client.post path, **payload
      end
      alias delete_address delete_withdraw_address

      def withdrawals(**kwargs)
        address_id = kwargs[:address_id]
        pin = kwargs[:pin]
        amount = format('%.8f', kwargs[:amount].to_d.to_r)
        trace_id = kwargs[:trace_id]
        memo = kwargs[:memo]
        access_token = kwargs[:access_token]

        path = '/withdrawals'
        payload = {
          address_id:,
          amount:,
          trace_id:,
          memo:
        }

        fee = '0'
        payload.update(
          tip_or_legacy_pin_payload(pin, 'TIP:WITHDRAWAL:CREATE:', address_id, amount, fee, trace_id, memo)
        )

        client.post path, **payload, access_token:
      end
      alias send_withdrawal withdrawals

      def withdraw_addresses(asset_id, access_token: nil)
        path = format('/assets/%<asset_id>s/addresses', asset_id:)
        client.get path, access_token:
      end
      alias get_addresses_by_asset_id withdraw_addresses

      def check_address(asset:, destination:, tag: nil)
        client.get '/external/addresses/check', asset:, destination:, tag:, access_token: ''
      end
    end
  end
end
