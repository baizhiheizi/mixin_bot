# frozen_string_literal: true

# Puma plugin hosting the Blaze connection inside the web process tree —
# the Solid Queue plugin architecture:
#
#   # config/puma.rb
#   plugin :mixin_blaze
#   mixin_blaze_mode :fork   # default; :async hosts the loop in-process
#
#   # config/initializers/mixin_bot.rb
#   MixinBot.configure do
#     self.blaze_handler = ->(envelope) { MyBot.process! envelope }
#   end
#
# Modes:
# - *fork* (default): after boot a dedicated child process runs
#   {MixinBot::Blaze::Reactor}; a background thread supervises it and stops
#   Puma if the child dies (fail fast — silent non-reception is worse than a
#   visible restart). The child stops with Puma and monitors the master.
# - *async*: the reactor runs in a Puma background thread inside this very
#   process. In cluster mode that process is the master.
#
# Requires `preload_app!` in cluster mode: plugins run in the launcher
# process, and without preloading it holds no application code to resolve
# the handler.
require 'English'
require 'mixin_bot'
require 'puma/plugin'

module Puma
  class DSL
    # Selects where the Blaze connection lives (see file comment).
    #
    # @param mode [Symbol] +:fork+ (default) or +:async+
    def mixin_blaze_mode(mode = :fork)
      @options[:mixin_blaze_mode] = mode.to_sym
    end
  end
end

Puma::Plugin.create do
  def start(launcher)
    @launcher = launcher
    @log_writer = launcher.log_writer
    @puma_pid = $PROCESS_ID
    @mode = launcher.options[:mixin_blaze_mode] || :fork

    unless %i[fork async].include?(@mode)
      @log_writer.error "mixin_blaze: mixin_blaze_mode must be fork or async, got #{@mode.inspect}; plugin not started"
      return
    end

    if launcher.options[:workers].to_i.positive? && !launcher.options[:preload_app]
      @log_writer.error 'mixin_blaze: Puma cluster mode requires preload_app! (the launcher process hosts the Blaze handler); ' \
                        'enable preload_app! or drop to single mode; plugin not started'
      return
    end

    @mode == :async ? start_async_mode : start_fork_mode
  end

  private

  def start_fork_mode
    in_background { monitor_blaze_fork }

    register_lifecycle(
      booted: -> { fork_blaze },
      stopped: -> { stop_blaze_fork },
      restart: -> { stop_blaze_fork }
    )
  end

  def start_async_mode
    register_lifecycle(
      booted: -> { start_blaze_async },
      stopped: -> { stop_blaze_async },
      restart: lambda {
        stop_blaze_async
        start_blaze_async
      }
    )
  end

  # Puma 7 renamed the lifecycle hooks; the old names remain as deprecated
  # aliases (same branching as Solid Queue's plugin).
  def register_lifecycle(booted:, stopped:, restart:)
    if Gem::Version.new(Puma::Const::VERSION) < Gem::Version.new('7')
      @launcher.events.on_booted { booted.call }
      @launcher.events.on_stopped { stopped.call }
      @launcher.events.on_restart { restart.call }
    else
      @launcher.events.after_booted { booted.call }
      @launcher.events.after_stopped { stopped.call }
      @launcher.events.before_restart { restart.call }
    end
  end

  # ---- fork mode ----

  def fork_blaze
    reactor = build_reactor
    return if reactor.nil?

    @blaze_pid = fork do
      @blaze_pid = nil
      # the master's INT trap must not run here; raise Interrupt on the main
      # thread instead, so the reactor unwinds and closes the connection
      Signal.trap(:INT) { raise Interrupt }
      Signal.trap(:TERM) { exit!(0) }
      Thread.new { monitor_puma_master }

      begin
        reactor.run
      ensure
        # skip at-exit finalization, which can deadlock on inherited
        # database handles (same rationale as Solid Queue's plugin)
        exit!(0)
      end
    end

    log "mixin_blaze: forked Blaze child (pid #{@blaze_pid})"
  rescue NotImplementedError
    @log_writer.error 'mixin_blaze: fork is unavailable on this platform; use mixin_blaze_mode :async'
  end

  def stop_blaze_fork
    return unless @blaze_pid

    @shutting_down = true

    begin
      Process.waitpid(@blaze_pid, Process::WNOHANG)
    rescue Errno::ECHILD, Errno::ESRCH
      # already gone; the reap loop below handles it
    end
    log 'mixin_blaze: stopping Blaze child...'
    begin
      Process.kill(:INT, @blaze_pid)
    rescue Errno::ESRCH
      @blaze_pid = nil
      return
    end

    # bounded reap: never let a stuck child hold up Puma's shutdown
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 10.0
    reaped = false
    while Process.clock_gettime(Process::CLOCK_MONOTONIC) < deadline
      begin
        reaped = true if Process.waitpid(@blaze_pid, Process::WNOHANG)
        break if reaped
      rescue Errno::ECHILD, Errno::ESRCH
        reaped = true
        break
      end
      sleep 0.05
    end

    unless reaped
      log "mixin_blaze: Blaze child #{@blaze_pid} did not stop within 10s; killing"
      begin
        Process.kill(:KILL, @blaze_pid)
      rescue Errno::ESRCH
        nil
      end
      begin
        Process.waitpid(@blaze_pid) # KILL is fatal; reap the zombie
      rescue Errno::ECHILD, Errno::ESRCH
        nil
      end
    end
    @blaze_pid = nil
  rescue Errno::ECHILD, Errno::ESRCH
    @blaze_pid = nil
  end

  def monitor_blaze_fork
    loop do
      if blaze_fork_dead?
        log 'mixin_blaze: Blaze child has gone away, stopping Puma...'
        stop_puma!
        break
      end
      sleep 2
    end
  rescue StandardError => e
    log "mixin_blaze: monitor thread ended (#{e.class}: #{e.message})"
  end

  def blaze_fork_dead?
    return false if @shutting_down
    return false unless @blaze_pid

    Process.waitpid(@blaze_pid, Process::WNOHANG)
    false
  rescue Errno::ECHILD, Errno::ESRCH
    true
  end

  def monitor_puma_master
    loop do
      if Process.ppid != @puma_pid
        Process.kill(:INT, $PROCESS_ID)
        break
      end
      sleep 2
    end
  end

  # ---- async mode ----

  def start_blaze_async
    reactor = build_reactor
    return if reactor.nil?

    @reactor = reactor
    @blaze_thread = Thread.new do
      Thread.current.name = 'puma plugin mixin_blaze' if Thread.current.respond_to?(:name=)
      reactor.run
    end

    log "mixin_blaze: Blaze reactor running in-process (pid #{Process.pid})"
  end

  def stop_blaze_async(join_limit: 1)
    reactor = @reactor
    thread = @blaze_thread
    @reactor = nil
    @blaze_thread = nil

    return unless reactor

    reactor.stop
    thread&.join(join_limit)
    log 'mixin_blaze: in-process Blaze reactor stopped'
  end

  # ---- shared ----

  # Handler resolution happens at boot time (after the application has
  # loaded — Puma starts plugin background work after load_and_bind).
  def build_reactor
    handler = MixinBot.config.blaze_handler
    if handler.nil?
      @log_writer.error 'mixin_blaze: no handler configured — set MixinBot.configure { self.blaze_handler = ->(envelope) { ... } }; ' \
                        'plugin not started'
      return nil
    end

    MixinBot::Blaze::Reactor.new(handler: handler, logger: ->(level, detail) { log("mixin_blaze #{level}: #{detail}") })
  end

  def stop_puma!
    Process.kill(:INT, $PROCESS_ID)
  end

  def log(message)
    @log_writer.log(message)
  rescue Errno::EIO, Errno::EPIPE, Errno::EBADF
    # the controlling terminal can disappear mid-shutdown; keep going
    nil
  end
end
