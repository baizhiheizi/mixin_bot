# frozen_string_literal: true

require 'test_helper'
require_relative '../support/generator_test_helper'
require 'generators/mixin_bot/notifications/notifications_generator'

module MixinBot
  class NotificationsGeneratorTest < Rails::Generators::TestCase
    tests MixinBot::Generators::NotificationsGenerator
    destination File.expand_path('../tmp/notifications_generator', __dir__)

    class MixinBot::Generators::NotificationsGenerator
      class << self
        attr_accessor :recorded_bundle_commands
      end
    end

    MixinBot::Generators::NotificationsGenerator.prepend(GeneratorCommandRecorder)

    setup do
      prepare_destination
      copy_fixture_app
    end

    def test_generator_is_discovered_by_rails_namespace
      assert_equal MixinBot::Generators::NotificationsGenerator,
                   Rails::Generators.find_by_namespace('notifications', 'mixin_bot')
    end

    def test_generates_example_notification
      run_generator_with_stubs

      assert_file 'app/notifications/payment_received_notification.rb' do |content|
        assert_match(/deliver_by :mixin/, content)
        assert_match(/def mixin_recipient/, content)
        assert_match(/def mixin_message/, content)
        assert_match(/Noticed::Notification/, content)
      end
    end

    def test_uncomments_commented_noticed_gem
      run_generator_with_stubs

      assert_file 'Gemfile' do |content|
        assert_match(/^gem "noticed"$/, content)
      end
      assert_equal [['install --quiet']], @bundle_commands
    end

    def test_bundle_adds_noticed_when_absent
      File.write(File.join(destination_root, 'Gemfile'),
                 "source \"https://rubygems.org\"\n\ngem \"rails\"\n")

      run_generator_with_stubs

      assert_includes @bundle_commands, ['add noticed --quiet']
    end

    def test_existing_noticed_gem_is_left_alone
      File.write(File.join(destination_root, 'Gemfile'),
                 "source \"https://rubygems.org\"\n\ngem \"rails\"\ngem 'noticed'\n")

      run_generator_with_stubs

      assert_empty @bundle_commands
    end

    def test_rerun_does_not_touch_the_gemfile_twice
      run_generator_with_stubs
      run_generator_with_stubs

      assert_file 'Gemfile' do |content|
        assert_equal 1, content.scan('noticed').size
      end
    end

    private

    def copy_fixture_app
      source = File.expand_path('../fixtures/rails_app', __dir__)
      FileUtils.cp_r("#{source}/.", destination_root)
    end

    def run_generator_with_stubs
      MixinBot::Generators::NotificationsGenerator.recorded_bundle_commands = []

      capture(:stdout) { run_generator }

      @bundle_commands = MixinBot::Generators::NotificationsGenerator.recorded_bundle_commands
    end
  end
end
