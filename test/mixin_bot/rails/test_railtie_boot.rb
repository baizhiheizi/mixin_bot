# frozen_string_literal: true

require 'test_helper'
require 'open3'
require 'rbconfig'

module MixinBot
  # Boots a minimal railties-only application in a subprocess and verifies the
  # railtie registers its rake tasks.
  class RailtieBootTest < Minitest::Test
    REPO_ROOT = File.expand_path('../../..', __dir__)

    def test_dummy_rails_app_boots_with_railtie_and_lists_poller_task
      script = <<~RUBY
        require 'mixin_bot/rails'
        require 'rake'

        module Dummy
          class Application < ::Rails::Application
            config.root = '#{__dir__}'
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
  end
end
