# frozen_string_literal: true

require 'test_helper'
require_relative '../support/generator_test_helper'
require 'generators/mixin_bot/transfers/transfers_generator'

module MixinBot
  class TransfersGeneratorTest < Rails::Generators::TestCase
    tests MixinBot::Generators::TransfersGenerator
    destination File.expand_path('../tmp/transfers_generator', __dir__)

    setup do
      prepare_destination
      copy_fixture_app
    end

    def test_generator_is_discovered_by_rails_namespace
      assert_equal MixinBot::Generators::TransfersGenerator,
                   Rails::Generators.find_by_namespace('transfers', 'mixin_bot')
    end

    def test_generates_the_ledger_migration
      run_generator

      assert_migration 'db/migrate/create_mixin_transfers.rb' do |content|
        assert_match(/create_table :mixin_transfers/, content)
        assert_match(/t\.string :trace_id, null: false/, content)
        assert_match(/t\.string :state, null: false, default: 'pending'/, content)
        assert_match(/unique: true/, content)
      end
    end

    def test_generates_model_with_runtime_concern_and_enqueue_hook
      run_generator

      assert_file 'app/models/mixin_transfer.rb' do |content|
        assert_match(/include MixinBot::Transfers::Model/, content)
        assert_match(/MixinTransfers::PerformJob\.perform_later\(id\)/, content)
      end
    end

    def test_generates_perform_and_reconcile_jobs
      run_generator

      assert_file 'app/jobs/mixin_transfers/perform_job.rb' do |content|
        assert_match(/class PerformJob < ApplicationJob/, content)
        assert_match(/MixinTransfer\.find\(transfer_id\)\.perform!/, content)
      end
      assert_file 'app/jobs/mixin_transfers/reconcile_job.rb' do |content|
        assert_match(/MixinTransfer\.reconcile_pending!/, content)
      end
    end

    def test_creates_recurring_schedule_when_missing
      run_generator

      assert_file 'config/recurring.yml' do |content|
        assert_match(/mixin_transfers_reconcile:/, content)
        assert_match(/class: MixinTransfers::ReconcileJob/, content)
        assert_match(/schedule: every 5 minutes/, content)
      end
    end

    def test_existing_recurring_schedule_is_left_untouched
      File.write(File.join(destination_root, 'config', 'recurring.yml'), "production:\n  other_job:\n")

      capture(:stdout) { run_generator }

      assert_file 'config/recurring.yml' do |content|
        assert_match(/other_job/, content)
        assert_no_match(/mixin_transfers_reconcile/, content)
      end
    end

    def test_rerun_does_not_duplicate_migrations
      run_generator
      run_generator

      migrations = Dir[File.join(destination_root, 'db', 'migrate', '*')]
      assert_equal 1, migrations.size
    end

    private

    def copy_fixture_app
      source = File.expand_path('../fixtures/rails_app', __dir__)
      FileUtils.cp_r("#{source}/.", destination_root)
    end
  end
end
