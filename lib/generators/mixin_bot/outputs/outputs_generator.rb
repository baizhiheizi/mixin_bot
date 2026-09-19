# frozen_string_literal: true

require 'rails/generators'

module MixinBot
  module Generators
    # `rails generate mixin_bot:outputs` — scaffolds the output-polling
    # foundation: the receipt table and model, and an example processor under
    # app/mixin/processors. Pair with the `mixin_bot:poller` rake task and a
    # job backend (e.g. Solid Queue). The poller's resume cursor is derived
    # from the receipts themselves — there is no separate cursor table.
    class OutputsGenerator < Rails::Generators::Base
      include Rails::Generators::Migration

      source_root File.expand_path('templates', __dir__)

      def self.next_migration_number(dirname)
        current = current_migration_number(dirname)
        return Time.now.utc.strftime('%Y%m%d%H%M%S%6N') if current.zero?

        current.succ.to_s
      end

      def create_migrations
        migration 'create_mixin_outputs'
      end

      def create_model
        template 'app/models/mixin_output.rb'
      end

      def create_example_processor
        template 'app/mixin/processors/deposit_processor.rb'
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
