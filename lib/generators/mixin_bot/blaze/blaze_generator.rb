# frozen_string_literal: true

require 'rails/generators'

module MixinBot
  module Generators
    # `rails generate mixin_bot:blaze` — scaffolds Mixin Blaze message
    # routing: a routes initializer wired to `config.blaze_handler`, an
    # example text handler under `app/mixin/handlers`, and the `mixin_blaze`
    # Puma plugin line in `config/puma.rb` so the app receives messages in
    # its own process tree.
    class BlazeGenerator < Rails::Generators::Base
      source_root File.expand_path('templates', __dir__)

      PUMA_PLUGIN_LINE = 'plugin :mixin_blaze'
      PUMA_COMMENT = '# Receive Mixin Blaze messages in the web process tree (MixinBot).'

      def create_routes_initializer
        template 'config/initializers/mixin_bot_blaze.rb'
      end

      def create_example_handler
        template 'app/mixin/handlers/text_handler.rb'
      end

      def configure_puma_plugin
        if File.exist?(puma_path)
          return if File.read(puma_path).match?(/^\s*plugin\s+:mixin_blaze\b/)

          append_to_file 'config/puma.rb', "\n#{PUMA_COMMENT}\n#{PUMA_PLUGIN_LINE}\n"
        else
          create_file 'config/puma.rb', "#{PUMA_COMMENT}\n#{PUMA_PLUGIN_LINE}\n"
        end
      end

      private

      def puma_path
        File.expand_path('config/puma.rb', destination_root)
      end
    end
  end
end
