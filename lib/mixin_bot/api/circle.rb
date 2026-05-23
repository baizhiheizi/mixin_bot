# frozen_string_literal: true

module MixinBot
  class API
    module Circle
      def circle(circle_id, access_token: nil)
        path = format('/circles/%<circle_id>s', circle_id:)
        client.get path, access_token:
      end
      alias fetch_circle circle

      def circles(access_token: nil)
        client.get '/circles', access_token:
      end
      alias fetch_circles circles

      def circle_conversations(circle_id, **params)
        path = format('/circles/%<circle_id>s/conversations', circle_id:)
        client.get path, **params.compact, access_token: params[:access_token]
      end

      def create_circle(name:, access_token: nil)
        client.post '/circles', name:, access_token:
      end

      def update_circle(circle_id, name:, access_token: nil)
        path = format('/circles/%<circle_id>s', circle_id:)
        client.post path, name:, access_token:
      end

      def delete_circle(circle_id, access_token: nil)
        path = format('/circles/%<circle_id>s/delete', circle_id:)
        client.post path, access_token:
      end

      def add_user_to_circle(user_id:, circle_id:, access_token: nil)
        path = format('/users/%<user_id>s/circles', user_id:)
        client.post path, circle_id:, action: 'ADD', access_token:
      end

      def remove_user_from_circle(user_id:, circle_id:, access_token: nil)
        path = format('/users/%<user_id>s/circles', user_id:)
        client.post path, circle_id:, action: 'REMOVE', access_token:
      end

      def add_conversation_to_circle(conversation_id:, circle_id:, access_token: nil)
        path = format('/conversations/%<conversation_id>s/circles', conversation_id:)
        client.post path, circle_id:, action: 'ADD', access_token:
      end

      def remove_conversation_from_circle(conversation_id:, circle_id:, access_token: nil)
        path = format('/conversations/%<conversation_id>s/circles', conversation_id:)
        client.post path, circle_id:, action: 'REMOVE', access_token:
      end
    end
  end
end
