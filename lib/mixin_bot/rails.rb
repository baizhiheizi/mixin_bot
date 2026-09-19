# frozen_string_literal: true

# Opt-in Rails integration layer: generators, railtie, and Rails glue.
#
# `require 'mixin_bot'` alone never loads any of this — the gem keeps no
# runtime dependency on Rails. Host applications opt in explicitly:
#
#   # Gemfile
#   gem 'mixin_bot'
#   gem 'rails'
#
#   # config/application.rb (after the bundler groups)
#   require 'mixin_bot/rails'
#
# The railtie registers the mixin_bot rake tasks (e.g. `mixin_bot:poller`).
# Rails discovers the `lib/generators/mixin_bot/*` generators on its own.

require 'mixin_bot'

begin
  require 'rails'
rescue LoadError => e
  raise LoadError,
        'mixin_bot/rails requires the rails gem, which is not a runtime ' \
        "dependency of mixin_bot. Add `gem 'rails'` to your Gemfile, or " \
        "drop `require 'mixin_bot/rails'` if you only need the SDK. " \
        "(#{e.message})"
end

require_relative 'blaze/router'
require_relative 'outputs'
require_relative 'transfers'
require_relative 'rails/railtie'
require_relative 'notifications/mixin_channel'
