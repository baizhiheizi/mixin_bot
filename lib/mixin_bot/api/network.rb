# frozen_string_literal: true

module MixinBot
  class API
    module Network
      def network_assets
        client.get '/network', access_token: ''
      end
      alias read_network_assets network_assets

      def network_assets_top
        client.get '/network/assets/top', access_token: ''
      end
      alias read_network_assets_top network_assets_top
    end
  end
end
