# frozen_string_literal: true

module MixinBot
  class API
    module Multisig
      def create_safe_multisig_request(request_id, raw, access_token: nil)
        path = '/safe/multisigs'
        payload = [{
          request_id:,
          raw:
        }]

        client.post path, *payload, access_token:
      end

      def sign_safe_multisig_request(request_id, raw, access_token: nil)
        path = format('/safe/multisigs/%<request_id>s/sign', request_id:)

        payload = {
          raw:
        }

        client.post path, **payload, access_token:
      end

      def unlock_safe_multisig_request(request_id, access_token: nil)
        path = format('/safe/multisigs/%<request_id>s/unlock', request_id:)

        client.post path, access_token:
      end

      def safe_multisig_request(request_id, access_token: nil)
        path = format('/safe/multisigs/%<request_id>s', request_id:)

        client.get path, access_token:
      end
      alias fetch_safe_multisig_request safe_multisig_request

      def create_multisig_raw_tx(_asset_id:, senders:, receivers:, threshold:, inputs:, amount:, trace_id:,
                                 extra: '')
        out_hint = MixinBot.utils.unique_object_id(trace_id, 'OUTPUT', '0')
        change_hint = MixinBot.utils.unique_object_id(trace_id, 'OUTPUT', '1')
        keys = create_safe_keys(
          { receivers:, index: 0, hint: out_hint },
          { receivers: senders, index: 1, hint: change_hint }
        )['data']

        receivers_list = [
          { members: receivers, threshold: 1, amount: amount.to_s, ghosts: [keys[0]] },
          { members: senders, threshold:, amount: nil, ghosts: [keys[1]] }
        ].compact

        tx = build_safe_transaction(utxos: inputs, receivers: receivers_list, extra:)
        MixinBot.utils.encode_raw_transaction(tx)
      end
    end
  end
end
