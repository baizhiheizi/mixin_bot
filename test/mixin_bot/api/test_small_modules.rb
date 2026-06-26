# frozen_string_literal: true

require 'test_helper'

module MixinBot
  ##
  # Offline unit tests for the small, single-method API modules that are not
  # yet covered by a dedicated test file:
  #
  #   - +Address+    — +safe_deposit_entries+
  #   - +Fiat+       — +fiats+ / +get_fiats+
  #   - +Turn+       — +turn_servers+ / +get_turn_server+
  #   - +Session+    — +fetch_user_sessions+ / +fetch_user_session+
  #   - +Deposit+    — +pending_safe_deposits+ / +fetch_pending_safe_deposits+
  #   - +PinPayload+ — +tip_or_legacy_pin_payload+ (private helper)
  #
  # These exercises are kept offline because all endpoints involved are already
  # covered by the default +MixinApiStubs.register!+ stub set (or fall through
  # to the +{}+ default), and +PinPayload+ is a pure helper that depends only
  # on the locally configured session keys.
  #
  class TestSmallModules < Minitest::Test
    include WebMock::API

    def setup
      WebMock.reset!
      MixinApiStubs.register!
    end

    # ===== Address =========================================================

    def test_safe_deposit_entries_wraps_string_members_into_array
      MixinBot.api.safe_deposit_entries(
        members: TEST_UID,
        threshold: 2,
        chain_id: ETH_ASSET_ID,
        access_token: 'tok'
      )

      assert_requested(:post, 'https://api.mixin.one/safe/deposit/entries') do |req|
        body = MixinApiStubs.parse_json_body(req)
        body.is_a?(Hash) &&
          body['members'] == [TEST_UID] &&
          body['threshold'] == 2 &&
          body['chain_id'] == ETH_ASSET_ID
      end
    end

    def test_safe_deposit_entries_preserves_array_members
      members = [TEST_UID, TEST_UID_2]
      MixinBot.api.safe_deposit_entries(
        members:,
        threshold: 1,
        chain_id: CNB_ASSET_ID
      )

      assert_requested(:post, 'https://api.mixin.one/safe/deposit/entries') do |req|
        body = MixinApiStubs.parse_json_body(req)
        body.is_a?(Hash) && body['members'] == members && body['chain_id'] == CNB_ASSET_ID
      end
    end

    def test_safe_deposit_entries_defaults_threshold_to_one_when_omitted
      MixinBot.api.safe_deposit_entries(members: [TEST_UID], chain_id: CNB_ASSET_ID)

      assert_requested(:post, 'https://api.mixin.one/safe/deposit/entries') do |req|
        body = MixinApiStubs.parse_json_body(req)
        body.is_a?(Hash) && body['threshold'] == 1
      end
    end

    # ===== Fiat ============================================================

    def test_fiats_returns_stub_data
      res = MixinBot.api.fiats

      assert_kind_of Array, res['data']
    end

    def test_fiats_hits_external_fiats_path
      MixinBot.api.fiats
      assert_requested :get, 'https://api.mixin.one/external/fiats'
    end

    def test_get_fiats_is_alias_for_fiats
      assert_equal MixinBot.api.fiats, MixinBot.api.get_fiats
    end

    # ===== Turn ============================================================

    def test_turn_servers_returns_stub_data
      res = MixinBot.api.turn_servers

      assert_kind_of Array, res['data']
      refute_empty res['data']
    end

    def test_turn_servers_hits_turn_path
      MixinBot.api.turn_servers
      assert_requested :get, 'https://api.mixin.one/turn'
    end

    def test_get_turn_server_is_alias_for_turn_servers
      assert_equal MixinBot.api.turn_servers, MixinBot.api.get_turn_server
    end

    # ===== Session =========================================================

    def test_fetch_user_sessions_returns_stub_data
      res = MixinBot.api.fetch_user_sessions([TEST_UID, TEST_UID_2])

      assert_kind_of Array, res['data']
    end

    def test_fetch_user_sessions_hits_sessions_fetch_path
      MixinBot.api.fetch_user_sessions([TEST_UID])
      assert_requested :post, 'https://api.mixin.one/sessions/fetch'
    end

    def test_fetch_user_sessions_posts_user_id_array_as_body
      MixinBot.api.fetch_user_sessions([TEST_UID, TEST_UID_2])

      assert_requested(:post, 'https://api.mixin.one/sessions/fetch') do |req|
        body = MixinApiStubs.parse_json_body(req)
        body == [TEST_UID, TEST_UID_2]
      end
    end

    def test_fetch_user_sessions_coerces_single_string_into_array
      MixinBot.api.fetch_user_sessions(TEST_UID)

      assert_requested(:post, 'https://api.mixin.one/sessions/fetch') do |req|
        body = MixinApiStubs.parse_json_body(req)
        body == [TEST_UID]
      end
    end

    def test_fetch_user_sessions_raises_on_blank_input
      assert_raises(ArgumentError) { MixinBot.api.fetch_user_sessions('') }
      assert_raises(ArgumentError) { MixinBot.api.fetch_user_sessions(nil) }
      assert_raises(ArgumentError) { MixinBot.api.fetch_user_sessions([]) }
    end

    def test_fetch_user_session_is_alias_for_fetch_user_sessions
      assert_equal MixinBot.api.fetch_user_sessions([TEST_UID]),
                   MixinBot.api.fetch_user_session([TEST_UID])
    end

    # ===== Deposit =========================================================

    def test_pending_safe_deposits_returns_stub_data
      res = MixinBot.api.pending_safe_deposits

      assert_kind_of Array, res['data']
    end

    def test_pending_safe_deposits_hits_safe_deposits_path
      MixinBot.api.pending_safe_deposits
      assert_requested :get, 'https://api.mixin.one/safe/deposits'
    end

    def test_pending_safe_deposits_passes_only_supplied_query_params
      MixinBot.api.pending_safe_deposits(asset: CNB_ASSET_ID, limit: 10, offset: 5)

      assert_requested(:get, %r{\Ahttps://api\.mixin\.one/safe/deposits\?}) do |req|
        # +.compact+ means omitted kwargs must NOT appear in the query string.
        uri = URI(req.uri)
        params = URI.decode_www_form(uri.query.to_s).to_h
        params == { 'asset' => CNB_ASSET_ID, 'limit' => '10', 'offset' => '5' }
      end
    end

    def test_pending_safe_deposits_compacts_away_nil_query_params
      MixinBot.api.pending_safe_deposits(asset: CNB_ASSET_ID, limit: nil, offset: nil, destination: nil, tag: nil)

      assert_requested(:get, %r{\Ahttps://api\.mixin\.one/safe/deposits\?}) do |req|
        uri = URI(req.uri)
        params = URI.decode_www_form(uri.query.to_s).to_h
        params == { 'asset' => CNB_ASSET_ID }
      end
    end

    def test_pending_safe_deposits_supports_destination_and_tag
      MixinBot.api.pending_safe_deposits(destination: 'dest-id', tag: 'tag-id')

      assert_requested(:get, %r{\Ahttps://api\.mixin\.one/safe/deposits\?}) do |req|
        uri = URI(req.uri)
        params = URI.decode_www_form(uri.query.to_s).to_h
        params == { 'destination' => 'dest-id', 'tag' => 'tag-id' }
      end
    end

    def test_fetch_pending_safe_deposits_is_alias_for_pending_safe_deposits
      assert_equal MixinBot.api.pending_safe_deposits(asset: CNB_ASSET_ID),
                   MixinBot.api.fetch_pending_safe_deposits(asset: CNB_ASSET_ID)
    end

    # ===== PinPayload ======================================================

    def test_tip_or_legacy_pin_payload_raises_for_blank_pin
      assert_raises(ArgumentError) do
        MixinBot.api.send(:tip_or_legacy_pin_payload, '', 'TIP:VERIFY:', '0' * 32)
      end
      assert_raises(ArgumentError) do
        MixinBot.api.send(:tip_or_legacy_pin_payload, nil, 'TIP:VERIFY:', '0' * 32)
      end
    end

    def test_tip_or_legacy_pin_payload_returns_pin_key_for_six_digit_pin
      # tip_action is required by the helper signature even though the 6-digit
      # branch never reads it.
      payload = MixinBot.api.send(:tip_or_legacy_pin_payload, '123456', 'TIP:VERIFY:')

      assert_equal %i[pin], payload.keys
      assert_kind_of String, payload[:pin]
      refute_empty payload[:pin]
    end

    def test_tip_or_legacy_pin_payload_returns_pin_base64_for_long_pin
      # A 128-char (64-byte) Ed25519 secret key — the smallest form
      # +decode_key+ passes through to +JOSE::JWA::Ed25519.sign+.
      pin_key = OfflineConfig.session_private_key_hex
      payload = MixinBot.api.send(:tip_or_legacy_pin_payload, pin_key, 'TIP:VERIFY:', '0' * 32)

      assert_equal %i[pin_base64], payload.keys
      assert_kind_of String, payload[:pin_base64]
      refute_empty payload[:pin_base64]
    end

    def test_tip_or_legacy_pin_payload_length_boundary_is_strictly_greater_than_six
      # Any pin with length > 6 takes the TIP / pin_base64 branch.
      pin_key = OfflineConfig.session_private_key_hex
      payload = MixinBot.api.send(:tip_or_legacy_pin_payload, pin_key, 'TIP:VERIFY:', '0' * 32)
      assert payload.key?(:pin_base64), 'expected long pin to use the pin_base64 branch'
    end
  end
end
