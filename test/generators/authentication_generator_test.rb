# frozen_string_literal: true

require 'test_helper'
require_relative '../support/generator_test_helper'

class MixinBotAuthenticationGeneratorTest < Rails::Generators::TestCase
  tests MixinBot::Generators::AuthenticationGenerator
  destination File.expand_path('../tmp/authentication_generator', __dir__)

  class MixinBot::Generators::AuthenticationGenerator
    class << self
      attr_accessor :recorded_bundle_commands, :recorded_rails_commands
    end
  end

  MixinBot::Generators::AuthenticationGenerator.prepend(GeneratorCommandRecorder)

  GENERATED_FILES = %w[
    config/initializers/omniauth.rb
    app/models/user.rb
    app/models/session.rb
    app/models/current.rb
    app/controllers/sessions_controller.rb
    app/controllers/concerns/authentication.rb
    app/views/sessions/new.html.erb
  ].freeze

  setup do
    prepare_destination
    copy_fixture_app
  end

  def test_generator_is_discovered_by_rails_namespace
    assert_equal MixinBot::Generators::AuthenticationGenerator,
                 Rails::Generators.find_by_namespace('authentication', 'mixin_bot')
  end

  def test_generates_complete_file_set
    run_generator_with_stubs

    GENERATED_FILES.each { |path| assert_file path }
  end

  def test_application_controller_includes_authentication
    run_generator_with_stubs

    assert_file 'app/controllers/application_controller.rb' do |content|
      assert_includes content, "class ApplicationController < ActionController::Base\n"
      assert_includes content, "  include Authentication\n"
    end
  end

  def test_routes_are_added
    run_generator_with_stubs

    assert_file 'config/routes.rb' do |content|
      assert_match(/resource :session, only: \[:new, :destroy\]/, content)
      assert_match(%r{get '/auth/mixin/callback', to: 'sessions#create'}, content)
    end
  end

  def test_migration_commands_are_requested
    run_generator_with_stubs

    assert_includes @rails_commands,
                    ['generate migration CreateUsers mixin_user_id:string!:uniq name:string avatar_url:string --force',
                     { abort_on_failure: true }]
    assert_includes @rails_commands,
                    ['generate migration CreateSessions user:references ip_address:string user_agent:string --force',
                     { abort_on_failure: true }]
  end

  def test_initializer_reads_env_credentials_and_fails_loud
    run_generator_with_stubs

    assert_file 'config/initializers/omniauth.rb' do |content|
      assert_match(/provider :mixin/, content)
      assert_match('MIXIN_CLIENT_ID', content)
      assert_match('MIXIN_CLIENT_SECRET', content)
      assert_match('setup:', content)
      assert_match(/raise ArgumentError/, content)
    end
  end

  def test_generated_models_store_identity_only
    run_generator_with_stubs

    assert_file 'app/models/user.rb' do |content|
      assert_match(/find_or_create_by!\(mixin_user_id: auth\.uid\)/, content)
      assert_match(/auth\.info\.name/, content)
      assert_match(/auth\.info\.image/, content)
      assert_no_match(/token/i, content)
    end
  end

  def test_controller_consumes_omniauth_auth_hash
    run_generator_with_stubs

    assert_file 'app/controllers/sessions_controller.rb' do |content|
      assert_match(/request\.env\["omniauth\.auth"\]/, content)
      assert_match(/User\.find_or_create_by_mixin_auth!/, content)
      assert_match(/start_new_session_for/, content)
      assert_match(/allow_unauthenticated_access only: %i\[new create\]/, content)
    end
  end

  def test_view_signs_in_via_post_button
    run_generator_with_stubs

    assert_file 'app/views/sessions/new.html.erb' do |content|
      assert_match(%r{button_to "Sign in with Mixin", "/auth/mixin"}, content)
    end
  end

  def test_generated_code_does_not_reference_mixin_bot
    run_generator_with_stubs

    GENERATED_FILES.each do |path|
      assert_file path do |content|
        assert_no_match(/mixin_bot|MixinBot/, content, "#{path} must not reference mixin_bot")
      end
    end
  end

  def test_commented_gemfile_entries_are_uncommented_without_bundling
    run_generator_with_stubs

    assert_file 'Gemfile' do |content|
      assert_match(/^gem "omniauth-mixin"$/, content)
      assert_match(/^gem "omniauth-rails_csrf_protection"$/, content)
      assert_no_match(/#\s*gem "omniauth-mixin"/, content)
      assert_no_match(/#\s*gem "omniauth-rails_csrf_protection"/, content)
    end
    assert_equal [['install --quiet']], @bundle_commands,
                 'uncommenting existing entries must refresh the bundle without adding gems'
  end

  def test_absent_gemfile_entries_are_bundle_added
    File.write(File.join(destination_root, 'Gemfile'), "source \"https://rubygems.org\"\n\ngem \"rails\"\n")

    run_generator_with_stubs

    assert_includes @bundle_commands, ['add omniauth-mixin --quiet']
    assert_includes @bundle_commands, ['add omniauth-rails_csrf_protection --quiet']
  end

  def test_bundle_command_call_shape_is_accepted_by_real_helper
    skip 'BundleHelper not present in this railties' unless defined?(Rails::Generators::BundleHelper)

    helper = Class.new do
      def say_status(*); end
    end.new.extend(Rails::Generators::BundleHelper)
    received = nil
    helper.define_singleton_method(:exec_bundle_command) do |*args|
      received = args
      true
    end

    helper.bundle_command('add omniauth-mixin --quiet')

    # exec_bundle_command receives (bundle_exe_path, command, env, params)
    assert_equal ['add omniauth-mixin --quiet', {}, {}], received.drop(1)
  end

  def test_rerun_does_not_duplicate_routes_or_gemfile_entries
    run_generator_with_stubs
    run_generator_with_stubs

    assert_file 'config/routes.rb' do |content|
      assert_equal 1, content.scan('resource :session').size
      assert_equal 1, content.scan('/auth/mixin/callback').size
    end
    assert_file 'Gemfile' do |content|
      assert_equal 1, content.scan('omniauth-mixin').size
      assert_equal 1, content.scan('omniauth-rails_csrf_protection').size
    end
  end

  private

  def copy_fixture_app
    source = File.expand_path('../fixtures/rails_app', __dir__)
    FileUtils.cp_r("#{source}/.", destination_root)
  end

  def run_generator_with_stubs
    MixinBot::Generators::AuthenticationGenerator.recorded_bundle_commands = []
    MixinBot::Generators::AuthenticationGenerator.recorded_rails_commands = []

    capture(:stdout) { run_generator }

    @bundle_commands = MixinBot::Generators::AuthenticationGenerator.recorded_bundle_commands
    @rails_commands = MixinBot::Generators::AuthenticationGenerator.recorded_rails_commands
  end
end
