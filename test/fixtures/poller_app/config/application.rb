# frozen_string_literal: true

require 'rails'
require 'mixin_bot/rails'

module MixinBotTest
  class Application < Rails::Application
    config.root = File.expand_path('..', __dir__)
    config.eager_load = false
    config.secret_key_base = 'poller-app-secret-key-base'
  end
end

MixinBotTest::Application.initialize!

# This minimal fixture app has no ActiveRecord models; register the in-memory
# store so the mixin_bot:poller task has a real dedup gate. Generated apps
# register their MixinOutput model automatically via ReceiptModel.
MixinBot::Outputs.receipt_store = MixinBot::Outputs::MemoryReceiptStore.new
