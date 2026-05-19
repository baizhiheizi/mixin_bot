# frozen_string_literal: true

module MixinBot
  class API
    module Session
      def fetch_user_sessions(user_ids, access_token: nil)
        raise ArgumentError, 'user_ids required' if user_ids.blank?

        client.fetch_post_array '/sessions/fetch', Array(user_ids), access_token:
      end
      alias fetch_user_session fetch_user_sessions
    end
  end
end
