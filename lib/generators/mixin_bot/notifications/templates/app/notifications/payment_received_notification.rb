# frozen_string_literal: true

# Example notification delivered as a Mixin message through the mixin channel:
#
#   PaymentReceivedNotification.with(amount: '1.5').deliver(user)
#
# (`user` must answer #mixin_user_id — the mixin_bot:authentication
# generator's users table has that column.)
#
# The recipient and message contract lives here; MixinBot's channel sends
# over the HTTP message API with the configured bot's credentials.
class PaymentReceivedNotification < Noticed::Notification
  deliver_by :mixin

  param :amount

  def mixin_recipient
    recipient.mixin_user_id
  end

  def mixin_message
    { category: 'PLAIN_TEXT', content: "Payment received: #{params[:amount]}" }
  end
end
