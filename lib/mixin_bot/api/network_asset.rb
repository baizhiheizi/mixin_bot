# frozen_string_literal: true

require 'cgi'

module MixinBot
  class API
    module NetworkAsset
      def network_asset(asset_id)
        path = format('/network/assets/%<asset_id>s', asset_id:)
        client.get path, access_token: ''
      end
      alias read_asset network_asset

      def network_ticker(asset_id, offset: nil, access_token: nil)
        params = { asset: asset_id, offset: }.compact
        client.get '/network/ticker', **params, access_token: access_token || ''
      end
      alias read_asset_ticker network_ticker

      def network_asset_search(name)
        path = "/network/assets/search/#{CGI.escape(name.to_s)}"
        client.get path, access_token: ''
      end
      alias asset_search network_asset_search
    end
  end
end
