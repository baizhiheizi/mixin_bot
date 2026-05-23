# frozen_string_literal: true

module MixinBot
  class API
    module App
      def app(app_id, access_token: nil)
        path = format('/apps/%<id>s', id: app_id)
        client.get path, access_token:
      end
      alias fetch_app app

      def apps(access_token: nil)
        client.get '/apps', access_token:
      end
      alias fetch_apps apps

      def app_properties(access_token: nil)
        client.get '/apps/property', access_token:
      end
      alias app_property app_properties

      def app_billing(app_id, access_token: nil)
        path = format('/safe/apps/%<id>s/billing', id: app_id)
        client.get path, access_token:
      end

      ##
      # Verifies the app has billing headroom before a billed operation (e.g.
      # creating a network user). Skipped when +force+ is true.
      #
      # @param force [Boolean] skip the preflight and call the API anyway
      # @raise [InsufficientAppBillingError] when +credit+ is not greater than
      #   total cost plus the next user fee from {app_properties}
      #
      def ensure_app_billing_credit!(force: false, access_token: nil)
        return if force

        app_id = config.app_id
        billing = app_billing(app_id, access_token:)['data']
        properties = app_properties(access_token:)['data']

        credit = billing_decimal billing['credit']
        cost_users = billing_decimal billing.dig('cost', 'users')
        cost_resources = billing_decimal billing.dig('cost', 'resources')
        cost = cost_users + cost_resources
        increment = billing_decimal properties['price']

        return if credit > cost + increment

        raise InsufficientAppBillingError.new(
          app_id:,
          credit: credit.to_s('F'),
          cost: cost.to_s('F'),
          increment: increment.to_s('F')
        )
      end

      def create_app(**kwargs)
        payload = {
          redirect_uri: kwargs[:redirect_uri],
          home_uri: kwargs[:home_uri],
          name: kwargs[:name],
          description: kwargs[:description],
          icon_base64: kwargs[:icon_base64],
          category: kwargs[:category],
          capabilities: kwargs[:capabilities],
          resource_patterns: kwargs[:resource_patterns]
        }.compact
        client.post '/apps', **payload, access_token: kwargs[:access_token]
      end

      def update_app(app_id, **kwargs)
        path = format('/apps/%<id>s', id: app_id)
        payload = {
          redirect_uri: kwargs[:redirect_uri],
          home_uri: kwargs[:home_uri],
          name: kwargs[:name],
          description: kwargs[:description],
          icon_base64: kwargs[:icon_base64],
          category: kwargs[:category],
          capabilities: kwargs[:capabilities],
          resource_patterns: kwargs[:resource_patterns]
        }.compact
        client.post path, **payload, access_token: kwargs[:access_token]
      end

      def rotate_app_secret(app_id, access_token: nil)
        path = format('/apps/%<id>s/secret', id: app_id)
        client.post path, access_token:
      end
      alias update_app_secret rotate_app_secret

      def update_app_safe_session(app_id, session_public_key:, access_token: nil)
        path = format('/safe/apps/%<id>s/session', id: app_id)
        client.post path, session_public_key:, access_token:
      end

      def register_app_safe(app_id, spend_public_key:, signature_base64:, access_token: nil)
        path = format('/safe/apps/%<id>s/register', id: app_id)
        client.post path, spend_public_key:, signature_base64:, access_token:
      end

      def add_favorite_app(app_id, access_token: nil)
        path = format('/apps/%<id>s/favorite', id: app_id)

        client.post path, access_token:
      end
      alias favorite_app add_favorite_app

      def remove_favorite_app(app_id, access_token: nil)
        path = format('/apps/%<id>s/unfavorite', id: app_id)

        client.post path, access_token:
      end
      alias unfavorite_app remove_favorite_app

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

      private

      def billing_decimal(value)
        BigDecimal(value.to_s)
      end
    end
  end
end
