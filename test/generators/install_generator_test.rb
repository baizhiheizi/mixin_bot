# frozen_string_literal: true

require 'test_helper'
require_relative '../support/generator_test_helper'
require 'generators/mixin_bot/install/install_generator'
require 'generators/mixin_bot/authentication/authentication_generator'
require 'generators/mixin_bot/blaze/blaze_generator'
require 'generators/mixin_bot/outputs/outputs_generator'
require 'generators/mixin_bot/transfers/transfers_generator'
require 'generators/mixin_bot/notifications/notifications_generator'

module MixinBot
  class InstallGeneratorTest < Rails::Generators::TestCase
    tests MixinBot::Generators::InstallGenerator
    destination File.expand_path('../tmp/install_generator', __dir__)

    # install composes the other generators, so the shell-out recorder must
    # cover each of them. Module#prepend is idempotent, so the authentication
    # generator's own test prepend is unaffected.
    COMPOSED_GENERATORS = [
      MixinBot::Generators::InstallGenerator,
      MixinBot::Generators::AuthenticationGenerator,
      MixinBot::Generators::BlazeGenerator,
      MixinBot::Generators::OutputsGenerator,
      MixinBot::Generators::TransfersGenerator,
      MixinBot::Generators::NotificationsGenerator
    ].freeze

    COMPOSED_GENERATORS.each do |generator|
      generator.singleton_class.attr_accessor :recorded_bundle_commands, :recorded_rails_commands
      generator.prepend(GeneratorCommandRecorder)
    end

    setup do
      prepare_destination
      copy_fixture_app
    end

    def test_full_install_runs_every_component_generator
      run_generator_with_stubs

      assert_file 'app/controllers/sessions_controller.rb'        # authentication
      assert_file 'config/initializers/mixin_bot_blaze.rb'        # blaze
      assert_file 'app/mixin/handlers/text_handler.rb'
      assert_migration 'db/migrate/create_mixin_outputs.rb'       # outputs
      assert_file 'app/mixin/processors/deposit_processor.rb'
      assert_migration 'db/migrate/create_mixin_transfers.rb'     # transfers
      assert_file 'app/models/mixin_transfer.rb'
      assert_file 'app/notifications/payment_received_notification.rb' # notifications
    end

    def test_skip_flags_drop_components
      run_generator_with_stubs ['--skip-notifications', '--skip-transfers']

      assert_file 'app/controllers/sessions_controller.rb'
      assert_file 'config/initializers/mixin_bot_blaze.rb'
      assert_migration 'db/migrate/create_mixin_outputs.rb'
      assert_no_file 'app/notifications/payment_received_notification.rb'
      assert_no_migration 'db/migrate/create_mixin_transfers.rb'
    end

    def test_comma_separated_skip_values
      run_generator_with_stubs ['--skip', 'notifications,transfers']

      assert_no_file 'app/notifications/payment_received_notification.rb'
      assert_no_migration 'db/migrate/create_mixin_transfers.rb'
      assert_file 'app/controllers/sessions_controller.rb'
    end

    def test_double_install_does_not_duplicate
      run_generator_with_stubs
      run_generator_with_stubs

      assert_file 'config/puma.rb' do |content|
        assert_equal 1, content.scan('plugin :mixin_blaze').size
      end
      assert_file 'Gemfile' do |content|
        assert_equal 1, content.scan('noticed').size
      end
      migrations = Dir[File.join(destination_root, 'db', 'migrate', '*')]
      # auth migrations are requested via `rails_command` (recorded, not run);
      # outputs adds one, transfers one.
      assert_equal 2, migrations.size
    end

    private

    def copy_fixture_app
      source = File.expand_path('../fixtures/rails_app', __dir__)
      FileUtils.cp_r("#{source}/.", destination_root)
    end

    def run_generator_with_stubs(args = [])
      COMPOSED_GENERATORS.each do |generator|
        generator.recorded_bundle_commands = []
        generator.recorded_rails_commands = []
      end

      capture(:stdout) { run_generator args }
    end
  end
end
