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

      def create_scheme(target, access_token: nil)
        client.post '/schemes', target:, access_token:
      end
      alias schemes create_scheme
    end
  end
end
