# frozen_string_literal: true

module MixinBot
  class API
    module App
      def add_favorite_app(app_id, access_token: nil)
        path = format('/apps/%<id>s/favorite', id: app_id)

        client.post path, access_token:
      end

      def remove_favorite_app(app_id, access_token: nil)
        path = format('/apps/%<id>s/unfavorite', id: app_id)

        client.post path, access_token:
      end

      def favorite_apps(user_id = nil, access_token: nil)
        path = format('/users/%<id>s/apps/favorite', id: user_id || config.app_id)

        client.get path, access_token:
      end

      def transfer_app_ownership(receiver_user_id:, pin:, access_token: nil)
        path = format('/apps/%<app_id>s/transfer', app_id: config.app_id)
        tip = tip_or_legacy_pin_payload(pin, 'TIP:APP:OWNERSHIP:TRANSFER:', receiver_user_id)
        client.post path, user_id: receiver_user_id, pin_base64: tip[:pin_base64] || tip[:pin], access_token:
      end
      alias migrate transfer_app_ownership
    end
  end
end
