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
  #   processor classes (+Mixin::Processors::*+). Rails' default path
  #   inference would make +app/mixin+ itself a Zeitwerk root (mapping files
  #   to +Handlers::*+ / +Processors::*+, not +Mixin::Handlers::*+), so the
  #   railtie excludes it from the defaults and re-registers it with the
  #   +Mixin+ namespace explicitly. Eager loading is the poller process's
  #   responsibility (it eager-loads before discovering processors),
  #   mirroring how Solid Queue's supervisor boots.
  #
  # Generator discovery needs no registration either: railties scans loaded
  # gems for +lib/generators+ automatically.
  class Railtie < ::Rails::Railtie
    railtie_name 'mixin_bot'

    initializer 'mixin_bot.exclude_default_mixin_root', before: :set_autoload_paths do |app|
      app.config.paths.add 'app/mixin', autoload: false, eager_load: false
    end

    initializer 'mixin_bot.push_mixin_root', after: :set_autoload_paths, before: :setup_main_autoloader do |app|
      mixin_root = app.root.join('app/mixin')
      next unless mixin_root.directory?

      Object.const_set(:Mixin, Module.new) unless Object.const_defined?(:Mixin)
      app.autoloaders.main.push_dir(mixin_root, namespace: Mixin)
    end

    rake_tasks do
      load File.expand_path('tasks/poller.rake', __dir__)
    end
  end
end
