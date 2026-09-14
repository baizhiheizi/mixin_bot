# frozen_string_literal: true

require 'test_helper'
require 'stringio'

module MixinBot
  module Blaze
    class FakeConnection
      attr_reader :frames, :pings, :closed

      def initialize(messages: [], error: nil)
        @messages = messages.dup
        @error = error
        @frames = []
        @pings = 0
        @closed = false
      end

      def self.gzip(envelope)
        io = StringIO.new
        Zlib::GzipWriter.new(io).tap do |gzip|
          gzip.write envelope.to_json
          gzip.close
        end
        io.string
      end

      Message = Struct.new(:payload) do
        def to_str
          payload
        end
      end

      def read
        raise @error if @error

        payload = @messages.shift
        payload ? Message.new(payload) : nil
      end

      def write(frame)
        @frames << frame
      end

      def send_ping
        @pings += 1
      end

      def close
        @closed = true
      end

      def binary_frames
        # frames are gzip(JSON); decode so assertions can match on content
        @frames.map do |frame|
          Zlib::GzipReader.new(StringIO.new(frame.to_str)).read
        rescue Zlib::Error
          frame.to_str
        end
      end
    end

    class TestReactor < Minitest::Test
      def setup
        @created = []
        @backoffs = []
        @logs = []
      end

      def test_dispatches_message_to_handler_and_acks_on_receipt
        envelope = { 'action' => 'CREATE_MESSAGE', 'data' => { 'message_id' => 'mid-1', 'category' => 'PLAIN_TEXT' } }
        connection = FakeConnection.new(messages: [FakeConnection.gzip(envelope)])
        handled = Queue.new

        reactor = build_reactor(connections: [connection], handler: ->(raw) { handled << raw })

        run_and_stop reactor do
          raw = pop(handled)
          assert_equal 'mid-1', raw.dig('data', 'message_id')
        end

        acked = connection.binary_frames.grep(/ACKNOWLEDGE_MESSAGE_RECEIPT/)
        assert_equal 1, acked.size
        assert_includes acked.first, 'mid-1'
        assert connection.closed
      end

      def test_on_receipt_acks_even_when_handler_raises
        envelope = { 'action' => 'CREATE_MESSAGE', 'data' => { 'message_id' => 'mid-2' } }
        connection = FakeConnection.new(messages: [FakeConnection.gzip(envelope)])
        handled = Queue.new

        reactor = build_reactor(
          connections: [connection],
          handler: lambda { |_raw|
            handled << :raised
            raise 'boom'
          }
        )

        run_and_stop reactor do
          pop(handled)
        end

        assert_equal 1, connection.binary_frames.grep(/mid-2/).size
        assert(@logs.any? { |level, _detail| level == :handler_error })
      end

      def test_after_handler_skips_ack_when_handler_raises
        envelope = { 'action' => 'CREATE_MESSAGE', 'data' => { 'message_id' => 'mid-3' } }
        connection = FakeConnection.new(messages: [FakeConnection.gzip(envelope)])
        handled = Queue.new

        reactor = build_reactor(
          connections: [connection],
          handler: lambda { |_raw|
            handled << :raised
            raise 'boom'
          },
          ack_policy: :after_handler
        )

        run_and_stop reactor do
          pop(handled)
        end

        assert_empty connection.binary_frames.grep(/ACKNOWLEDGE_MESSAGE_RECEIPT/)
      end

      def test_after_handler_acks_once_handler_succeeds
        envelope = { 'action' => 'CREATE_MESSAGE', 'data' => { 'message_id' => 'mid-4' } }
        connection = FakeConnection.new(messages: [FakeConnection.gzip(envelope)])
        handled = Queue.new

        reactor = build_reactor(
          connections: [connection],
          handler: ->(_raw) { handled << :ok },
          ack_policy: :after_handler
        )

        run_and_stop reactor do
          pop(handled)
        end

        assert_equal 1, connection.binary_frames.grep(/mid-4/).size
      end

      def test_receipt_confirmations_are_neither_dispatched_nor_acked
        # the server confirms our own sent/acked messages with
        # ACKNOWLEDGE_MESSAGE_RECEIPT frames; re-acking one would round-trip a
        # no-op frame back to the server, and the handler must not see them
        echo = { 'action' => 'ACKNOWLEDGE_MESSAGE_RECEIPT', 'data' => { 'message_id' => 'mid-out' } }
        handled = Queue.new

        %i[on_receipt after_handler].each do |ack_policy|
          connection = FakeConnection.new(messages: [FakeConnection.gzip(echo)])
          reactor = build_reactor(connections: [connection], handler: ->(raw) { handled << raw }, ack_policy: ack_policy)

          run_and_stop reactor do
            # a dispatched echo would enqueue here and fail the pop timeout
            assert_nil handled.pop(timeout: 0.2), 'handler must not receive ACKNOWLEDGE_MESSAGE_RECEIPT frames'
          end

          assert_empty connection.binary_frames.grep(/ACKNOWLEDGE_MESSAGE_RECEIPT/),
                       "#{ack_policy} must not acknowledge receipt confirmations"
        end
      end

      def test_reconnects_after_abrupt_close_with_backoff
        broken = FakeConnection.new(error: EOFError.new('abrupt'))
        good = FakeConnection.new(messages: [FakeConnection.gzip({ 'action' => 'CREATE_MESSAGE', 'data' => { 'message_id' => 'mid-5' } })])
        handled = Queue.new

        reactor = build_reactor(connections: [broken, good], handler: ->(_raw) { handled << :ok })

        run_and_stop reactor do
          pop(handled)
        end

        assert_equal [broken, good], @created
        assert_equal 1, @backoffs.first
      end

      def test_undecodable_message_is_skipped_without_ending_delivery
        garbage = FakeConnection.new(messages: ['not gzip at all', FakeConnection.gzip({ 'action' => 'CREATE_MESSAGE', 'data' => { 'message_id' => 'mid-6' } })])
        handled = Queue.new

        reactor = build_reactor(connections: [garbage], handler: ->(_raw) { handled << :ok })

        run_and_stop reactor do
          pop(handled)
        end

        assert(@logs.any? { |level, _detail| level == :decode_error })
      end

      def test_requires_callable_handler
        assert_raises(MixinBot::ArgumentError) do
          Reactor.new(handler: 'nope')
        end
      end

      def test_rejects_unknown_ack_policy
        assert_raises(MixinBot::ArgumentError) do
          Reactor.new(handler: ->(_raw) {}, ack_policy: :whenever)
        end
      end

      private

      def build_reactor(connections:, handler:, ack_policy: :on_receipt)
        Reactor.new(
          handler: handler,
          ack_policy: ack_policy,
          connection_factory: lambda {
            connection = connections.shift || raise('no more fake connections')
            @created << connection
            connection
          },
          keepalive_interval: 3600,
          sleeper: lambda { |seconds|
            @backoffs << seconds
            sleep 0.001
          },
          logger: ->(level, detail) { @logs << [level, detail] }
        )
      end

      def pop(queue)
        item = queue.pop(timeout: 5)
        flunk 'handler was never invoked' if item.nil?
        item
      end

      def run_and_stop(reactor)
        thread = Thread.new { reactor.run }
        yield
        reactor.stop
        thread.join(5)
      ensure
        reactor.stop
        thread.join(1) if thread&.alive?
        flunk 'reactor thread did not stop' if thread&.alive?
      end
    end
  end
end
