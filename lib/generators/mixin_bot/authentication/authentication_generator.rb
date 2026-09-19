# frozen_string_literal: true

require 'rails/generators'

module MixinBot
  module Generators
    # `rails generate mixin_bot:authentication` — sets up "Sign in with Mixin"
    # via OmniAuth, modeled on Rails' built-in `authentication` generator.
    # Identity only: the OAuth tokens are used to establish identity and are
    # not persisted.
    class AuthenticationGenerator < Rails::Generators::Base
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

      SESSION_ROUTE = 'resource :session, only: [:new, :destroy]'
      CALLBACK_ROUTE = "get '/auth/mixin/callback', to: 'sessions#create'"
      OMNIAUTH_GEMS = %w[omniauth-mixin omniauth-rails_csrf_protection].freeze

      def create_authentication_files
        template 'config/initializers/omniauth.rb'
        template 'app/models/user.rb'
        template 'app/models/session.rb'
        template 'app/models/current.rb'
        template 'app/controllers/sessions_controller.rb'
        template 'app/controllers/concerns/authentication.rb'
        template 'app/views/sessions/new.html.erb'
      end

      def configure_application_controller
        inject_into_class 'app/controllers/application_controller.rb', 'ApplicationController', "  include Authentication\n"
      end

      def configure_authentication_routes
        route SESSION_ROUTE
        route CALLBACK_ROUTE
      end

      def add_migrations
        generate 'migration', 'CreateUsers', 'mixin_user_id:string!:uniq name:string avatar_url:string', '--force'
        generate 'migration', 'CreateSessions', 'user:references ip_address:string user_agent:string', '--force'
      end

      def add_omniauth_gems
        gemfile = File.read(gemfile_path)
        uncommented = []

        OMNIAUTH_GEMS.each do |name|
          pattern = /gem\s+["']#{Regexp.escape(name)}["']/
          next if gemfile.match?(/^\s*#{pattern}/) # already present

          if gemfile.match?(/^\s*#\s*#{pattern}/)
            uncomment_lines 'Gemfile', pattern
            uncommented << name
          else
            bundle_command("add #{name}", {}, quiet: true)
          end
        end

        bundle_command('install --quiet') unless uncommented.empty?
      end

      private

      def gemfile_path
        File.expand_path('Gemfile', destination_root)
      end
    end
  end
end
