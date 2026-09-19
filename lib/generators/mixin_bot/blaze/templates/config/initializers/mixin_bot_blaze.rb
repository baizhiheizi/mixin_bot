# frozen_string_literal: true

# Mixin Blaze message routing.
#
# Requires bot credentials in MixinBot.configure (app_id, session_id,
# session_private_key, server_public_key, spend_key) — typically from
# environment variables — and the `mixin_blaze` Puma plugin in
# config/puma.rb to actually receive messages.
#
# Routes dispatch decoded envelopes in registration order (first match
# wins); handlers live under app/mixin/handlers and are re-resolved on
# every code reload in development.

Rails.application.config.to_prepare do
  MixinBot.configure do
    self.blaze_handler = MixinBot::Blaze::Router.new do
      on 'text', Mixin::Handlers::TextHandler
      # on 'transfer', Mixin::Handlers::TransferHandler
      # on category: 'APP_CARD', handler: Mixin::Handlers::AppCardHandler
      # on action: 'CREATE_MESSAGE', handler: ->(message) { ... }
    end
  end
end
