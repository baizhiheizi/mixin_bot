# frozen_string_literal: true

# Fiber-based Blaze client — the async-websocket sibling of examples/blaze.rb.
#
# Drives API#blaze_async without EventMachine: the gem returns the connected
# connection and the caller runs the loop inside an Async reactor. The frame
# codec (write_ws_message / ws_message / list_pending_message /
# acknowledge_message_receipt) is shared with blaze verbatim; only the wire
# differs:
# - *Send*: write_ws_message returns an Array of byte integers (Faye framed
#   that itself) — wrap it in a Protocol::WebSocket::BinaryMessage.
# - *Read*: connection.read yields a Protocol::WebSocket::Message (or nil
#   after a clean close) — feed message.to_str into ws_message.
# - *Keepalive*: Faye's ping: 60 becomes the caller's job; server pings are
#   auto-replied by the protocol layer.
#
# Run: ruby examples/blaze_async.rb

require './lib/mixin_bot'
require 'async'
require 'base64'
require 'json'
require 'securerandom'
require 'yaml'

CONFIG = YAML.load_file("#{File.dirname __FILE__}/config.yml")
MixinBot.configure do
  self.app_id = CONFIG['app_id']
  self.client_secret = CONFIG['client_secret']
  self.session_id = CONFIG['session_id']
  self.server_public_key = CONFIG['server_public_key']
  self.session_private_key = CONFIG['session_private_key']
end

API = MixinBot.api

# gzip+JSON bytes from write_ws_message -> one binary WebSocket frame
def send_frame(connection, bytes)
  connection.write Protocol::WebSocket::BinaryMessage.new(bytes.pack('C*'))
end

Async do |task|
  # endpoint_options: is forwarded to Async::HTTP::Endpoint.parse. No
  # timeout: here — it would become the socket's per-read timeout and kill
  # quiet-but-healthy connections; liveness is the keepalive ping below.
  # handler: stays default; pass an Async::WebSocket::Connection subclass to
  # hook the raw frame events (e.g. PONG correlation).
  connection = API.blaze_async
  p [Time.now.to_s, :connected]

  # liveness is the caller's policy: nothing on the wire goes stale quietly
  keepalive = task.async do
    loop do
      sleep 30
      connection.send_ping
    end
  rescue Protocol::WebSocket::ProtocolError, IOError # IOError covers EOFError
    # connection is gone; the read loop below is already winding down
  end

  # sends nothing on open — mirror blaze and request pending messages first
  send_frame connection, API.list_pending_message

  # read returns nil after a clean close; an abrupt one raises EOFError
  while (message = connection.read)
    raw = JSON.parse API.ws_message(message.to_str)
    p [Time.now.to_s, :on_message, raw&.[]('action')]

    # data is a Hash for message envelopes, but an Array (the pending list)
    # in the LIST_PENDING_MESSAGES reply
    data = raw['data'].is_a?(Hash) ? raw['data'] : {}
    send_frame connection, API.acknowledge_message_receipt(data['message_id']) if data['message_id']

    # echo PLAIN_TEXT back to its sender over the same connection
    next unless data['category'] == 'PLAIN_TEXT'

    send_frame connection, API.write_ws_message(
      params: {
        conversation_id: data['conversation_id'],
        recipient_id: data['user_id'],
        message_id: SecureRandom.uuid,
        category: 'PLAIN_TEXT',
        data_base64: Base64.urlsafe_encode64("echo: #{Base64.urlsafe_decode64(data['data'])}", padding: false)
      }
    )
  end
  p [Time.now.to_s, :closed]
ensure
  keepalive&.stop
  connection&.close
end
