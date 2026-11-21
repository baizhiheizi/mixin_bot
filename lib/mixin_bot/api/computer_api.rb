# frozen_string_literal: true

module MixinBot
  class API
    # Delegates to {MixinBot::Computer} for API surface parity with Go SDK.
    module ComputerApi
      def get_computer_info
        MixinBot::Computer.info(proxy: config.proxy_config)
      end

      def get_computer_user(addr)
        MixinBot::Computer.user(addr, proxy: config.proxy_config)
      end

      def get_computer_deployed_assets
        MixinBot::Computer.deployed_assets(proxy: config.proxy_config)
      end

      def get_computer_system_call(id)
        MixinBot::Computer.system_call(id, proxy: config.proxy_config)
      end

      def computer_deploy_external_asset(assets)
        MixinBot::Computer.deploy_external_assets(assets, proxy: config.proxy_config)
      end

      def lock_computer_nonce_account(mix)
        MixinBot::Computer.lock_nonce_account(mix, proxy: config.proxy_config)
      end

      def get_fee_on_xin_based_on_sol(sol_amount)
        MixinBot::Computer.fee_on_xin_from_sol(sol_amount, proxy: config.proxy_config)
      end

      def register_computer
        MixinBot::Computer.register_computer(self)
      end

      def computer_user_id_to_bytes(id)
        MixinBot::Computer.user_id_to_bytes(id)
      end

      def build_system_call_extra(uid, cid, skip_process: false, fid: nil)
        MixinBot::Computer.build_system_call_extra(uid, cid, skip_process:, fid:)
      end

      def encode_operation_memo(operation, extra = +'')
        MixinBot::Computer.encode_operation_memo(operation, extra)
      end

      def encode_mtg_extra(app_id, extra)
        MixinBot::Computer.encode_mtg_extra(app_id, extra)
      end

      def decode_computer_extra_base64(extra)
        MixinBot::Computer.decode_computer_extra_base64(extra)
      end
    end
  end
end
