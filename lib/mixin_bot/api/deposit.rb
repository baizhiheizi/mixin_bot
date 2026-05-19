# frozen_string_literal: true

module MixinBot
  class API
    module Deposit
      def pending_safe_deposits
        client.get '/safe/deposits', access_token: ''
      end
      alias fetch_pending_safe_deposits pending_safe_deposits
    end
  end
end
