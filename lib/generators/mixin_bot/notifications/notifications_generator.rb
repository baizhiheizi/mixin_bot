# frozen_string_literal: true

require 'rails/generators'

module MixinBot
  module Generators
    # `rails generate mixin_bot:notifications` — adds the Noticed gem and
    # scaffolds one example notification delivered as a Mixin message through
    # the gem's MixinChannel (`deliver_by :mixin`).
    class NotificationsGenerator < Rails::Generators::Base
      # Rails 8.1 moved bundle_command out of Actions into BundleHelper.
      unless method_defined?(:bundle_command) || private_method_defined?(:bundle_command)
        begin
          require 'rails/generators/bundle_helper'
          include Rails::Generators::BundleHelper
        rescue LoadError
          # Older Rails ships bundle_command in Rails::Generators::Actions.
        end
      end

      source_root File.expand_path('templates', __dir__)

      NOTICED_GEM = 'noticed'

      def add_noticed_gem
        gemfile = File.read(gemfile_path)
        pattern = /gem\s+["']#{NOTICED_GEM}["']/
        return if gemfile.match?(/^\s*#{pattern}/)

        if gemfile.match?(/^\s*#\s*#{pattern}/)
          uncomment_lines 'Gemfile', pattern
          bundle_command('install --quiet')
        else
          bundle_command("add #{NOTICED_GEM} --quiet")
        end
      end

      def create_example_notification
        template 'app/notifications/payment_received_notification.rb'
      end

      private

      def gemfile_path
        File.expand_path('Gemfile', destination_root)
      end
    end
  end
end
