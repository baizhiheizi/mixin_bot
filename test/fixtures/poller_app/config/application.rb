# frozen_string_literal: true

require 'rails'
require 'mixin_bot/rails'

module MixinBotTest
  class Application < Rails::Application
    config.root = __dir__
    config.eager_load = false
    config.secret_key_base = 'poller-app-secret-key-base'
  end
end

MixinBotTest::Application.initialize!
