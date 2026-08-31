# frozen_string_literal: true

require 'test_helper'

module MixinBot
  class TestEncrtypedMessage < Minitest::Test
    include WebMock::API

    def setup
      WebMock.reset!
      MixinApiStubs.register!
    end

    def test_encrypt_and_decrypt_message
      recipient_key = JOSE::JWA::Ed25519.keypair
      recipient_session_id = SecureRandom.uuid
      recipient_user_id = SecureRandom.uuid

      sender_key = JOSE::JWA::Ed25519.keypair
      sender_session_id = SecureRandom.uuid
      sender_user_id = SecureRandom.uuid

      sessions = [
        {
          'user_id' => recipient_user_id,
          'session_id' => recipient_session_id,
          'public_key' => Base64.urlsafe_encode64(JOSE::JWA::Ed25519.pk_to_curve25519(recipient_key[0]))
        },
        {
          'user_id' => sender_user_id,
          'session_id' => sender_session_id,
          'public_key' => Base64.urlsafe_encode64(JOSE::JWA::Ed25519.pk_to_curve25519(sender_key[0]))
        }
      ]

      msg = 'hello world'

      encoded_msg = Base64.urlsafe_encode64(msg)
      encrypted_msg = MixinBot.api.encrypt_message(encoded_msg, sessions, sk: sender_key[1][0...32], pk: sender_key[0])
      refute_nil encrypted_msg

      decrypted_msg = MixinBot.api.decrypt_message(encrypted_msg, sk: recipient_key[1][0...32], si: recipient_session_id)
      decoded_msg = Base64.urlsafe_decode64(decrypted_msg)
      assert_equal msg, decoded_msg
    end

    def test_send_encrypted_text_message
      recipient_id = TEST_UID
      conversation_id = MixinBot.api.unique_uuid(recipient_id)
      conversation = MixinBot.api.create_contact_conversation recipient_id
      sessions = conversation['participant_sessions'].filter(&->(s) { s['user_id'] == recipient_id })

      r =
        MixinBot
        .api
        .send_encrypted_text_message(
          recipient_id:,
          conversation_id:,
          data: 'Hello world',
          sessions:
        )

      assert_equal r['data']['state'], 'SUCCESS'
    end

    # ---------------------------------------------------------------------------
    # post_encrypted_messages pipeline
    # ---------------------------------------------------------------------------

    RecordingStore = Class.new do
      attr_reader :fetched, :stored

      def initialize(sessions = {})
        @sessions = sessions
        @fetched = []
        @stored = []
      end

      def fetch(user_id)
        @fetched << user_id
        @sessions[user_id]
      end

      def store(user_id, sessions)
        @stored << [user_id, sessions]
        @sessions[user_id] = sessions
      end
    end

    def make_sessions(user_id)
      keypair = JOSE::JWA::Ed25519.keypair
      [
        {
          'user_id' => user_id,
          'session_id' => SecureRandom.uuid,
          'public_key' => Base64.urlsafe_encode64(JOSE::JWA::Ed25519.pk_to_curve25519(keypair[0]), padding: false)
        }
      ]
    end

    def stub_sessions_fetch(sessions_by_user)
      stub_request(:post, 'https://api.mixin.one/sessions/fetch').to_return do |request|
        requested = JSON.parse(request.body)
        list = requested.flat_map { |uid| sessions_by_user[uid] || [] }
        { status: 200, headers: { 'Content-Type' => 'application/json' },
          body: JSON.generate({ 'data' => list, 'error' => nil }) }
      end
    end

    def stub_encrypted_messages(*state_sequences)
      captured = []
      stub_request(:post, 'https://api.mixin.one/encrypted_messages').to_return do |request|
        captured << JSON.parse(request.body)
        states = state_sequences.fetch(captured.size - 1)
        { status: 200, headers: { 'Content-Type' => 'application/json' },
          body: JSON.generate({ 'data' => states, 'error' => nil }) }
      end
      captured
    end

    def response_entry(message_id, recipient_id, state)
      { 'type' => 'encrypted_message', 'message_id' => message_id,
        'recipient_id' => recipient_id, 'state' => state }
    end

    def test_post_encrypted_messages_fetches_sessions_and_posts_encrypted_payload
      recipient_id = SecureRandom.uuid
      message_id = SecureRandom.uuid
      sessions = make_sessions(recipient_id)
      stub_sessions_fetch(recipient_id => sessions)
      captured_posts = stub_encrypted_messages([response_entry(message_id, recipient_id, 'SUCCESS')])

      r = MixinBot.api.post_encrypted_messages({
                                                 recipient_id:,
                                                 conversation_id: MixinBot.api.unique_uuid(recipient_id),
                                                 category: 'ENCRYPTED_TEXT',
                                                 data: 'hello pipeline',
                                                 message_id:
                                               })

      assert_requested :post, 'https://api.mixin.one/sessions/fetch'
      assert_requested :post, 'https://api.mixin.one/encrypted_messages'
      assert_equal 'SUCCESS', r['data'].first['state']

      assert_equal 1, captured_posts.size
      entry = captured_posts.first.first
      assert_equal message_id, entry['message_id']
      assert_equal recipient_id, entry['recipient_id']
      assert entry['checksum'].present?
      assert_equal sessions.map { |s| s['session_id'] }.sort,
                   entry['recipient_sessions'].map { |s| s['session_id'] }.sort
      refute_equal Base64.urlsafe_encode64('hello pipeline', padding: false), entry['data_base64'],
                   'payload must be encrypted, not the plaintext base64'
    end

    def test_post_encrypted_messages_reuses_cached_sessions
      recipient_id = SecureRandom.uuid
      message_id = SecureRandom.uuid
      store = MixinBot::SessionStore.new
      store.store(recipient_id, make_sessions(recipient_id))
      stub_encrypted_messages([response_entry(message_id, recipient_id, 'SUCCESS')])

      MixinBot.api.post_encrypted_messages(
        [{ recipient_id:, category: 'ENCRYPTED_TEXT', data: 'hi', message_id: }],
        session_store: store
      )

      assert_not_requested :post, 'https://api.mixin.one/sessions/fetch'
      assert_requested :post, 'https://api.mixin.one/encrypted_messages'
    end

    def test_post_encrypted_messages_retries_once_after_session_expiry
      recipient_id = SecureRandom.uuid
      message_id = SecureRandom.uuid
      stub_sessions_fetch(recipient_id => make_sessions(recipient_id))
      stub_encrypted_messages(
        [response_entry(message_id, recipient_id, 'FAILED')],
        [response_entry(message_id, recipient_id, 'SUCCESS')]
      )

      r = MixinBot.api.post_encrypted_messages(
        [{ recipient_id:, category: 'ENCRYPTED_TEXT', data: 'retry me', message_id: }]
      )

      assert_requested :post, 'https://api.mixin.one/sessions/fetch', times: 2
      assert_requested :post, 'https://api.mixin.one/encrypted_messages', times: 2
      assert_equal 'SUCCESS', r['data'].first['state']
    end

    def test_post_encrypted_messages_reports_failed_after_single_retry
      recipient_id = SecureRandom.uuid
      message_id = SecureRandom.uuid
      stub_sessions_fetch(recipient_id => make_sessions(recipient_id))
      stub_encrypted_messages(
        [response_entry(message_id, recipient_id, 'FAILED')],
        [response_entry(message_id, recipient_id, 'FAILED')]
      )

      r = MixinBot.api.post_encrypted_messages(
        [{ recipient_id:, category: 'ENCRYPTED_TEXT', data: 'still failing', message_id: }]
      )

      assert_requested :post, 'https://api.mixin.one/sessions/fetch', times: 2
      assert_requested :post, 'https://api.mixin.one/encrypted_messages', times: 2
      assert_equal 'FAILED', r['data'].first['state']
    end

    def test_post_encrypted_messages_uses_custom_session_store
      recipient_id = SecureRandom.uuid
      message_id = SecureRandom.uuid
      cached = make_sessions(recipient_id)
      store = RecordingStore.new(recipient_id => cached)
      stub_encrypted_messages([response_entry(message_id, recipient_id, 'SUCCESS')])

      MixinBot.api.post_encrypted_messages(
        [{ recipient_id:, category: 'ENCRYPTED_TEXT', data: 'custom store', message_id: }],
        session_store: store
      )

      assert_equal [recipient_id], store.fetched
      assert_not_requested :post, 'https://api.mixin.one/sessions/fetch'
      assert_requested :post, 'https://api.mixin.one/encrypted_messages'
    end

    def test_post_encrypted_messages_stores_fetched_sessions
      recipient_id = SecureRandom.uuid
      message_id = SecureRandom.uuid
      sessions = make_sessions(recipient_id)
      store = RecordingStore.new
      stub_sessions_fetch(recipient_id => sessions)
      stub_encrypted_messages([response_entry(message_id, recipient_id, 'SUCCESS')])

      MixinBot.api.post_encrypted_messages(
        [{ recipient_id:, category: 'ENCRYPTED_TEXT', data: 'remember me', message_id: }],
        session_store: store
      )

      assert_equal [[recipient_id, sessions]], store.stored
    end
  end
end
