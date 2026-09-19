# frozen_string_literal: true

module MixinBot
  module Generators
    # Generator namespace discovered by railties: every bundler-managed gem's
    # `lib/generators` directory is on the generator load path, so apps can run
    # `rails generate mixin_bot:<name>` without any configuration. Individual
    # generators live in sibling directories (e.g. mixin_bot/authentication).
  end
end
