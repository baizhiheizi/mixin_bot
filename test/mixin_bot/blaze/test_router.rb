# frozen_string_literal: true

require 'test_helper'
require 'mixin_bot/rails'
require 'base64'
require 'digest'
require 'json'
require 'jose'

module MixinBot
  class BlazeRouterTest < Minitest::Test
    include WebMock::API

    def setup
      super
      RecordingHandler.handled = []
      ExplodingHandler.handled = []
      @captured_bodies = []
      @captured_auth = []
      @message_stub = stub_request(:post, 'https://api.mixin.one/messages').to_return do |request|
        @captured_bodies << JSON.parse(request.body)
        @captured_auth << request.headers['Authorization']
        { status: 200, headers: { 'Content-Type' => 'application/json' },
          body: JSON.generate({ 'data' => { 'message_id' => 'ack' }, 'error' => nil }) }
      end
    end

    def teardown
      remove_request_stub(@message_stub)
      super
    end

    def envelope(category: 'PLAIN_TEXT', data: 'hello', user_id: 'user-1', conversation_id: 'conv-1',
                 action: 'CREATE_MESSAGE', message_id: 'msg-1')
      {
        'action' => action,
        'data' => {
          'conversation_id' => conversation_id,
          'user_id' => user_id,
          'message_id' => message_id,
          'category' => category,
          'data_base64' => Base64.encode64(data)
        }
      }
    end

    # ---- Router dispatch (blaze-message-router: routing DSL) ----

    def test_dispatches_registered_category_to_class_handler
      router = MixinBot::Blaze::Router.new do
        on 'text', EchoHandler
      end

      result = router.call envelope

      assert_equal %w[hello conv-1 user-1 PLAIN_TEXT], result
    end

    def test_first_registered_route_wins
      router = MixinBot::Blaze::Router.new do
        on 'text', EchoHandler
        on 'PLAIN_TEXT', RecordingHandler
      end

      router.call envelope

      assert_empty RecordingHandler.handled
    end

    def test_unmatched_envelope_is_logged_and_ignored
      logs = []
      router = MixinBot::Blaze::Router.new(logger: ->(level, detail) { logs << [level, detail] }) do
        on 'app_card', RecordingHandler
      end

      assert_silent { router.call envelope }

      assert_empty RecordingHandler.handled
      assert_equal 1, logs.size
      assert_equal :unmatched, logs.first[0]
      assert_match(/PLAIN_TEXT/, logs.first[1].to_s)
    end

    def test_alias_normalization
      assert_equal 'PLAIN_TEXT', MixinBot::Blaze::Router.normalize_category(:text)
      assert_equal 'PLAIN_DATA', MixinBot::Blaze::Router.normalize_category('file')
      assert_equal 'SYSTEM_ACCOUNT_SNAPSHOT', MixinBot::Blaze::Router.normalize_category('transfer')
      assert_equal 'APP_CARD', MixinBot::Blaze::Router.normalize_category('app_card')
      assert_equal 'APP_CARD', MixinBot::Blaze::Router.normalize_category('APP_CARD')
    end

    def test_unknown_category_alias_raises
      error = assert_raises(MixinBot::ArgumentError) do
        MixinBot::Blaze::Router.new { on 'nope', RecordingHandler }
      end

      assert_match(/unknown message category/, error.message)
    end

    def test_hash_conditions_match_action_and_category
      router = MixinBot::Blaze::Router.new do
        on action: 'CREATE_MESSAGE', category: 'text', handler: RecordingHandler
      end

      router.call envelope

      assert_equal 1, RecordingHandler.handled.size
    end

    def test_hash_condition_mismatch_skips_route
      router = MixinBot::Blaze::Router.new do
        on action: 'ACKNOWLEDGE_MESSAGE_RECEIPT', handler: RecordingHandler
      end

      router.call envelope

      assert_empty RecordingHandler.handled
    end

    def test_callable_handler_receives_message
      received = nil
      router = MixinBot::Blaze::Router.new do
        on 'text', ->(message) { received = message }
      end

      router.call envelope

      assert_instance_of MixinBot::Blaze::Router::Message, received
      assert_equal 'hello', received.data
    end

    def test_invalid_handler_raises_at_registration
      error = assert_raises(MixinBot::ArgumentError) do
        MixinBot::Blaze::Router.new { on 'text', 'not-a-handler' }
      end

      assert_match(/must be a class or respond to #call/, error.message)
    end

    # ---- Handler exception containment ----

    def test_handler_exception_is_contained_and_next_message_still_delivered
      logs = []
      router = MixinBot::Blaze::Router.new(logger: ->(level, detail) { logs << [level, detail] }) do
        on 'text', ExplodingHandler
      end

      assert_silent do
        router.call envelope(message_id: 'boom')
        router.call envelope(message_id: 'after')
      end

      assert_equal %w[boom after], ExplodingHandler.handled
      assert_equal :handler_error, logs.first[0]
    end

    # ---- Message wrapper ----

    def test_message_decodes_text_payload_and_ids
      message = nil
      MixinBot::Blaze::Router.new { on 'text', ->(m) { message = m } }.call envelope

      assert_equal 'CREATE_MESSAGE', message.action
      assert_equal 'PLAIN_TEXT', message.category
      assert_equal 'conv-1', message.conversation_id
      assert_equal 'msg-1', message.message_id
      assert_equal 'user-1', message.user_id
      assert_equal 'hello', message.data
    end

    def test_message_parses_json_categories
      card = { 'title' => 'T', 'description' => 'D' }
      message = nil
      MixinBot::Blaze::Router.new { on 'app_card', ->(m) { message = m } }
                             .call envelope(category: 'APP_CARD', data: card.to_json)

      assert_equal card, message.data
    end

    def test_message_tolerates_missing_data_fields
      message = MixinBot::Blaze::Router::Message.new({ 'action' => 'CREATE_MESSAGE' }, api: MixinBot.api)

      assert_nil message.category
      assert_equal '', message.data
    end

    # ---- Reply over the HTTP message API ----

    def test_reply_posts_plain_text_via_http
      message = MixinBot::Blaze::Router::Message.new(envelope, api: MixinBot.api)
      message.reply('pong')

      assert_equal 1, @captured_bodies.size
      body = @captured_bodies.first
      assert_equal 'PLAIN_TEXT', body['category']
      assert_equal 'pong', Base64.decode64(body['data'])
      assert_equal 'user-1', body['recipient_id']
      assert_equal 'conv-1', body['conversation_id']
    end

    def test_base_handler_reply_delegates_to_message
      MixinBot::Blaze::Router.new { on 'text', PongHandler }.call envelope

      assert_equal 'pong', Base64.decode64(@captured_bodies.first['data'])
    end

    def test_reply_rejects_unsupported_category
      message = MixinBot::Blaze::Router::Message.new(envelope, api: MixinBot.api)

      error = assert_raises(MixinBot::ArgumentError) do
        message.reply('x', category: 'PLAIN_IMAGE')
      end

      assert_match(/unsupported reply category/, error.message)
    end

    # ---- Multi-bot binding ----

    def test_routers_send_replies_with_their_own_bot_credentials
      shop = MixinBot.register_bot(:router_shop, **registry_credentials('router-shop-app-id', 'shop'))
      vault = MixinBot.register_bot(:router_vault, **registry_credentials('router-vault-app-id', 'vault'))

      MixinBot::Blaze::Router.new(api: shop) { on 'text', ->(m) { m.reply('from shop') } }
                             .call envelope
      MixinBot::Blaze::Router.new(api: vault) { on 'text', ->(m) { m.reply('from vault') } }
                             .call envelope

      assert_equal 2, @captured_bodies.size
      assert_equal 'router-shop-app-id', jwt_uid(@captured_auth[0])
      assert_equal 'router-vault-app-id', jwt_uid(@captured_auth[1])
    end

    private

    def jwt_uid(authorization_header)
      jwt = authorization_header.delete_prefix('Bearer ')
      JSON.parse(Base64.urlsafe_decode64(jwt.split('.')[1]))['uid']
    end

    def registry_credentials(app_id, seed_suffix)
      session_seed = Digest::SHA256.digest("mixin_bot:test:registry:#{seed_suffix}:session")[0, 32]
      spend_seed = Digest::SHA256.digest("mixin_bot:test:registry:#{seed_suffix}:spend")[0, 32]
      session_kp = JOSE::JWA::Ed25519.keypair(session_seed)
      spend_kp = JOSE::JWA::Ed25519.keypair(spend_seed)

      {
        app_id:,
        session_id: app_id,
        session_private_key: session_kp[1].unpack1('H*'),
        server_public_key: session_kp[0].unpack1('H*'),
        spend_key: spend_kp[1].unpack1('H*')
      }
    end

    # ---- handler fixtures ----

    class RecordingHandler < MixinBot::Blaze::Router::Base
      class << self
        attr_accessor :handled
      end
      self.handled = []

      def handle
        self.class.handled << message.data
      end
    end

    class EchoHandler < MixinBot::Blaze::Router::Base
      def handle
        [message.data, message.conversation_id, message.user_id, message.category]
      end
    end

    class PongHandler < MixinBot::Blaze::Router::Base
      def handle
        reply('pong')
      end
    end

    class ExplodingHandler < MixinBot::Blaze::Router::Base
      class << self
        attr_accessor :handled
      end
      self.handled = []

      def handle
        self.class.handled << message.message_id
        raise 'kaboom' if message.message_id == 'boom'
      end
    end
  end
end
