# frozen_string_literal: true

require 'test_helper'
require 'base64'
require 'openssl'
require 'socket'

module MixinBot
  ##
  # Offline unit tests for +MixinBot::API::BlazeAsync+ — the fiber-based
  # sibling of +API::Blaze#blaze+.
  #
  # The transport itself is out of scope here (it needs a live WebSocket
  # endpoint); these tests stub +Async::WebSocket::Client.connect+ and assert
  # the contract +blaze_async+ must uphold: same URL, subprotocol, and
  # headers as +blaze+; forced HTTP/1 ALPN; handler and endpoint-option
  # passthrough; and the block-less "returns a client the caller drives"
  # result shape.
  class TestBlazeAsync < Minitest::Test
    def setup
      OfflineConfig.apply!
    end

    def capture_connect(&call)
      captured = {}
      original = Async::WebSocket::Client.method(:connect)
      stub = lambda do |endpoint, **options|
        captured[:endpoint] = endpoint
        captured[:options] = options
        :connection
      end

      Async::WebSocket::Client.define_singleton_method(:connect, stub)
      captured[:result] = call.call
      captured
    ensure
      Async::WebSocket::Client.define_singleton_method(:connect, original)
    end

    def test_returns_the_connect_result_unchanged
      captured = capture_connect { MixinBot.api.blaze_async }

      assert_equal :connection, captured[:result]
    end

    def test_builds_the_endpoint_from_the_configured_blaze_host
      captured = capture_connect { MixinBot.api.blaze_async }

      assert_includes captured[:endpoint].to_s, MixinBot.config.blaze_host
    end

    def test_forces_the_http1_alpn_upgrade_path
      captured = capture_connect { MixinBot.api.blaze_async }

      assert_equal Async::HTTP::Protocol::HTTP11.names, captured[:endpoint].alpn_protocols
    end

    def test_negotiates_the_mixin_blaze_subprotocol
      captured = capture_connect { MixinBot.api.blaze_async }

      assert_equal ['Mixin-Blaze-1'], captured[:options][:protocols]
    end

    def test_sends_the_bearer_authorization_and_user_agent_headers
      captured = capture_connect { MixinBot.api.blaze_async }
      headers = captured[:options][:headers]

      assert_match(/\ABearer .+\z/, headers['Authorization'])
      assert_equal "mixin_bot/#{MixinBot::VERSION}", headers['User-Agent']
    end

    def test_passes_the_handler_through_to_the_client
      handler = Class.new(Async::WebSocket::Connection)
      captured = capture_connect { MixinBot.api.blaze_async(handler: handler) }

      assert_equal handler, captured[:options][:handler]
    end

    def test_defaults_the_handler_to_the_library_connection
      captured = capture_connect { MixinBot.api.blaze_async }

      assert_equal Async::WebSocket::Connection, captured[:options][:handler]
    end

    def test_forwards_endpoint_options_to_the_endpoint
      captured = capture_connect { MixinBot.api.blaze_async(endpoint_options: { timeout: 42 }) }

      assert_equal 42, captured[:endpoint].timeout
    end

    def test_uses_direct_endpoint_when_proxy_is_unset
      previous = MixinBot.config.proxy
      MixinBot.config.proxy = nil

      captured = capture_connect { MixinBot.api.blaze_async }
      underlying = captured[:endpoint].endpoint.endpoint

      refute_instance_of MixinBot::API::BlazeAsync::HttpConnectEndpoint, underlying
    ensure
      MixinBot.config.proxy = previous
    end

    def test_wraps_endpoint_in_http_connect_tunnel_when_proxy_is_set
      previous = MixinBot.config.proxy
      MixinBot.config.proxy = 'http://alice:secret@127.0.0.1:7890'

      captured = capture_connect { MixinBot.api.blaze_async }
      underlying = captured[:endpoint].endpoint.endpoint

      assert_instance_of MixinBot::API::BlazeAsync::HttpConnectEndpoint, underlying
      assert_equal MixinBot.config.proxy_config, underlying.proxy
      assert_equal "#{MixinBot.config.blaze_host}:443", underlying.authority
    ensure
      MixinBot.config.proxy = previous
    end

    def test_http_connect_endpoint_tunnels_over_http_proxy_with_auth
      server = TCPServer.new('127.0.0.1', 0)
      port = server.addr[1]
      proxy = MixinBot::Proxy.parse("http://alice:s3cr3t@127.0.0.1:#{port}")
      received_request = +''

      Sync do |task|
        server_task = task.async do
          client = server.accept
          received_request << client.gets("\r\n\r\n").to_s
          client.write("HTTP/1.1 200 Connection Established\r\n\r\n")
          assert_equal 'ping', client.read(4)
          client.write('pong')
          client.close
        end

        endpoint = MixinBot::API::BlazeAsync::HttpConnectEndpoint.new(proxy, 'blaze.mixin.one:443')
        socket = endpoint.connect
        begin
          socket.write('ping')
          assert_equal 'pong', socket.read(4)
        ensure
          socket.close unless socket.closed?
        end

        server_task.wait
      end

      expected_auth = "Basic #{Base64.strict_encode64('alice:s3cr3t')}"
      assert_includes received_request, "CONNECT blaze.mixin.one:443 HTTP/1.1\r\n"
      assert_includes received_request, "Host: blaze.mixin.one:443\r\n"
      assert_includes received_request, "Proxy-Authorization: #{expected_auth}\r\n"
    ensure
      server&.close
    end

    def test_http_connect_endpoint_raises_on_non_200_proxy_response
      server = TCPServer.new('127.0.0.1', 0)
      port = server.addr[1]
      proxy = MixinBot::Proxy.parse("http://127.0.0.1:#{port}")

      Sync do |task|
        server_task = task.async do
          client = server.accept
          client.gets("\r\n\r\n")
          client.write("HTTP/1.1 407 Proxy Authentication Required\r\n\r\n")
          client.close
        end

        endpoint = MixinBot::API::BlazeAsync::HttpConnectEndpoint.new(proxy, 'blaze.mixin.one:443')
        error = assert_raises(MixinBot::HttpError) { endpoint.connect }
        assert_match(/407/, error.message)

        server_task.wait
      end
    ensure
      server&.close
    end

    def test_http_connect_endpoint_bridges_https_proxy_to_raw_socket
      tcp_server = TCPServer.new('127.0.0.1', 0)
      port = tcp_server.addr[1]
      ssl_server = OpenSSL::SSL::SSLServer.new(tcp_server, self_signed_localhost_context)
      proxy = MixinBot::Proxy.parse("https://bob:pass@localhost:#{port}")
      received_request = +''

      Sync do |task|
        server_task = task.async do
          client = ssl_server.accept
          received_request << client.gets("\r\n\r\n").to_s
          client.write("HTTP/1.1 200 Connection Established\r\n\r\n")
          assert_equal 'hello-https', client.read(11)
          client.write('world-https')
          client.close
        end

        endpoint = MixinBot::API::BlazeAsync::HttpConnectEndpoint.new(proxy, 'blaze.mixin.one:443')
        socket = endpoint.connect
        begin
          assert_kind_of ::Socket, socket
          # Ensure Ruby OpenSSL accepts the bridged socket as a File/Socket (not an SSLSocket).
          wrapper = OpenSSL::SSL::SSLSocket.new(socket)
          assert_instance_of OpenSSL::SSL::SSLSocket, wrapper

          socket.write('hello-https')
          assert_equal 'world-https', socket.read(11)
        ensure
          socket.close unless socket.closed?
        end

        server_task.wait
      end

      assert_includes received_request, "CONNECT blaze.mixin.one:443 HTTP/1.1\r\n"
      assert_includes received_request, "Proxy-Authorization: Basic #{Base64.strict_encode64('bob:pass')}\r\n"
    ensure
      ssl_server&.close
      tcp_server&.close unless tcp_server&.closed?
    end

    private

    def self_signed_localhost_context
      key = OpenSSL::PKey::RSA.new(2048)
      cert = OpenSSL::X509::Certificate.new
      cert.version = 2
      cert.serial = 1
      cert.subject = OpenSSL::X509::Name.parse('/CN=localhost')
      cert.issuer = cert.subject
      cert.public_key = key.public_key
      cert.not_before = Time.now - 60
      cert.not_after = Time.now + 3600
      ef = OpenSSL::X509::ExtensionFactory.new
      ef.subject_certificate = cert
      ef.issuer_certificate = cert
      cert.add_extension(ef.create_extension('subjectAltName', 'DNS:localhost', false))
      cert.sign(key, OpenSSL::Digest.new('SHA256'))

      ctx = OpenSSL::SSL::SSLContext.new
      ctx.cert = cert
      ctx.key = key
      ctx
    end
  end
end
