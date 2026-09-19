# frozen_string_literal: true

require 'test_helper'
require 'mixin_bot/rails'
require 'json'

module MixinBot
  class NotificationsMixinChannelTest < Minitest::Test
    include WebMock::API

    CHANNEL_FILE = File.expand_path('../../../lib/mixin_bot/notifications/mixin_channel.rb', __dir__)

    # Minimal double of the Noticed channel surface the adapter pins to:
    # construction with (recipient:, notification:, params:) + #deliver.
    module NoticedDouble
      class Channel
        attr_reader :recipient, :notification, :params

        def initialize(recipient:, notification:, params: {})
          @recipient = recipient
          @notification = notification
          @params = params || {}
        end
      end
    end

    class FakeNotification
      attr_reader :params

      def initialize(params: {}, recipient: nil, message: nil, with_recipient: true)
        @params = params
        @recipient = recipient
        @message = message
        # Only attaches #mixin_recipient when the notification class provides
        # it — the channel must fall back otherwise.
        define_singleton_method(:mixin_recipient) { 'notif-recipient' } if with_recipient
      end

      def mixin_message
        @message
      end
    end

    class UserRecord
      def mixin_user_id
        'record-recipient'
      end
    end

    def setup
      super
      raise 'Noticed double missing' unless defined?(NoticedDouble)

      Object.const_set(:Noticed, NoticedDouble) unless Object.const_defined?(:Noticed)
      # Re-evaluate the channel against the double (require would be a no-op
      # when another test file already loaded the integration layer).
      load CHANNEL_FILE
      @captured = []
      @auth_header = nil
      @message_stub = stub_request(:post, 'https://api.mixin.one/messages').to_return do |request|
        @captured << JSON.parse(request.body)
        @auth_header = request.headers['Authorization']
        { status: 200, headers: { 'Content-Type' => 'application/json' },
          body: JSON.generate({ 'data' => { 'message_id' => 'ack' }, 'error' => nil }) }
      end
    end

    def teardown
      remove_request_stub(@message_stub)
      super
    end

    def channel(notification, recipient: nil, params: {})
      MixinBot::Notifications::MixinChannel.new(recipient:, notification:, params:)
    end

    def test_delivers_plain_text_to_the_notification_recipient
      notification = FakeNotification.new(
        message: { category: 'PLAIN_TEXT', content: 'payment received' }
      )

      channel(notification).deliver

      assert_equal 1, @captured.size
      body = @captured.first
      assert_equal 'PLAIN_TEXT', body['category']
      assert_equal 'payment received', Base64.decode64(body['data'])
      assert_equal 'notif-recipient', body['recipient_id']
    end

    def test_falls_back_to_the_recipient_record_mixin_id
      notification = FakeNotification.new(
        with_recipient: false,
        message: { category: 'PLAIN_TEXT', content: 'hi' }
      )

      channel(notification, recipient: UserRecord.new).deliver

      assert_equal 'record-recipient', @captured.first['recipient_id']
    end

    def test_delivers_app_card_messages
      card = { 'title' => 'T', 'description' => 'D', 'action' => 'https://example.com' }
      notification = FakeNotification.new(
        message: { category: 'APP_CARD', card: }
      )

      channel(notification).deliver

      body = @captured.first
      assert_equal 'APP_CARD', body['category']
      assert_equal card, JSON.parse(Base64.decode64(body['data']))
    end

    def test_unresolvable_recipient_raises_for_noticed_to_capture
      notification = FakeNotification.new(
        with_recipient: false,
        message: { category: 'PLAIN_TEXT', content: 'hi' }
      )

      error = assert_raises(MixinBot::ArgumentError) do
        channel(notification).deliver
      end

      assert_match(/could not resolve a Mixin recipient/, error.message)
      assert_empty @captured
    end

    def test_channel_uses_the_bot_named_in_params
      shop = MixinBot.register_bot(:channel_shop, **registry_credentials('channel-shop-app-id', 'shop'))
      notification = FakeNotification.new(message: { category: 'PLAIN_TEXT', content: 'from shop' })

      channel(notification, params: { bot: :channel_shop }).deliver

      jwt = @auth_header.delete_prefix('Bearer ')
      uid = JSON.parse(Base64.urlsafe_decode64(jwt.split('.')[1]))['uid']
      assert_equal 'channel-shop-app-id', uid
      assert_same shop, MixinBot.bot(:channel_shop)
    end

    private

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
  end
end
