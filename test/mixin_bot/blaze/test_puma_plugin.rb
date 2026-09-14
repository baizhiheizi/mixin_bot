# frozen_string_literal: true

require 'test_helper'
require 'minitest/stub_const'
require 'puma'
require 'puma/configuration'
require 'puma/plugin/mixin_blaze'

module MixinBot
  module Blaze
    class FakeLogWriter
      attr_reader :entries

      def initialize
        @entries = []
      end

      def log(message)
        @entries << [:log, message]
      end

      def error(message)
        @entries << [:error, message]
      end

      def errors
        @entries.filter_map { |level, message| message if level == :error }
      end
    end

    class FakeEvents
      attr_reader :hooks

      def initialize
        @hooks = Hash.new { |hash, key| hash[key] = [] }
      end

      %i[on_booted on_stopped on_restart after_booted after_stopped before_restart].each do |name|
        define_method(name) { |&block| @hooks[name] << block }
      end

      def fire!(event)
        @hooks[event].each(&:call)
      end

      def empty?
        @hooks.values.all?(&:empty?)
      end
    end

    class FakeLauncher
      attr_reader :options, :log_writer, :events

      def initialize(options: {})
        @options = options
        @log_writer = FakeLogWriter.new
        @events = FakeEvents.new
      end
    end

    # Test double for MixinBot::Blaze::Reactor — no network, no forks of its own.
    class HangingReactor
      attr_reader :stop_called

      def initialize(handler:, logger: nil)
        @handler = handler
        @logger = logger
        @stop_called = false
      end

      def run
        sleep 0.05 until @stop_called
      end

      def stop
        @stop_called = true
      end
    end

    class QuittingReactor < HangingReactor
      def run
        # exits immediately: simulates a crashing Blaze child
      end
    end

    class TestPumaPlugin < Minitest::Test
      def setup
        @previous_handler = MixinBot.config.blaze_handler
        @previous_ack_policy = MixinBot.config.blaze_ack_policy
        MixinBot.configure do
          self.blaze_handler = ->(_envelope) { envelope }
        end
      end

      def teardown
        MixinBot.configure do
          self.blaze_handler = @previous_handler
          self.blaze_ack_policy = @previous_ack_policy
        end
        Puma::Plugins.instance_variable_get(:@background)&.clear
      end

      def test_plugin_is_discoverable_and_dsl_option_registers
        assert Puma::Plugins.find('mixin_blaze')

        config = Puma::Configuration.new do |user_dsl|
          user_dsl.mixin_blaze_mode :async
        end
        config.clamp
        assert_equal :async, config.options[:mixin_blaze_mode]
      end

      def test_defaults_to_fork_mode_and_registers_puma7plus_events
        plugin = start_plugin

        assert_equal :fork, plugin.instance_variable_get(:@mode)
        assert_equal 1, events_of(plugin).hooks[:after_booted].size
        assert_equal 1, events_of(plugin).hooks[:after_stopped].size
        assert_equal 1, events_of(plugin).hooks[:before_restart].size
      end

      def test_puma6_receives_legacy_event_registrations
        plugin = nil
        Puma::Const.stub_const(:VERSION, '6.6.0') do
          plugin = start_plugin
        end

        assert_equal 1, events_of(plugin).hooks[:on_booted].size
        assert_equal 1, events_of(plugin).hooks[:on_stopped].size
        assert_equal 1, events_of(plugin).hooks[:on_restart].size
        assert_empty events_of(plugin).hooks[:after_booted]
      end

      def test_cluster_mode_without_preload_app_fails_loudly_and_starts_nothing
        launcher = FakeLauncher.new(options: { workers: 2, preload_app: false })
        plugin = start_plugin(launcher: launcher)

        assert(launcher.log_writer.errors.any? { |message| message.include?('preload_app!') })
        assert_empty events_of(plugin)
      end

      def test_invalid_mode_fails_loudly_and_starts_nothing
        launcher = FakeLauncher.new(options: { workers: 0, mixin_blaze_mode: :bogus })
        plugin = start_plugin(launcher: launcher)

        assert(launcher.log_writer.errors.any? { |message| message.include?('mixin_blaze_mode') })
        assert_empty events_of(plugin)
      end

      def test_missing_handler_fails_at_boot
        MixinBot.configure { self.blaze_handler = nil }
        launcher = FakeLauncher.new(options: { workers: 0 })
        plugin = start_plugin(launcher: launcher)

        events_of(plugin).fire!(:after_booted)

        assert(launcher.log_writer.errors.any? { |message| message.include?('blaze_handler') })
        assert_nil plugin.instance_variable_get(:@blaze_pid)
        assert_nil plugin.instance_variable_get(:@blaze_thread)
      end

      def test_async_mode_starts_and_stops_the_reactor
        thread = nil
        stub = nil
        MixinBot::Blaze.stub_const(:Reactor, HangingReactor) do
          plugin = start_plugin(mixin_blaze_mode: :async)

          events_of(plugin).fire!(:after_booted)
          wait_for(5) do
            thread = plugin.instance_variable_get(:@blaze_thread)
            thread&.alive?
          end
          stub = plugin.instance_variable_get(:@reactor)

          events_of(plugin).fire!(:after_stopped)
        end

        refute thread&.alive?
        assert stub.stop_called
      end

      def test_fork_mode_forks_a_child_and_stops_it_on_shutdown
        pid = nil
        MixinBot::Blaze.stub_const(:Reactor, HangingReactor) do
          plugin = start_plugin

          events_of(plugin).fire!(:after_booted)
          wait_for(5) { pid = plugin.instance_variable_get(:@blaze_pid) }
          refute_equal Process.pid, pid

          events_of(plugin).fire!(:after_stopped)
        end

        assert pid
        # SIGKILL delivery + reap can take a moment; poll rather than race
        deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 5
        alive = true
        while Process.clock_gettime(Process::CLOCK_MONOTONIC) < deadline
          begin
            Process.kill(0, pid)
          rescue Errno::ESRCH
            alive = false
            break
          end
          sleep 0.05
        end
        refute alive, 'Blaze child must not survive the launcher shutdown'
      end

      def test_monitor_stops_puma_when_the_child_dies
        stopped = Queue.new
        MixinBot::Blaze.stub_const(:Reactor, QuittingReactor) do
          plugin = start_plugin
          plugin.define_singleton_method(:stop_puma!) { stopped << Process.pid }

          Puma::Plugins.fire_background

          events_of(plugin).fire!(:after_booted) # the QuittingReactor child exits immediately
          assert_equal Process.pid, stopped.pop(timeout: 5)
        end
      end

      private

      def start_plugin(launcher: nil, mixin_blaze_mode: :fork)
        launcher ||= FakeLauncher.new(options: { workers: 0, mixin_blaze_mode: mixin_blaze_mode })

        plugin = Puma::Plugins.find('mixin_blaze').new
        plugin.start(launcher)
        plugin
      end

      def events_of(plugin)
        plugin.instance_variable_get(:@launcher).events
      end

      def wait_for(seconds)
        deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + seconds
        until yield
          flunk 'condition was never met' if Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline
          sleep 0.01
        end
      end
    end
  end
end
