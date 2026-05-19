# frozen_string_literal: true

module MixinBot
  class API
    module Fiat
      def fiats(access_token: nil)
        client.get '/external/fiats', access_token: access_token || ''
      end
      alias get_fiats fiats
    end
  end
end
