# frozen_string_literal: true

require 'async/http/endpoint'
require 'async/http/protocol/http11'
require 'async/websocket/client'

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

        endpoint = Async::HTTP::Endpoint.parse(
          format('wss://%<host>s/', host: config.blaze_host),
          # Force the HTTP/1 upgrade path: avoids the RFC 8441 (h2 CONNECT)
          # route, which not every gateway negotiates the same way.
          alpn_protocols: Async::HTTP::Protocol::HTTP11.names,
          **endpoint_options
        )

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
