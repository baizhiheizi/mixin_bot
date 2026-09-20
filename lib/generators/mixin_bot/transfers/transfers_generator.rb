# frozen_string_literal: true

require 'rails/generators'

module MixinBot
  module Generators
    # `rails generate mixin_bot:transfers` — scaffolds the outbound transfer
    # ledger: migration + model (state machine concern), perform/reconcile
    # jobs, and a Solid Queue recurring entry for reconciliation.
    class TransfersGenerator < Rails::Generators::Base
      include Rails::Generators::Migration

      source_root File.expand_path('templates', __dir__)

      RECURRING_ENTRY = <<~YAML
        production:
          mixin_transfers_reconcile:
            class: MixinTransfers::ReconcileJob
            schedule: every 5 minutes
      YAML

      def self.next_migration_number(dirname)
        current = current_migration_number(dirname)
        return Time.now.utc.strftime('%Y%m%d%H%M%S%6N') if current.zero?

        current.succ.to_s
      end

      def create_ledger_migration
        migration 'create_mixin_transfers'
      end

      def create_model
        template 'app/models/mixin_transfer.rb'
      end

      def create_jobs
        template 'app/jobs/mixin_transfers/perform_job.rb'
        template 'app/jobs/mixin_transfers/reconcile_job.rb'
      end

      def create_recurring_schedule
        path = File.expand_path('config/recurring.yml', destination_root)
        if File.exist?(path)
          say_status :todo, <<~MSG.chomp
            add the MixinTransfers reconcile entry to config/recurring.yml (see USAGE)
          MSG
        else
          create_file 'config/recurring.yml', RECURRING_ENTRY
        end
      end

      private

      # Skips the migration when a same-named one already exists (re-run).
      def migration(name)
        return if self.class.migration_exists?('db/migrate', name)

        migration_template "db/migrate/#{name}.rb.tt", "db/migrate/#{name}.rb"
      end

      def migration_version
        "[#{Rails::VERSION::MAJOR}.#{Rails::VERSION::MINOR}]"
      end
    end
  end
end
