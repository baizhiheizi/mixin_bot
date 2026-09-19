# frozen_string_literal: true

require 'test_helper'
require_relative '../support/generator_test_helper'
require 'generators/mixin_bot/outputs/outputs_generator'

module MixinBot
  class OutputsGeneratorTest < Rails::Generators::TestCase
    tests MixinBot::Generators::OutputsGenerator
    destination File.expand_path('../tmp/outputs_generator', __dir__)

    setup do
      prepare_destination
      copy_fixture_app
    end

    def test_generator_is_discovered_by_rails_namespace
      assert_equal MixinBot::Generators::OutputsGenerator,
                   Rails::Generators.find_by_namespace('outputs', 'mixin_bot')
    end

    def test_generates_receipt_and_cursor_migrations
      run_generator

      assert_migration 'db/migrate/create_mixin_outputs.rb' do |content|
        assert_match(/create_table :mixin_outputs/, content)
        assert_match(/t\.string :bot_app_id, null: false/, content)
        assert_match(/t\.string :output_id, null: false/, content)
        assert_match(/t\.text :memo/, content)
        assert_match(/t\.datetime :enqueued_at/, content)
        assert_match(/unique: true/, content)
      end

      assert_migration 'db/migrate/create_mixin_poller_cursors.rb' do |content|
        assert_match(/create_table :mixin_poller_cursors/, content)
        assert_match(/t\.string :bot_app_id, null: false/, content)
      end
    end

    def test_generates_models_including_runtime_concerns
      run_generator

      assert_file 'app/models/mixin_output.rb' do |content|
        assert_match(/include MixinBot::Outputs::ReceiptModel/, content)
      end
      assert_file 'app/models/mixin_poller_cursor.rb' do |content|
        assert_match(/include MixinBot::Outputs::CursorModel/, content)
      end
    end

    def test_generates_example_processor
      run_generator

      assert_file 'app/mixin/processors/deposit_processor.rb' do |content|
        assert_match(/module Mixin/, content)
        assert_match(/class DepositProcessor < MixinBot::Outputs::Processor/, content)
        assert_match(/def self\.matches\?/, content)
        assert_match(/def process/, content)
      end
    end

    def test_rerun_does_not_duplicate_migrations
      run_generator
      run_generator

      migrations = Dir[File.join(destination_root, 'db', 'migrate', '*')]
      assert_equal 2, migrations.size
    end

    private

    def copy_fixture_app
      source = File.expand_path('../fixtures/rails_app', __dir__)
      FileUtils.cp_r("#{source}/.", destination_root)
    end
  end
end
