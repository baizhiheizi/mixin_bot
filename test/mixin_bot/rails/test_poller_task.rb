# frozen_string_literal: true

require 'test_helper'
require 'open3'
require 'rbconfig'

module MixinBot
  # Runs the mixin_bot:poller rake task in a subprocess against the fixture
  # app and verifies its lifecycle: boots, polls (the offline fetch fails and
  # is logged), and stops gracefully on SIGTERM. The task is invoked through
  # Rake directly (bypassing the rake binstub chain).
  class PollerTaskTest < Minitest::Test
    APP_ROOT = File.expand_path('../../fixtures/poller_app', __dir__)
    REPO_ROOT = File.expand_path('../../..', __dir__)

    def test_poller_task_starts_polls_and_stops_on_sigterm
      @output = +''
      stdin, out, waiter = Open3.popen2e(
        { 'BUNDLE_GEMFILE' => File.join(REPO_ROOT, 'Gemfile'),
          'MIXIN_BOT_POLL_INTERVAL' => '1' },
        'bundle', 'exec', 'ruby', "-I#{File.join(REPO_ROOT, 'lib')}",
        '-e', "load 'Rakefile'; Rake::Task['mixin_bot:poller'].invoke",
        chdir: APP_ROOT
      )
      stdin.close

      started = wait_until(out) { @output.match?('poller started') }
      polling = wait_until(out) { @output.match?('poll_error') }

      Process.kill('TERM', waiter.pid) if started && polling
      stopped = wait_until(out, timeout: 10) { @output.match?('poller stopped') }
      status = waiter.join(10)&.value

      assert started, "expected a 'poller started' log line, got:\n#{@output}"
      assert polling, "expected poll cycles to be attempted (poll_error logged), got:\n#{@output}"
      assert stopped, "expected graceful 'poller stopped' log line after SIGTERM, got:\n#{@output}"
      assert_predicate status, :success?, "expected clean exit after SIGTERM, output:\n#{@output}"
    ensure
      begin
        out&.close
      rescue IOError
        nil
      end
    end

    private

    # Reads whatever arrives on io, accumulating into @output, until the block
    # reports ready or the deadline passes.
    def wait_until(io, timeout: 15)
      deadline = Time.now + timeout
      loop do
        loop do
          chunk = io.read_nonblock(4096, exception: false)
          break if chunk.nil? || chunk == :wait_readable

          @output << chunk
        end
        return true if yield
        return false if Time.now > deadline

        sleep 0.1
      end
    end
  end
end
