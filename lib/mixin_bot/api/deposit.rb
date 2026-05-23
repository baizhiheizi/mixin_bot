# frozen_string_literal: true

module MixinBot
  class API
    module Deposit
      def pending_safe_deposits(**params)
        query = {
          limit: params[:limit],
          offset: params[:offset],
          asset: params[:asset],
          destination: params[:destination],
          tag: params[:tag]
        }.compact
        client.get '/safe/deposits', **query, access_token: params[:access_token] || ''
      end
      alias fetch_pending_safe_deposits pending_safe_deposits
    end
  end
end
