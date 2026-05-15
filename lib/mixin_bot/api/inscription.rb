# frozen_string_literal: true

module MixinBot
  class API
    module Inscription
      def collection(hash)
        path = "/safe/inscriptions/collections/#{hash}"

        client.get path
      end

      def collectible(hash)
        path = "/safe/inscriptions/items/#{hash}"

        client.get path
      end

      def collection_collectibles(hash, offset: 0)
        path = "/safe/inscriptions/collections/#{hash}/items"

        client.get path, offset:
      end

      def collectibles(members: [], access_token: nil, state: :unspent)
        unspent_outputs = safe_outputs(state:, members:, access_token:)['data']
        unspent_outputs.select { |output| output['inscription_hash'].present? }
      end

      def create_collectible_transfer(utxo, **kwargs)
        # verify collectible
        utxo = utxo.with_indifferent_access
        raise MixinBot::ArgumentError, 'not a valid collectible' unless utxo['inscription_hash'].present?

        # verify members
        members = [kwargs[:members]].flatten.compact
        raise ArgumentError, 'members required' if members.blank?

        threshold = kwargs[:threshold] || members.length
        request_id = kwargs[:request_id] || kwargs[:trace_id] || SecureRandom.uuid

        memo = kwargs[:memo] || ''

        # build transaction
        tx = build_safe_transaction(
          utxos: [utxo],
          receivers: [{
            members:,
            threshold:,
            amount: utxo['amount']
          }],
          extra: memo
        )

        # encode transaction
        raw = MixinBot.utils.encode_raw_transaction tx

        # verify transaction
        request = create_safe_transaction_request(request_id, raw)['data']

        # sign transaction
        spend_key = MixinBot.utils.decode_key(kwargs[:spend_key]) || config.spend_key
        signed_raw = MixinBot.api.sign_safe_transaction(
          raw:,
          utxos: [utxo],
          request: request[0],
          spend_key:
        )

        # submit transaction
        send_safe_transaction(
          request_id,
          signed_raw
        )
      end
    end
  end
end
