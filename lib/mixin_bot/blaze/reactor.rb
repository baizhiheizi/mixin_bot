# frozen_string_literal: true

require 'async'
require 'json'
require 'protocol/websocket'

module MixinBot
  module Blaze
    # Fiber-based Blaze receive loop — the hosted sibling of
    # examples/blaze_async.rb.
    #
    # Drives API#blaze_async inside its own Async reactor (created by #run,
    # so it can be called from any plain thread — e.g. a Puma plugin's
    # background thread or a forked child). The loop: connect, request
    # pending messages, read frames serially, dispatch each decoded envelope
    # to the configured handler, and acknowledge per the ack policy. Dropped
    # connections are re-established with bounded exponential backoff.
    #
    # Handlers run serially on the reactor thread — never in concurrent
    # fibers — so handler code may use per-thread resources like ActiveRecord
    # connections safely. Handler exceptions are logged and do not end
    # message delivery.
    #
    #   Reactor.new(handler: ->(envelope) { ... }).run   # blocks forever
    #
    class Reactor
      CONNECT_TIMEOUT = 10
      KEEPALIVE_INTERVAL = 30
      INITIAL_BACKOFF = 1
      MAX_BACKOFF = 30
      # a connection must live at least this long for the backoff to reset
      STABLE_PERIOD = 30

      attr_reader :handler, :ack_policy

      ##
      # @param api [MixinBot::API] API used for frame codecs and connecting
      # @param handler [#call] invoked with each decoded message envelope
      #   Hash (with +action+ and +data+ keys)
      # @param ack_policy [Symbol] +:on_receipt+ (ack before the handler
      #   runs) or +:after_handler+ (ack only after the handler succeeds;
      #   failed messages are redelivered on reconnect)
      # @param connection_factory [#call, nil] returns a connected
      #   +Async::WebSocket+ connection; defaults to +api.blaze_async+
      #   with a +connect_timeout+ connect phase
      # @param keepalive_interval [Numeric] seconds between client pings
      # @param connect_timeout [Numeric] seconds allowed for connecting
      # @param sleeper [#call, nil] backoff hook, called with seconds;
      #   defaults to +Kernel#sleep+ (inject for tests)
      # @param logger [#call, nil] called with +(level, exception_or_message)+;
      #   defaults to +$stderr+
      def initialize(handler:, api: MixinBot.api, ack_policy: MixinBot.config.blaze_ack_policy,
                     connection_factory: nil, keepalive_interval: KEEPALIVE_INTERVAL,
                     connect_timeout: CONNECT_TIMEOUT, sleeper: nil, logger: nil)
        raise MixinBot::ArgumentError, 'handler must respond to #call' unless handler.respond_to?(:call)
        unless %i[on_receipt after_handler].include?(ack_policy)
          raise MixinBot::ArgumentError, "ack_policy must be :on_receipt or :after_handler, got #{ack_policy.inspect}"
        end

        @api = api
        @handler = handler
        @ack_policy = ack_policy
        @connection_factory = connection_factory || -> { api.blaze_async(endpoint_options: { timeout: connect_timeout }) }
        @keepalive_interval = keepalive_interval
        @sleeper = sleeper || ->(seconds) { sleep seconds }
        @logger = logger || ->(level, detail) { warn "[mixin_blaze] #{level}: #{detail}" }
        @guard = Mutex.new
        @stopping = false
        @connection = nil
      end

      ##
      # Runs the connect/read/reconnect loop, blocking the calling thread
      # until #stop. Yields control to the fiber scheduler while waiting.
      #
      # @return [void]
      def run
        Async do
          backoff = INITIAL_BACKOFF

          until stopped?
            started_at = monotonic_time
            begin
              run_connection
              backoff = INITIAL_BACKOFF if stable?(started_at)
            rescue StandardError => e
              log.call :error, e
              backoff = INITIAL_BACKOFF if stable?(started_at)
            end

            break if stopped?

            sleep_backoff backoff
            backoff = [(backoff * 2), MAX_BACKOFF].min
          end
        end
      end

      ##
      # Stops the loop and closes the current connection. Safe to call from
      # any thread (including while #run blocks in another one) and safe to
      # call more than once.
      #
      # @return [void]
      def stop
        @guard.synchronize do
          @stopping = true
          begin
            @connection&.close
          rescue StandardError
            # already dead; the read loop will notice on its own
          end
        end
      end

      private

      def stopped?
        @guard.synchronize { @stopping }
      end

      # One connection lifetime: connect, keepalive, pending request, read
      # loop. Returns on a clean close; raises on a broken one.
      def run_connection
        return unless connect!

        log.call :connected, "pid=#{Process.pid}"

        keepalive = start_keepalive
        send_frame @api.list_pending_message

        while (message = @connection.read)
          dispatch message
        end
        log.call :closed, 'clean close'
      ensure
        keepalive&.stop
        @connection&.close
        @connection = nil
      end

      # Establishes the connection and registers it under the guard, so a
      # concurrent #stop can always find and close it. Returns nil when the
      # reactor stopped mid-connect; the fresh connection is closed here.
      def connect!
        fresh = @connection_factory.call

        @guard.synchronize do
          if @stopping
            begin
              fresh&.close
            rescue StandardError
              nil
            end
            return nil
          end

          @connection = fresh
        end

        fresh
      end

      def start_keepalive
        Async do
          loop do
            sleep @keepalive_interval
            @connection&.send_ping
          end
        rescue Protocol::WebSocket::ProtocolError, IOError
          # the connection is gone; the read loop is already winding down
        end
      end

      # Serial dispatch — handlers never run in concurrent fibers.
      def dispatch(message)
        raw = decode(message)
        return if raw.nil?

        data = raw['data'].is_a?(Hash) ? raw['data'] : {}
        message_id = data['message_id']

        send_frame @api.acknowledge_message_receipt(message_id) if @ack_policy == :on_receipt && message_id

        handler_ok =
          begin
            handler.call raw
            true
          rescue StandardError => e
            log.call :handler_error, e
            false
          end

        send_frame @api.acknowledge_message_receipt(message_id) if @ack_policy == :after_handler && handler_ok && message_id
      end

      def decode(message)
        JSON.parse @api.ws_message(message.to_str)
      rescue Zlib::Error, JSON::ParserError => e
        log.call :decode_error, e
        nil
      end

      def send_frame(bytes)
        @connection.write Protocol::WebSocket::BinaryMessage.new(bytes.pack('C*'))
      end

      def sleep_backoff(seconds)
        @sleeper.call seconds
      end

      def stable?(started_at)
        monotonic_time - started_at >= STABLE_PERIOD
      end

      def monotonic_time
        Process.clock_gettime Process::CLOCK_MONOTONIC
      end

      def log
        @logger
      end
    end
  end
end
