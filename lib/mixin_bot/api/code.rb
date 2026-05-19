# frozen_string_literal: true

module MixinBot
  class API
    module Code
      def read_code(code_id, access_token: nil)
        path = format('/codes/%<code_id>s', code_id:)
        client.get path, access_token: access_token || ''
      end

      def read_multisig_by_code(code_id, access_token: nil)
        read_code(code_id, access_token:)
      end
    end
  end
end
