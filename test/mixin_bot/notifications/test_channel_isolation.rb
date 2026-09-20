# frozen_string_literal: true

require 'test_helper'
require 'open3'
require 'rbconfig'

module MixinBot
  # The Noticed channel must not load (and must not raise) when Noticed is
  # absent — verified in a clean subprocess where Noticed never gets defined.
  class NotificationsIsolationTest < Minitest::Test
    REPO_ROOT = File.expand_path('../../..', __dir__)

    def test_channel_is_not_defined_without_noticed
      script = <<~RUBY
        require 'mixin_bot/rails'
        if defined?(MixinBot::Notifications::MixinChannel)
          raise 'MixinChannel loaded without Noticed'
        end
        print 'OK'
      RUBY

      stdout, _stderr, status = Open3.capture3(
        { 'BUNDLE_GEMFILE' => File.join(REPO_ROOT, 'Gemfile') },
        RbConfig.ruby, '-I', File.join(REPO_ROOT, 'lib'), '-e', script,
        chdir: REPO_ROOT
      )

      assert status.success?, "expected a clean boot without Noticed, stdout:\n#{stdout}"
      assert_equal 'OK', stdout
    end

    def test_channel_loads_when_noticed_is_available
      script = <<~RUBY
        module Noticed
          class Channel; end
        end
        require 'mixin_bot/rails'
        raise 'MixinChannel not loaded' unless defined?(MixinBot::Notifications::MixinChannel)
        raise 'wrong parent' unless MixinBot::Notifications::MixinChannel < Noticed::Channel
        print 'OK'
      RUBY

      stdout, _stderr, status = Open3.capture3(
        { 'BUNDLE_GEMFILE' => File.join(REPO_ROOT, 'Gemfile') },
        RbConfig.ruby, '-I', File.join(REPO_ROOT, 'lib'), '-e', script,
        chdir: REPO_ROOT
      )

      assert status.success?, "expected the channel to load with Noticed, stdout:\n#{stdout}"
      assert_equal 'OK', stdout
    end
  end
end
