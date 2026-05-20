# frozen_string_literal: true

require 'faraday'

module MixinBot
  # Mixin Computer API client (https://computer.mixin.one).
  class Computer
    BASE_URI = 'https://computer.mixin.one'
    OPERATION_TYPE_ADD_USER = 1
    OPERATION_TYPE_SYSTEM_CALL = 2
    OPERATION_TYPE_USER_DEPOSIT = 3
    SOLANA_CHAIN_ID = '64692c23-8971-4cf4-84a7-4dd1271dd887'

    class << self
      def connection
        @connection ||= Faraday.new(url: BASE_URI) do |f|
          f.request :json
          f.response :json
          f.adapter Faraday.default_adapter
        end
      end

      def request(method, path, body = nil)
        response =
          case method.to_s.upcase
          when 'GET'
            connection.get(path)
          when 'POST'
            connection.post(path, body)
          else
            raise ArgumentError, "unsupported method #{method}"
          end
        raise MixinBot::ServerError, "computer HTTP #{response.status}" if response.status >= 500

        response.body
      end

      def info
        request 'GET', '/'
      end
      alias get_computer_info info

      def user(addr)
        request 'GET', "/users/#{addr}"
      end
      alias get_computer_user user

      def deployed_assets
        request 'GET', '/deployed_assets'
      end
      alias get_computer_deployed_assets deployed_assets

      def system_call(id)
        request 'GET', "/system_calls/#{id}"
      end
      alias get_computer_system_call system_call

      def deploy_external_assets(assets)
        assets = Array(assets)
        raise ArgumentError, "cannot deploy asset from Solana: #{SOLANA_CHAIN_ID}" if assets.include?(SOLANA_CHAIN_ID)

        request 'POST', '/deployed_assets', assets
      end
      alias computer_deploy_external_asset deploy_external_assets

      def lock_nonce_account(mix)
        request 'POST', '/nonce_accounts', { mix: }
      end
      alias lock_computer_nonce_account lock_nonce_account

      def fee_on_xin_from_sol(sol_amount)
        request 'POST', '/fee', { sol_amount: sol_amount.to_s }
      end
      alias get_fee_on_xin_based_on_sol fee_on_xin_from_sol

      def register_computer(api)
        info_data = info
        mix = MixinBot::MixAddress.from_members(members: [api.config.app_id], threshold: 1).address
        memo = encode_mtg_extra(
          info_data.dig('members', 'app_id'),
          encode_operation_memo(OPERATION_TYPE_ADD_USER, mix)
        )
        trace = MixinBot.utils.unique_object_id(mix, 'computer_register')
        api.create_safe_transfer(
          members: info_data.dig('members', 'members'),
          threshold: info_data.dig('members', 'threshold'),
          asset_id: info_data.dig('params', 'operation', 'asset'),
          amount: info_data.dig('params', 'operation', 'price'),
          trace_id: trace,
          memo:
        )
      end

      def user_id_to_bytes(id)
        n = Integer(id, 10)
        raise ArgumentError, "invalid user id: #{id}" if n.negative?

        [n].pack('Q>')
      end
      alias computer_user_id_to_bytes user_id_to_bytes

      def build_system_call_extra(uid, cid, skip_process: false, fid: nil)
        extra = user_id_to_bytes(uid)
        extra += MixinBot::UUID.new(hex: cid).packed
        extra += [skip_process ? 1 : 0].pack('C')
        extra += MixinBot::UUID.new(hex: fid).packed if fid.present?
        extra
      end

      def encode_operation_memo(operation, extra = +'')
        [operation].pack('C') + extra.to_s
      end

      def encode_mtg_extra(app_id, extra)
        data = MixinBot::UUID.new(hex: app_id).packed + extra.to_s
        Base64.urlsafe_encode64(data, padding: false)
      end

      def decode_computer_extra_base64(extra)
        data = Base64.urlsafe_decode64(extra)
        return ['', nil] if data.length < 16

        app_id = MixinBot::UUID.new(raw: data[0, 16]).unpacked
        [app_id, data[16..]]
      end

      def solana_asset_id_for(deployed)
        MixinBot.utils.unique_object_id(SOLANA_CHAIN_ID, deployed['address'])
      end
    end
  end
end
