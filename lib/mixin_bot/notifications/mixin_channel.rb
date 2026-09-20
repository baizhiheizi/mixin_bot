# frozen_string_literal: true

# Loads only when the Noticed gem is already loaded (it is in every app that
# declares `deliver_by :mixin`); requiring the integration layer without
# Noticed neither raises nor loads this file's contents.
return unless defined?(Noticed::Channel)

module MixinBot
  module Notifications
    ##
    # Noticed delivery channel that sends the notification as a Mixin message
    # over the HTTP message API.
    #
    # Notification-class contract (all resolution lives in the notification,
    # so the channel stays a thin adapter over Noticed's surface):
    #
    #   class PaymentReceivedNotification < Noticed::Notification
    #     deliver_by :mixin                      # or: deliver_by :mixin, bot: :shop
    #
    #     def mixin_recipient                    # Mixin user id to deliver to
    #       recipient.mixin_user_id
    #     end
    #
    #     def mixin_message
    #       { category: 'PLAIN_TEXT', content: "received #{params[:amount]}" }
    #     end
    #   end
    #
    # mixin_message supports {category: 'PLAIN_TEXT'|'PLAIN_POST', content:}
    # and {category: 'APP_CARD', card: {title:, description:, action:, ...}}.
    # When the notification class does not define #mixin_recipient, the
    # channel falls back to the recipient record's #mixin_user_id.
    #
    # Delivery failures raise out of #deliver — Noticed captures them per
    # delivery without aborting sibling channels.
    #
    class MixinChannel < ::Noticed::Channel
      def deliver
        api.send_message(payload)
      end

      private

      def api
        @api ||=
          if params[:bot]
            MixinBot.bot(params[:bot])
          else
            MixinBot.api
          end
      end

      def payload
        message = notification.try(:mixin_message) ||
                  raise(MixinBot::ArgumentError,
                        "#{notification.class} must define #mixin_message for the mixin channel")

        options = { recipient_id: recipient_id, data: message[:content] }
        case message[:category]
        when 'PLAIN_POST' then api.plain_post(options)
        when 'APP_CARD' then api.app_card(options.merge(data: message[:card]))
        else api.plain_text(options)
        end
      end

      def recipient_id
        id =
          if notification.respond_to?(:mixin_recipient)
            notification.mixin_recipient
          elsif recipient.respond_to?(:mixin_user_id)
            recipient.mixin_user_id
          end

        raise MixinBot::ArgumentError, 'could not resolve a Mixin recipient id' if id.blank?

        id
      end
    end
  end
end
