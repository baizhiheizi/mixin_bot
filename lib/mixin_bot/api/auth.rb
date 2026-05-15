# frozen_string_literal: true

module MixinBot
  class API
    module Auth
      def oauth_token(code)
        path = 'oauth/token'
        payload = {
          client_id: config.app_id,
          client_secret: config.client_secret,
          code:
        }
        client.post path, **payload
      end

      def request_oauth(scope = nil)
        scope ||= 'PROFILE:READ'
        format(
          'https://mixin.one/oauth/authorize?client_id=%<app_id>s&scope=%<scope>s',
          app_id: config.app_id,
          scope:
        )
      end

      def authorize_code(**kwargs)
        data = authorization_data(
          kwargs[:app_id],
          kwargs[:scope] || ['PROFILE:READ']
        )

        path = '/oauth/authorize'
        pin = kwargs[:pin] || config.pin
        raise ArgumentError, 'pin is required' if pin.blank?

        tip = tip_or_legacy_pin_payload(pin, 'TIP:OAUTH:APPROVE:', data['scopes'], data['authorization_id'])
        payload = {
          authorization_id: data['authorization_id'],
          scopes: data['scopes'],
          pin_base64: tip[:pin_base64] || tip[:pin]
        }

        client.post path, **payload, access_token: kwargs[:access_token]
      end

      def authorization_data(app_id, scope = ['PROFILE:READ'])
        @_app_id = app_id
        @_scope = scope.join(' ')
        EM.run do
          start_blaze_connect do
            def on_open(websocket, _event) # rubocop:disable Lint/NestedMethodDefinition
              websocket.send write_ws_message(
                action: 'REFRESH_OAUTH_CODE',
                params: {
                  client_id: @_app_id,
                  scope: @_scope,
                  authorization_id: '',
                  code_challenge: ''
                }
              )
            end

            def on_message(websocket, event) # rubocop:disable Lint/NestedMethodDefinition
              raw = JSON.parse ws_message(event.data)
              @_data = raw
              websocket.close
            end

            def on_close(_websocket, _event) # rubocop:disable Lint/NestedMethodDefinition
              EM.stop_event_loop
            end
          end
        end

        raise MixinBot::RequestError, @_data if @_data['error'].present?

        @_data['data']
      end
    end
  end
end
