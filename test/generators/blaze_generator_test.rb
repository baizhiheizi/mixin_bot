# frozen_string_literal: true

require 'test_helper'
require_relative '../support/generator_test_helper'
require 'generators/mixin_bot/blaze/blaze_generator'

module MixinBot
  class BlazeGeneratorTest < Rails::Generators::TestCase
    tests MixinBot::Generators::BlazeGenerator
    destination File.expand_path('../tmp/blaze_generator', __dir__)

    setup do
      prepare_destination
      copy_fixture_app
    end

    def test_generator_is_discovered_by_rails_namespace
      assert_equal MixinBot::Generators::BlazeGenerator,
                   Rails::Generators.find_by_namespace('blaze', 'mixin_bot')
    end

    def test_generates_initializer_and_example_handler
      run_generator

      assert_file 'config/initializers/mixin_bot_blaze.rb' do |content|
        assert_match(/MixinBot::Blaze::Router\.new/, content)
        assert_match(/on 'text', Mixin::Handlers::TextHandler/, content)
        assert_match(/blaze_handler/, content)
        assert_match(/to_prepare/, content)
      end

      assert_file 'app/mixin/handlers/text_handler.rb' do |content|
        assert_match(/module Mixin/, content)
        assert_match(/class TextHandler < MixinBot::Blaze::Router::Base/, content)
        assert_match(/def handle/, content)
        assert_match(/reply/, content)
      end
    end

    def test_creates_puma_rb_when_missing
      run_generator

      assert_file 'config/puma.rb' do |content|
        assert_match(/^plugin :mixin_blaze$/, content)
      end
    end

    def test_appends_plugin_line_to_existing_puma_rb
      File.write(File.join(destination_root, 'config', 'puma.rb'), "workers 2\n")

      run_generator

      assert_file 'config/puma.rb' do |content|
        assert_match(/\Aworkers 2\n/, content)
        assert_equal 1, content.scan('plugin :mixin_blaze').size
      end
    end

    def test_does_not_duplicate_existing_plugin_line
      File.write(File.join(destination_root, 'config', 'puma.rb'), "plugin :mixin_blaze\n")

      capture(:stdout) { run_generator }

      assert_file 'config/puma.rb' do |content|
        assert_equal 1, content.scan('plugin :mixin_blaze').size
      end
    end

    def test_rerun_does_not_duplicate_puma_plugin_line
      run_generator
      run_generator

      assert_file 'config/puma.rb' do |content|
        assert_equal 1, content.scan('plugin :mixin_blaze').size
      end
    end

    private

    def copy_fixture_app
      source = File.expand_path('../fixtures/rails_app', __dir__)
      FileUtils.cp_r("#{source}/.", destination_root)
    end
  end
end
