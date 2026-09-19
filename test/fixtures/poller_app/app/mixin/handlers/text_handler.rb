# frozen_string_literal: true

module Mixin
  module Handlers
    class TextHandler < MixinBot::Blaze::Router::Base
      def handle
        reply("You said: #{message.data}")
      end
    end
  end
end
