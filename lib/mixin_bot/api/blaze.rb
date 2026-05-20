# frozen_string_literal: true

module MixinBot
  class API
    module Blaze
      def blaze
        access_token = access_token('GET', '/', '')

        authorization = format('Bearer %<access_token>s', access_token:)
        Faye::WebSocket::Client.new(
          format('wss://%<host>s/', host: config.blaze_host),
          ['Mixin-Blaze-1'],
          headers: { 'Authorization' => authorization },
          ping: 60
        )
      end

      def start_blaze_connect(reconnect: true, &_block)
        ws ||= blaze
        yield if block_given?

        ws.on :open do |event|
          if defined? on_open
            on_open ws, event
          else
            p [Time.now.to_s, :open]
            ws.send list_pending_message
          end
        end

        ws.on :message do |event|
          if defined? on_message
            on_message ws, event
          else
            raw = JSON.parse ws_message(event.data)
            p [Time.now.to_s, :message, raw&.[]('action')]

            ws.send acknowledge_message_receipt(raw['data']['message_id']) unless raw&.[]('data')&.[]('message_id').nil?
          end
        end

        ws.on :error do |event|
          if defined? on_error
            on_error ws, event
          else
            p [Time.now.to_s, :error]
          end
        end

        ws.on :close do |event|
          if defined? on_close
            on_close ws, event
          else
            p [Time.now.to_s, :close, event.code, event.reason]
          end

          ws = nil
          start_blaze_connect(&_block) if reconnect
        end
      end

      def blaze_send_plain_text(socket, conversation_id:, recipient_id:, content:)
        socket.send write_ws_message(
          params: {
            conversation_id:,
            recipient_id:,
            message_id: SecureRandom.uuid,
            category: 'PLAIN_TEXT',
            data_base64: Base64.urlsafe_encode64(content.to_s, padding: false)
          }
        )
      end

      def blaze_send_recall_message(socket, conversation_id:, recipient_id:, message_id:)
        data = { message_id: }.to_json
        socket.send write_ws_message(
          params: {
            conversation_id:,
            recipient_id:,
            message_id: SecureRandom.uuid,
            category: 'MESSAGE_RECALL',
            data_base64: Base64.urlsafe_encode64(data, padding: false)
          }
        )
      end

      def blaze_send_post(socket, conversation_id:, recipient_id:, content:)
        blaze_send_plain_text(socket, conversation_id:, recipient_id:, content:)
      end

      def blaze_send_contact(socket, conversation_id:, recipient_id:, contact_id:)
        data = { user_id: contact_id }.to_json
        socket.send write_ws_message(
          params: {
            conversation_id:,
            recipient_id:,
            message_id: SecureRandom.uuid,
            category: 'PLAIN_CONTACT',
            data_base64: Base64.urlsafe_encode64(data, padding: false)
          }
        )
      end

      def blaze_send_app_card(socket, conversation_id:, recipient_id:, title:, description:, action:, icon_url:)
        data = { title:, description:, action:, icon_url: }.to_json
        socket.send write_ws_message(
          params: {
            conversation_id:,
            recipient_id:,
            message_id: SecureRandom.uuid,
            category: 'APP_CARD',
            data_base64: Base64.urlsafe_encode64(data, padding: false)
          }
        )
      end

      def blaze_send_app_button(socket, conversation_id:, recipient_id:, label:, action:, color:)
        data = [{ label:, action:, color: }].to_json
        socket.send write_ws_message(
          params: {
            conversation_id:,
            recipient_id:,
            message_id: SecureRandom.uuid,
            category: 'APP_BUTTON_GROUP',
            data_base64: Base64.urlsafe_encode64(data, padding: false)
          }
        )
      end

      def blaze_send_group_app_button(socket, conversation_id:, recipient_id:, buttons:)
        data = buttons.to_json
        socket.send write_ws_message(
          params: {
            conversation_id:,
            recipient_id:,
            message_id: SecureRandom.uuid,
            category: 'APP_BUTTON_GROUP',
            data_base64: Base64.urlsafe_encode64(data, padding: false)
          }
        )
      end
    end
  end
end
