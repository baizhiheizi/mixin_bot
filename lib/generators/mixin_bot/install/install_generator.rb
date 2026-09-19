# frozen_string_literal: true

require 'rails/generators'

module MixinBot
  module Generators
    # `rails generate mixin_bot:install` — one-command setup: runs every
    # component generator in dependency order. Skip any of them:
    #
    #   rails g mixin_bot:install --skip-notifications --skip-transfers
    #   rails g mixin_bot:install --skip notifications transfers
    #   rails g mixin_bot:install --skip=notifications,transfers
    #
    # Idempotent: each component generator (and this one) is safe to re-run.
    class InstallGenerator < Rails::Generators::Base
      COMPONENTS = %w[authentication blaze outputs transfers notifications].freeze

      class_option :skip,
                   type: :array, default: [],
                   banner: 'component,component2',
                   desc: "Skip components (comma-separated; any of: #{COMPONENTS.join(' ')})"

      COMPONENTS.each do |component|
        class_option :"skip_#{component}", type: :boolean, default: false,
                                           desc: "Skip the #{component} component"

        define_method(:"install_#{component}") do
          invoke "mixin_bot:#{component}" unless skip?(component)
        end
      end

      def show_plan
        skipped = COMPONENTS.select { |component| skip?(component) }
        say_status :install, if skipped.empty?
                               'all components'
                             else
                               "all components except #{skipped.join(', ')}"
                             end
      end

      private

      def skip?(component)
        return true if options[:"skip_#{component}"]

        Array(options[:skip]).flat_map { |value| value.to_s.split(',') }.include?(component.to_s)
      end
    end
  end
end
