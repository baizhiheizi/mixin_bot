# frozen_string_literal: true

require 'test_helper'
require 'open3'
require 'rbconfig'

module MixinBot
  # Boots a minimal railties application in a subprocess and verifies the
  # railtie registers its rake tasks and the Mixin namespace convention:
  # app/mixin/** files must define Mixin::Handlers::* / Mixin::Processors::*
  # (the railtie excludes Rails' default app/* root for app/mixin and
  # re-registers it with the Mixin namespace).
  class RailtieBootTest < Minitest::Test
    APP_ROOT = File.expand_path('../../fixtures/poller_app', __dir__)
    REPO_ROOT = File.expand_path('../../..', __dir__)

    def test_dummy_rails_app_boots_with_railtie_and_lists_poller_task
      script = <<~RUBY
        require 'mixin_bot/rails'
        require 'rake'

        module Dummy
          class Application < ::Rails::Application
            config.root = '#{APP_ROOT}'
            config.eager_load = false
            config.secret_key_base = 'boot-test-secret-key-base'
          end
        end

        Dummy::Application.initialize!
        Dummy::Application.load_tasks

        raise 'mixin_bot:poller task not registered' unless Rake::Task.task_defined?('mixin_bot:poller')
        raise 'environment prerequisite missing' unless Rake::Task['mixin_bot:poller'].prerequisites.include?('environment')
        print 'OK'
      RUBY

      stdout, _stderr, status = Open3.capture3(
        { 'BUNDLE_GEMFILE' => File.join(REPO_ROOT, 'Gemfile') },
        RbConfig.ruby, '-I', File.join(REPO_ROOT, 'lib'), '-e', script,
        chdir: REPO_ROOT
      )

      assert status.success?, "expected the dummy app to boot with the railtie, stdout:\n#{stdout}"
      assert_equal 'OK', stdout
    end

    def test_mixin_namespace_convention_eager_loads_handlers_and_processors
      script = <<~RUBY
        require 'mixin_bot/rails'

        module Dummy
          class Application < ::Rails::Application
            config.root = '#{APP_ROOT}'
            config.eager_load = true
            config.secret_key_base = 'boot-test-secret-key-base'
          end
        end

        Dummy::Application.initialize!

        raise 'Mixin::Handlers::TextHandler not eager-loaded' unless defined?(Mixin::Handlers::TextHandler)
        raise 'Mixin::Processors::DepositProcessor not eager-loaded' unless defined?(Mixin::Processors::DepositProcessor)
        raise 'wrong handler base' unless Mixin::Handlers::TextHandler < MixinBot::Blaze::Router::Base
        raise 'wrong processor base' unless Mixin::Processors::DepositProcessor < MixinBot::Outputs::Processor
        print 'OK'
      RUBY

      stdout, _stderr, status = Open3.capture3(
        { 'BUNDLE_GEMFILE' => File.join(REPO_ROOT, 'Gemfile') },
        RbConfig.ruby, '-I', File.join(REPO_ROOT, 'lib'), '-e', script,
        chdir: REPO_ROOT
      )

      assert status.success?, "expected Mixin::* convention classes to eager-load, stdout:\n#{stdout}"
      assert_equal 'OK', stdout
    end
  end
end
