# frozen_string_literal: true

module MixinBot
  class API
    module Turn
      def turn_servers(access_token: nil)
        client.get '/turn', access_token:
      end
      alias get_turn_server turn_servers
    end
  end
end
