# frozen_string_literal: true

require 'test_helper'
require 'minitest/stub_const'
require 'puma'
require 'puma/configuration'
require 'puma/log_writer'
require 'puma/plugin/mixin_blaze'

module MixinBot
  module Blaze
    # Local reactor double: blocks until stopped, no network.
    class IntegrationHangingReactor
      def initialize(*)
        @stop_called = false
      end

      def run
        sleep 0.05 until @stop_called
      end

      def stop
        @stop_called = true
      end
    end

    # Boots a real Puma launcher (single mode, stub rack app, stubbed
    # reactor) and exercises the full plugin wiring: fire_starts ->
    # after_booted fork -> after_stopped reap. The launcher runs on the
    # main thread because Puma installs signal traps there; a watchdog
    # thread pulls the shutdown trigger once the child is up.
    class TestPumaPluginIntegration < Minitest::Test
      def test_fork_mode_child_lives_and_dies_with_the_launcher
        previous_handler = MixinBot.config.blaze_handler
        MixinBot.configure { self.blaze_handler = ->(_envelope) { _envelope } }

        MixinBot::Blaze.stub_const(:Reactor, IntegrationHangingReactor) do
          config = Puma::Configuration.new do |user_dsl|
            user_dsl.plugin :mixin_blaze
            user_dsl.port 0
            user_dsl.app { |_env| [200, {}, ['ok']] }
            user_dsl.mixin_blaze_mode :fork
          end

          launcher = Puma::Launcher.new(config, log_writer: Puma::LogWriter.strings, argv: [])

          watchdog = Thread.new do
            plugin = wait_for_plugin(config)
            pid = wait_for_fork(plugin)
            @pid = pid
            @child_was_alive = child_alive?(pid)
            sleep 0.5 # let the child settle, then bring the whole unit down
            begin
              launcher.stop
            rescue StandardError => e
              @watchdog_error = e
            end
          rescue StandardError => e
            @watchdog_error = e
            begin
              launcher.stop
            rescue StandardError
              nil
            end
          end

          launcher.run # blocks until the watchdog stops it

          watchdog.join(20)
          refute @watchdog_error, "watchdog failed: #{@watchdog_error&.message}"
          assert @pid, 'plugin never forked the Blaze child'
          assert @child_was_alive, 'Blaze child was not alive after fork'
          refute child_alive?(@pid), 'Blaze child must not outlive the launcher'
        end
      ensure
        MixinBot.configure { self.blaze_handler = previous_handler }
      end

      private

      def wait_for_plugin(config)
        deadline = deadline_at(15)
        loop do
          plugin = config.plugins.instance_variable_get(:@instances)&.first
          return plugin if plugin
          raise 'plugin instance never appeared' if deadline_passed?(deadline)

          sleep 0.02
        end
      end

      def wait_for_fork(plugin)
        deadline = deadline_at(15)
        loop do
          pid = plugin.instance_variable_get(:@blaze_pid)
          return pid if pid
          raise 'plugin never forked the Blaze child' if deadline_passed?(deadline)

          sleep 0.02
        end
      end

      def deadline_at(seconds)
        Process.clock_gettime(Process::CLOCK_MONOTONIC) + seconds
      end

      def deadline_passed?(deadline)
        Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline
      end

      def child_alive?(pid)
        return false unless pid

        Process.kill(0, pid)
        true
      rescue Errno::ESRCH, Errno::EPERM
        false
      end
    end
  end
end
