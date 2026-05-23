# frozen_string_literal: true

module MixinBot
  class API
    module External
      def external_proxy(method:, params: [], access_token: nil)
        client.post '/external/proxy', method:, params:, access_token:
      end
      alias proxy external_proxy
    end
  end
end
