# frozen_string_literal: true

require 'rails/railtie'

module MixinBot
  # Registers the Rails integration's rake tasks and application-code
  # conventions. Lives at lib/mixin_bot/rails/railtie.rb (loaded by
  # `require 'mixin_bot/rails'`), named +MixinBot::Railtie+ — deliberately not
  # +MixinBot::Rails+, which would lexically shadow ::Rails for code written
  # inside module MixinBot.
  #
  # Application conventions:
  # - +app/mixin/handlers+ hosts Blaze message handler classes
  #   (+Mixin::Handlers::*+) and +app/mixin/processors+ hosts output
  #   processor classes (+Mixin::Processors::*+). Rails' default autoload
  #   path inference already picks up every +app/*+ directory as a Zeitwerk
  #   root (namespace +Mixin+), so the railtie does not re-add the paths —
  #   doing so would double-manage the tree. Eager loading is the poller
  #   process's responsibility (it eager-loads before discovering
  #   processors), mirroring how Solid Queue's supervisor boots.
  #
  # Generator discovery needs no registration either: railties scans loaded
  # gems for +lib/generators+ automatically.
  class Railtie < ::Rails::Railtie
    railtie_name 'mixin_bot'

    rake_tasks do
      load File.expand_path('tasks/poller.rake', __dir__)
    end
  end
end
