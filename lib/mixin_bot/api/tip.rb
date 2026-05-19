# frozen_string_literal: true

module MixinBot
  class API
    module Tip
      TIP_ACTIONS = %w[
        TIP:VERIFY:
        TIP:ADDRESS:ADD:
        TIP:ADDRESS:REMOVE:
        TIP:USER:DEACTIVATE:
        TIP:EMERGENCY:CONTACT:CREATE:
        TIP:EMERGENCY:CONTACT:READ:
        TIP:EMERGENCY:CONTACT:REMOVE:
        TIP:PHONE:NUMBER:UPDATE:
        TIP:MULTISIG:REQUEST:SIGN:
        TIP:MULTISIG:REQUEST:UNLOCK:
        TIP:COLLECTIBLE:REQUEST:SIGN:
        TIP:COLLECTIBLE:REQUEST:UNLOCK:
        TIP:TRANSFER:CREATE:
        TIP:WITHDRAW:
        TIP:WITHDRAWAL:CREATE:
        TIP:TRANSACTION:CREATE:
        TIP:OAUTH:APPROVE:
        TIP:PROVISIONING:UPDATE:
        TIP:APP:OWNERSHIP:TRANSFER:
        SEQUENCER:REGISTER:
      ].freeze

      def encrypt_tip_pin(pin, action, *params)
        raise ArgumentError, 'invalid action' unless TIP_ACTIONS.include? action

        pin_key = MixinBot.utils.decode_key pin

        msg = action + params.flatten.map(&:to_s).join

        msg = Digest::SHA256.digest(msg) unless action == 'TIP:VERIFY:'

        signature = JOSE::JWA::Ed25519.sign msg, pin_key

        encrypt_pin signature
      end

      def get_tip_node(path, request_id: nil, access_token: nil)
        url = format('/external/tip/%<path>s', path:)
        if request_id.present?
          client.fetch_get url, access_token: access_token || ''
        else
          client.get url, access_token: access_token || ''
        end
      end
      alias get_tip_node_by_path get_tip_node

      def tip_migrate_body(pub_hex)
        "TIP:MIGRATE:#{pub_hex}"
      end

      def tip_body_for_verify(timestamp = (Time.now.to_f * 1e9).to_i)
        format('TIP:VERIFY:%032d', timestamp)
      end

      def tip_body_for_raw_transaction_create(asset_id, opponent_key, opponent_receivers, opponent_threshold, amount,
                                              trace_id, memo)
        receivers = Array(opponent_receivers).join
        format('TIP:TRANSACTION:CREATE:%s%s%s%s%s%s%s', asset_id, opponent_key, receivers, opponent_threshold, amount,
               trace_id, memo)
      end

      def tip_body_for_withdrawal_create(address_id, amount, fee, trace_id, memo)
        format('TIP:WITHDRAWAL:CREATE:%s%s%s%s%s', address_id, amount, fee, trace_id, memo)
      end

      def tip_body_for_transfer(asset_id, counter_user_id, amount, trace_id, memo)
        format('TIP:TRANSFER:CREATE:%s%s%s%s%s', asset_id, counter_user_id, amount, trace_id, memo)
      end

      def tip_body_for_phone_number_update(verification_id, code)
        format('TIP:PHONE:NUMBER:UPDATE:%s%s', verification_id, code)
      end

      def tip_body_for_emergency_contact_create(verification_id, code)
        format('TIP:EMERGENCY:CONTACT:CREATE:%s%s', verification_id, code)
      end

      def tip_body_for_address_add(asset_id, public_key, key_tag, name)
        format('TIP:ADDRESS:ADD:%s%s%s%s', asset_id, public_key, key_tag, name)
      end

      def tip_body_for_provisioning_update(device_id, secret)
        format('TIP:PROVISIONING:UPDATE:%s%s', device_id, secret)
      end

      def tip_body_for_ownership_transfer(user_id)
        format('TIP:APP:OWNERSHIP:TRANSFER:%s', user_id)
      end

      def tip_body_for_sequencer_register(user_id, public_key)
        format('SEQUENCER:REGISTER:%s%s', user_id, public_key)
      end

      def tip_body(str)
        str.to_s.b
      end
    end
  end
end
