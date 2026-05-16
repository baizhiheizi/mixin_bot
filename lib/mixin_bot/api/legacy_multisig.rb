# frozen_string_literal: true

module MixinBot
  class API
    module LegacyMultisig
      MULTISIG_REQUEST_ACTIONS = %i[sign unlock].freeze
      def create_multisig_request(action, raw, access_token: nil)
        warn_legacy_mixin_api!('LegacyMultisig#create_multisig_request')
        unless MULTISIG_REQUEST_ACTIONS.include? action.to_sym
          raise ArgumentError,
                "request action is limited in #{MULTISIG_REQUEST_ACTIONS.join(', ')}"
        end

        path = '/multisigs/requests'
        payload = {
          action:,
          raw:
        }
        client.post path, **payload, access_token:
      end

      # transfer from the multisig address
      def create_sign_multisig_request(raw, access_token: nil)
        warn_legacy_mixin_api!('LegacyMultisig#create_sign_multisig_request')
        create_multisig_request 'sign', raw, access_token:
      end

      # transfer from the multisig address
      # create a request for unlock a multi-sign
      def create_unlock_multisig_request(raw, access_token: nil)
        warn_legacy_mixin_api!('LegacyMultisig#create_unlock_multisig_request')
        create_multisig_request 'unlock', raw, access_token:
      end

      def sign_multisig_request(request_id, pin = nil)
        warn_legacy_mixin_api!('LegacyMultisig#sign_multisig_request')
        pin ||= config.pin
        path = format('/multisigs/requests/%<request_id>s/sign', request_id:)
        payload = tip_or_legacy_pin_payload(pin, 'TIP:MULTISIG:REQUEST:SIGN:', request_id)

        client.post path, **payload
      end

      def unlock_multisig_request(request_id, pin = nil)
        warn_legacy_mixin_api!('LegacyMultisig#unlock_multisig_request')
        pin ||= config.pin

        path = format('/multisigs/requests/%<request_id>s/unlock', request_id:)
        payload = tip_or_legacy_pin_payload(pin, 'TIP:MULTISIG:REQUEST:UNLOCK:', request_id)

        client.post path, **payload
      end

      # pay to the multisig address
      # used for create multisig payment code_id
      def create_multisig_payment(**kwargs)
        warn_legacy_mixin_api!('LegacyMultisig#create_multisig_payment')
        path = '/payments'
        payload = {
          asset_id: kwargs[:asset_id],
          amount: format('%.8f', kwargs[:amount].to_d),
          trace_id: kwargs[:trace_id] || SecureRandom.uuid,
          memo: kwargs[:memo],
          opponent_multisig: {
            receivers: kwargs[:receivers],
            threshold: kwargs[:threshold]
          }
        }
        client.post path, **payload, access_token: kwargs[:access_token]
      end

      def verify_multisig(code_id, access_token: nil)
        warn_legacy_mixin_api!('LegacyMultisig#verify_multisig')
        path = format('/codes/%<code_id>s', code_id:)
        client.get path, access_token:
      end
    end
  end
end
