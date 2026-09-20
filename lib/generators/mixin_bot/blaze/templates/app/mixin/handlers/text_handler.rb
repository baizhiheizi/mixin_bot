# frozen_string_literal: true

module Mixin
  module Handlers
    # Example Blaze handler: echoes text messages back to the sender.
    # Handlers are instantiated per message; `message` exposes decoded data,
    # conversation/sender ids, and the `reply` helper (HTTP message API).
    class TextHandler < MixinBot::Blaze::Router::Base
      def handle
        reply("You said: #{message.data}")
      end
    end
  end
end
