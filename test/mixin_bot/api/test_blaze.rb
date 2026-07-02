# frozen_string_literal: true

require 'test_helper'

module MixinBot
  ##
  # Offline unit tests for +MixinBot::API::Blaze+ — the seven +blaze_send_*+
  # helpers that publish messages over an already-open Blaze WebSocket.
  #
  # The +start_blaze_connect+ / +blaze+ entry points need Faye::WebSocket
  # + EventMachine and are out of scope here; the helpers below only depend
  # on +MixinBot::API::Message#write_ws_message+ (+ Base64 + JSON + UUID), so
  # they can be exercised byte-for-byte by stubbing the socket.
  #
  # The wire format under test: every +blaze_send_*+ emits a gzip-compressed
  # JSON envelope of shape
  #   { id: <uuid>, action: "CREATE_MESSAGE", params: { conversation_id: …,
  #     recipient_id: …, message_id: <uuid>, category: …, data_base64: … } }
  # The +data_base64+ payload is +Base64.urlsafe_encode64(json_data, padding: false)+
  # for the structured-message helpers, or +Base64.urlsafe_encode64(content,
  # padding: false)+ for plain text.
  class TestBlaze < Minitest::Test
    CONV = '00000000-0000-0000-0000-000000000001'
    RECIPIENT = '00000000-0000-0000-0000-000000000002'
    UUID_PATTERN = /\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i.freeze

    # Captures everything +.send+ hands it, then returns self so the helpers
    # can chain. +sent+ holds the raw byte arrays exactly as +write_ws_message+
    # produced them; +envelopes+ holds the decoded JSON for assertions.
    class FakeSocket
      attr_reader :sent, :envelopes

      def initialize(api)
        @api = api
        @sent = []
        @envelopes = []
      end

      def send(bytes)
        @sent << bytes
        @envelopes << JSON.parse(@api.ws_message(bytes))
        self
      end
    end

    def setup
      OfflineConfig.apply!
      @socket = FakeSocket.new(MixinBot.api)
    end

    # =================================================================
    # blaze_send_plain_text
    # =================================================================

    def test_plain_text_sends_a_create_message_envelope
      MixinBot.api.blaze_send_plain_text(
        @socket,
        conversation_id: CONV,
        recipient_id: RECIPIENT,
        content: 'hello'
      )

      assert_equal 1, @socket.envelopes.length
      env = @socket.envelopes.first

      assert_equal 'CREATE_MESSAGE', env['action']
      assert_match UUID_PATTERN, env['id']

      params = env['params']
      assert_equal CONV, params['conversation_id']
      assert_equal RECIPIENT, params['recipient_id']
      assert_match UUID_PATTERN, params['message_id']
      assert_equal 'PLAIN_TEXT', params['category']

      decoded = Base64.urlsafe_decode64(params['data_base64'])
      assert_equal 'hello', decoded
    end

    def test_plain_text_coerces_non_string_content_to_string
      MixinBot.api.blaze_send_plain_text(
        @socket,
        conversation_id: CONV,
        recipient_id: RECIPIENT,
        content: 42
      )

      decoded = Base64.urlsafe_decode64(@socket.envelopes.first['params']['data_base64'])
      assert_equal '42', decoded
    end

    def test_plain_text_emits_a_fresh_message_id_per_call
      MixinBot.api.blaze_send_plain_text(
        @socket,
        conversation_id: CONV,
        recipient_id: RECIPIENT,
        content: 'a'
      )
      MixinBot.api.blaze_send_plain_text(
        @socket,
        conversation_id: CONV,
        recipient_id: RECIPIENT,
        content: 'b'
      )

      ids = @socket.envelopes.map { |e| e['params']['message_id'] }
      refute_equal ids[0], ids[1]
    end

    def test_plain_text_payload_is_urlsafe_base64_without_padding
      MixinBot.api.blaze_send_plain_text(
        @socket,
        conversation_id: CONV,
        recipient_id: RECIPIENT,
        content: 'pad?'
      )

      data_b64 = @socket.envelopes.first['params']['data_base64']
      refute_includes data_b64, '='
      # urlsafe alphabet uses '-' / '_' instead of '+' / '/'.
      assert_equal Base64.urlsafe_encode64('pad?', padding: false), data_b64
    end

    # =================================================================
    # blaze_send_post — documented as an alias of blaze_send_plain_text
    # =================================================================

    def test_post_payload_is_byte_equivalent_to_plain_text
      MixinBot.api.blaze_send_plain_text(
        @socket,
        conversation_id: CONV,
        recipient_id: RECIPIENT,
        content: 'a post'
      )
      MixinBot.api.blaze_send_post(
        @socket,
        conversation_id: CONV,
        recipient_id: RECIPIENT,
        content: 'a post'
      )

      # Each call gets a fresh envelope + message UUID, so the envelopes are
      # not whole-object equal; but the JSON payload + category + base64
      # body must be identical.
      e0 = @socket.envelopes[0]['params']
      e1 = @socket.envelopes[1]['params']
      assert_equal e0['category'], e1['category']
      assert_equal e0['data_base64'], e1['data_base64']
      assert_equal e0['conversation_id'], e1['conversation_id']
      assert_equal e0['recipient_id'], e1['recipient_id']
    end

    # =================================================================
    # blaze_send_recall_message
    # =================================================================

    def test_recall_wraps_message_id_in_json_data
      MixinBot.api.blaze_send_recall_message(
        @socket,
        conversation_id: CONV,
        recipient_id: RECIPIENT,
        message_id: 'recalled-message-uuid'
      )

      params = @socket.envelopes.first['params']
      assert_equal 'MESSAGE_RECALL', params['category']

      decoded = Base64.urlsafe_decode64(params['data_base64'])
      assert_equal({ 'message_id' => 'recalled-message-uuid' }, JSON.parse(decoded))
    end

    def test_recall_envelope_message_id_differs_from_recalled_id
      MixinBot.api.blaze_send_recall_message(
        @socket,
        conversation_id: CONV,
        recipient_id: RECIPIENT,
        message_id: 'recalled-message-uuid'
      )

      params = @socket.envelopes.first['params']
      # The envelope's message_id is a fresh UUID for the RECALL action itself,
      # not the recalled message — caller passes the recalled id in `data`.
      refute_equal 'recalled-message-uuid', params['message_id']
      assert_match UUID_PATTERN, params['message_id']
    end

    # =================================================================
    # blaze_send_contact
    # =================================================================

    def test_contact_wraps_user_id_in_json_data
      MixinBot.api.blaze_send_contact(
        @socket,
        conversation_id: CONV,
        recipient_id: RECIPIENT,
        contact_id: TEST_UID_2
      )

      params = @socket.envelopes.first['params']
      assert_equal 'PLAIN_CONTACT', params['category']

      decoded = Base64.urlsafe_decode64(params['data_base64'])
      assert_equal({ 'user_id' => TEST_UID_2 }, JSON.parse(decoded))
    end

    # =================================================================
    # blaze_send_app_card
    # =================================================================

    def test_app_card_packs_all_four_fields_into_json_data
      MixinBot.api.blaze_send_app_card(
        @socket,
        conversation_id: CONV,
        recipient_id: RECIPIENT,
        title: 'T',
        description: 'D',
        action: 'https://example.com/x',
        icon_url: 'https://example.com/i.png'
      )

      params = @socket.envelopes.first['params']
      assert_equal 'APP_CARD', params['category']

      decoded = Base64.urlsafe_decode64(params['data_base64'])
      assert_equal(
        {
          'title' => 'T',
          'description' => 'D',
          'action' => 'https://example.com/x',
          'icon_url' => 'https://example.com/i.png'
        },
        JSON.parse(decoded)
      )
    end

    def test_app_card_preserves_field_order_in_json
      MixinBot.api.blaze_send_app_card(
        @socket,
        conversation_id: CONV,
        recipient_id: RECIPIENT,
        title: 'T',
        description: 'D',
        action: 'A',
        icon_url: 'I'
      )

      decoded = Base64.urlsafe_decode64(@socket.envelopes.first['params']['data_base64'])
      # +Hash#to_json+ preserves insertion order in modern Ruby; the helper
      # builds the hash in keyword order so the on-wire JSON keys follow.
      assert_equal %w[title description action icon_url], JSON.parse(decoded).keys
    end

    # =================================================================
    # blaze_send_app_button (single-button form)
    # =================================================================

    def test_app_button_wraps_a_single_button_array_in_json_data
      MixinBot.api.blaze_send_app_button(
        @socket,
        conversation_id: CONV,
        recipient_id: RECIPIENT,
        label: 'Tap',
        action: 'https://example.com/x',
        color: '#FF0000'
      )

      params = @socket.envelopes.first['params']
      assert_equal 'APP_BUTTON_GROUP', params['category']

      decoded = Base64.urlsafe_decode64(params['data_base64'])
      assert_equal(
        [{ 'label' => 'Tap', 'action' => 'https://example.com/x', 'color' => '#FF0000' }],
        JSON.parse(decoded)
      )
    end

    # =================================================================
    # blaze_send_group_app_button (multi-button form)
    # =================================================================

    def test_group_app_button_emits_buttons_array_verbatim
      buttons = [
        { label: 'Yes', action: 'yes',  color: '#0F0' },
        { label: 'No',  action: 'no',   color: '#F00' }
      ]
      MixinBot.api.blaze_send_group_app_button(
        @socket,
        conversation_id: CONV,
        recipient_id: RECIPIENT,
        buttons: buttons
      )

      params = @socket.envelopes.first['params']
      assert_equal 'APP_BUTTON_GROUP', params['category']

      decoded = Base64.urlsafe_decode64(params['data_base64'])
      expected = buttons.map { |b| b.transform_keys(&:to_s) }
      assert_equal expected, JSON.parse(decoded)
    end

    def test_group_app_button_uses_same_category_as_single_button_form
      MixinBot.api.blaze_send_app_button(
        @socket, conversation_id: CONV, recipient_id: RECIPIENT,
        label: 'a', action: 'a', color: '#000'
      )
      MixinBot.api.blaze_send_group_app_button(
        @socket, conversation_id: CONV, recipient_id: RECIPIENT,
        buttons: [{ label: 'b', action: 'b', color: '#000' }]
      )

      cats = @socket.envelopes.map { |e| e['params']['category'] }
      assert_equal %w[APP_BUTTON_GROUP APP_BUTTON_GROUP], cats
    end

    # =================================================================
    # Wire-format invariants shared by every helper
    # =================================================================

    def test_every_helper_emits_a_gzipped_byte_array
      helpers = %i[
        blaze_send_plain_text
        blaze_send_recall_message
        blaze_send_contact
        blaze_send_app_card
        blaze_send_app_button
        blaze_send_group_app_button
      ]

      helpers.each do |m|
        args = base_args_for(m)
        MixinBot.api.public_send(m, @socket, **args)
      end

      assert_equal helpers.length, @socket.sent.length
      @socket.sent.each do |bytes|
        assert_kind_of Array, bytes
        # +write_ws_message+ uses +io.string.unpack('c*')+ which yields
        # signed 8-bit integers (-128..127). Faye::WebSocket repacks to
        # unsigned on the wire, but the in-memory shape is signed.
        assert(bytes.all? { |b| b.is_a?(Integer) && b.between?(-128, 127) },
               'every byte must be an 8-bit integer (signed)')
        # Sanity: gzip magic number (0x1f 0x8b) is the first two bytes.
        assert_equal [0x1f, -117], bytes[0, 2]
      end
    end

    def test_every_helper_uses_create_message_action
      helpers = %i[
        blaze_send_plain_text
        blaze_send_recall_message
        blaze_send_contact
        blaze_send_app_card
        blaze_send_app_button
        blaze_send_group_app_button
      ]

      helpers.each do |m|
        MixinBot.api.public_send(m, @socket, **base_args_for(m))
      end

      actions = @socket.envelopes.map { |e| e['action'] }
      assert helpers.length.times.all? { |i| actions[i] == 'CREATE_MESSAGE' },
             "all helpers must use action=CREATE_MESSAGE, got #{actions.inspect}"
    end

    def test_every_helper_assigns_a_unique_envelope_id
      helpers = %i[
        blaze_send_plain_text
        blaze_send_recall_message
        blaze_send_contact
        blaze_send_app_card
        blaze_send_app_button
        blaze_send_group_app_button
      ]

      helpers.each do |m|
        MixinBot.api.public_send(m, @socket, **base_args_for(m))
      end

      ids = @socket.envelopes.map { |e| e['id'] }
      assert_equal ids.uniq.length, ids.length, 'each call should mint a fresh envelope id'
      ids.each { |id| assert_match UUID_PATTERN, id }
    end

    private

    # Per-helper argument map for the invariant tests above.
    def base_args_for(helper)
      {
        blaze_send_plain_text: {
          conversation_id: CONV, recipient_id: RECIPIENT, content: 'hi'
        },
        blaze_send_recall_message: {
          conversation_id: CONV, recipient_id: RECIPIENT, message_id: 'mid'
        },
        blaze_send_contact: {
          conversation_id: CONV, recipient_id: RECIPIENT, contact_id: TEST_UID_2
        },
        blaze_send_app_card: {
          conversation_id: CONV, recipient_id: RECIPIENT,
          title: 't', description: 'd', action: 'a', icon_url: 'i'
        },
        blaze_send_app_button: {
          conversation_id: CONV, recipient_id: RECIPIENT,
          label: 'l', action: 'a', color: '#000'
        },
        blaze_send_group_app_button: {
          conversation_id: CONV, recipient_id: RECIPIENT,
          buttons: [{ label: 'l', action: 'a', color: '#000' }]
        }
      }[helper]
    end
  end
end