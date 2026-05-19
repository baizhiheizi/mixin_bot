# frozen_string_literal: true

module MixinBot
  class API
    module Conversation
      def conversation(conversation_id, access_token: nil)
        path = format('/conversations/%<conversation_id>s', conversation_id:)
        client.get path, access_token:
      end

      def conversation_by_user_id(user_id)
        conversation_id = unique_uuid user_id
        conversation conversation_id
      end

      def create_conversation(**kwargs)
        path = '/conversations'
        payload = {
          announcement: kwargs[:announcement],
          category: kwargs[:category],
          conversation_id: kwargs[:conversation_id],
          name: kwargs[:name],
          participants: kwargs[:participants],
          random_id: kwargs[:random_id]
        }.compact_blank

        client.post path, **payload, access_token: kwargs[:access_token]
      end

      def create_group_conversation(user_ids:, name:, **kwargs)
        random_id = kwargs[:random_id] || SecureRandom.uuid
        conversation_id = kwargs[:conversation_id] || MixinBot.utils.generate_group_conversation_id(user_ids:, name:,
                                                                                                    owner_id: config.app_id, random_id:)
        create_conversation(
          announcement: kwargs[:announcement],
          category: 'GROUP',
          conversation_id:,
          name:,
          participants: user_ids.map(&->(participant) { { user_id: participant } }),
          random_id:,
          access_token: kwargs[:access_token]
        )
      end

      def create_contact_conversation(user_id, access_token: nil)
        create_conversation(
          category: 'CONTACT',
          conversation_id: unique_uuid(user_id),
          participants: [
            {
              user_id:
            }
          ],
          access_token:
        )
      end

      def update_group_conversation_name(name:, conversation_id:, access_token: nil)
        path = format('/conversations/%<id>s', id: conversation_id)
        payload = {
          name:
        }

        client.post path, **payload, access_token:
      end

      def update_group_conversation_announcement(announcement:, conversation_id:, access_token: nil)
        path = format('/conversations/%<id>s', id: conversation_id)
        payload = {
          announcement:
        }

        client.post path, **payload, access_token:
      end

      # participants = [{ user_id: "" }]
      def add_conversation_participants(conversation_id:, user_ids:, access_token: nil)
        path = format('/conversations/%<id>s/participants/ADD', id: conversation_id)
        payload = user_ids.map(&->(participant) { { user_id: participant } })

        client.post path, *payload, access_token:
      end

      # participants = [{ user_id: "" }]
      def remove_conversation_participants(conversation_id:, user_ids:, access_token: nil)
        path = format('/conversations/%<id>s/participants/REMOVE', id: conversation_id)
        payload = user_ids.map(&->(participant) { { user_id: participant } })

        client.post path, *payload, access_token:
      end

      def exit_conversation(conversation_id, access_token: nil)
        path = format('/conversations/%<id>s/exit', id: conversation_id)

        client.post path, access_token:
      end

      def join_conversation(conversation_id, access_token: nil)
        path = format('/conversations/%<conversation_id>s/join', conversation_id:)
        client.post path, access_token:
      end

      def rotate_conversation(conversation_id, access_token: nil)
        path = format('/conversations/%<id>s/rotate', id: conversation_id)

        client.post path, access_token:
      end

      # participants = [{ user_id: "", role: "ADMIN" }]
      def update_conversation_participants_role(conversation_id:, participants:, access_token: nil)
        path = format('/conversations/%<id>s/participants/ROLE', id: conversation_id)
        payload = participants

        client.post path, *payload, access_token:
      end

      def unique_uuid(user_id, opponent_id = nil)
        opponent_id ||= config.app_id
        MixinBot.utils.unique_uuid user_id, opponent_id
      end
      alias unique_conversation_id unique_uuid
    end
  end
end
