# frozen_string_literal: true

require 'async'
require 'async/http/endpoint'
require 'async/http/protocol/http11'
require 'async/websocket/client'
require 'io/endpoint/generic'
require 'openssl'
require 'socket'
require 'uri'

module MixinBot
  class API
    # Fiber-based sibling of +Blaze#blaze+: returns a connected
    # +Async::WebSocket+ client instead of a +Faye::WebSocket::Client+.
    #
    # Same endpoint, +Mixin-Blaze-1+ subprotocol, Bearer JWT, and User-Agent as
    # +blaze+. The frame codec (+ws_message+, +write_ws_message+,
    # +list_pending_message+, +acknowledge_message_receipt+) is
    # transport-agnostic and shared verbatim.
    #
    # Wire differences the caller must handle:
    # - *Send*: +write_ws_message+ returns an +Array+ of byte integers (the
    #   Faye backend framed that automatically); here the caller wraps it:
    #   +connection.write(Protocol::WebSocket::BinaryMessage.new(bytes.pack('C*')))+.
    # - *Read*: +connection.read+ returns a +Protocol::WebSocket::Message+;
    #   pass +message.to_str+ (the binary buffer) into +ws_message+.
    # - *Keepalive*: Faye's +ping: 60+ becomes the caller's job (server pings
    #   are still auto-replied by the protocol layer).
    #
    # Sends nothing on open — the caller sends +list_pending_message+ first,
    # mirroring +blaze+. No per-IO read timeout by default: quiet-but-healthy
    # connections are legitimate; liveness is the caller's policy.
    module BlazeAsync
      # Underlying IO endpoint that opens an HTTP/1.1 CONNECT tunnel through an
      # HTTP/HTTPS proxy so +Async::HTTP::Endpoint+ can wrap the tunneled
      # connection in TLS for +wss://+ targets.
      class HttpConnectEndpoint < ::IO::Endpoint::Generic
        MAX_HEADER_BYTES = 16_384

        attr_reader :proxy, :authority

        def initialize(proxy, authority, **)
          super(**)
          @proxy = proxy
          @authority = authority
        end

        def to_s
          "http-connect:#{@proxy.origin}->#{@authority}"
        end

        def inspect
          "#<#{self.class} proxy=#{@proxy.origin} authority=#{@authority}>"
        end

        def connect(_wrapper = nil)
          socket = open_tunnel
          return socket unless block_given?

          begin
            yield socket
          ensure
            close_quietly(socket)
          end
        end

        private

        def open_tunnel
          proxy_opts = { alpn_protocols: Async::HTTP::Protocol::HTTP11.names }
          proxy_opts[:timeout] = timeout if timeout

          socket = Async::HTTP::Endpoint.parse(@proxy.origin, **proxy_opts).connect
          begin
            write_connect_request(socket)
            read_connect_response!(socket)
          rescue StandardError
            close_quietly(socket)
            raise
          end

          @proxy.https? ? bridge_ssl_socket(socket) : socket
        end

        def write_connect_request(socket)
          lines = ["CONNECT #{@authority} HTTP/1.1"]
          @proxy.connect_headers(@authority).each do |name, value|
            lines << "#{name}: #{value}"
          end
          lines << '' << ''
          write_all(socket, lines.join("\r\n"))
        end

        def write_all(socket, data)
          bytes_written = 0
          while bytes_written < data.bytesize
            written = socket.write(data.byteslice(bytes_written..))
            bytes_written += written
          end
        end

        def read_connect_response!(socket)
          buffer = +''
          loop do
            chunk = socket.readpartial(1)
            buffer << chunk
            raise MixinBot::HttpError, 'Proxy CONNECT response headers exceeded 16KB limit' if buffer.bytesize > MAX_HEADER_BYTES
            break if buffer.end_with?("\r\n\r\n", "\n\n")
          end

          status_line = buffer.lines.first.to_s.strip
          return if status_line.match?(%r{\AHTTP/1\.[01]\s+200\b}i)

          raise MixinBot::HttpError, "Proxy CONNECT tunnel to #{@authority} failed: #{status_line}"
        rescue EOFError
          raise MixinBot::HttpError, "Proxy closed connection during CONNECT tunnel to #{@authority}"
        end

        # OpenSSL::SSL::SSLSocket rejects another SSLSocket as its underlying IO
        # (TypeError: expected File), so an HTTPS proxy tunnel must be bridged
        # over a Unix socket pair before the target SSL handshake wraps it.
        def bridge_ssl_socket(ssl_socket)
          head, tail = ::Socket.pair(::Socket::AF_UNIX, ::Socket::SOCK_STREAM)
          state = { writer_finished: false, reader_task: nil }

          pump_reader = lambda do |*|
            pump_stream(ssl_socket, head)
          ensure
            close_write_quietly(head)
            if state[:writer_finished]
              close_quietly(head)
              close_quietly(ssl_socket)
            end
          end

          pump_writer = lambda do |*|
            pump_stream(head, ssl_socket)
          ensure
            state[:writer_finished] = true
            reader_task = state[:reader_task]
            reader_task.stop if reader_task.respond_to?(:stop) && !reader_task.finished?
            close_quietly(head)
            close_quietly(ssl_socket)
          end

          if Async::Task.current?
            parent = Async::Task.current
            state[:reader_task] = parent.async(transient: true, &pump_reader)
            parent.async(transient: true, &pump_writer)
          else
            Thread.new(&pump_reader)
            Thread.new(&pump_writer)
          end

          tail
        end

        def pump_stream(source, dest)
          loop do
            chunk = source.readpartial(16_384)
            write_all(dest, chunk)
          end
        rescue IOError, Errno::EPIPE, Errno::ECONNRESET, Errno::EBADF, OpenSSL::SSL::SSLError
          nil
        end

        def close_write_quietly(io)
          io.close_write unless io.closed?
        rescue StandardError
          nil
        end

        def close_quietly(io)
          io.close unless io.closed?
        rescue StandardError
          nil
        end
      end

      # Returns the block-less +Client.connect+ connection, preserving
      # +blaze+'s "returns a client the caller drives" contract.
      #
      # +handler:+ is yield-through so the caller can supply an
      # +Async::WebSocket::Connection+ subclass (e.g. one that correlates
      # PONG frames). +endpoint_options:+ are forwarded to
      # +Async::HTTP::Endpoint.parse+. Prefer not passing +timeout:+ there: it
      # becomes the socket's per-read timeout, so a quiet-but-healthy
      # connection dies when no frame arrives within that window. Bound the
      # connect phase at the call site instead (see
      # MixinBot::Blaze::Reactor#connect!).
      def blaze_async(handler: Async::WebSocket::Connection, endpoint_options: {})
        access_token = access_token('GET', '/', '')
        authorization = format('Bearer %<access_token>s', access_token:)
        url = format('wss://%<host>s/', host: config.blaze_host)
        opts = {
          # Force the HTTP/1 upgrade path: avoids the RFC 8441 (h2 CONNECT)
          # route, which not every gateway negotiates the same way.
          alpn_protocols: Async::HTTP::Protocol::HTTP11.names,
          **endpoint_options
        }

        endpoint =
          if config.proxy_config
            target_uri = URI.parse(url)
            target_host = opts[:hostname] || target_uri.host
            target_port = opts[:port] || target_uri.port || 443
            tunnel = HttpConnectEndpoint.new(
              config.proxy_config,
              "#{target_host}:#{target_port}",
              timeout: opts[:timeout]
            )
            Async::HTTP::Endpoint.parse(url, tunnel, **opts)
          else
            Async::HTTP::Endpoint.parse(url, **opts)
          end

        Async::WebSocket::Client.connect(
          endpoint,
          protocols: ['Mixin-Blaze-1'],
          headers: { 'Authorization' => authorization, 'User-Agent' => "mixin_bot/#{MixinBot::VERSION}" },
          handler: handler
        )
      end
    end
  end
end
