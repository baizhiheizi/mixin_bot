# frozen_string_literal: true

require 'test_helper'

module MixinBot
  class TestMultisig < Minitest::Test
    include WebMock::API

    REQUEST_ID = '11259e74-1b6c-47dc-b08e-d3e4fe54fb74'
    RAW_HEX = '85a7abcdef' * 20
    ASSET_ID = '965e5c6e-434c-3fa9-b780-c50f43cd955c'

    # Two inputs that share the same senders (MixinBot.config.app_id) and threshold.
    # `create_multisig_raw_tx` requires every input to belong to the same senders
    # set and to use the same `receivers_threshold`; mismatched inputs cause
    # `build_safe_transaction` to raise before the raw transaction is encoded.
    SAMPLE_INPUTS = [
      {
        'transaction_hash' => 'ab' * 32,
        'output_index' => 0,
        'amount' => '0.5',
        'asset_id' => ASSET_ID,
        'receivers' => [MixinBot.config.app_id],
        'receivers_threshold' => 1,
        'state' => 'unspent'
      },
      {
        'transaction_hash' => 'cd' * 32,
        'output_index' => 1,
        'amount' => '0.5',
        'asset_id' => ASSET_ID,
        'receivers' => [MixinBot.config.app_id],
        'receivers_threshold' => 1,
        'state' => 'unspent'
      }
    ].freeze

    def setup
      WebMock.reset!
      MixinApiStubs.register!
    end

    def test_create_safe_multisig_request_posts_to_safe_multisigs_path
      MixinBot.api.create_safe_multisig_request(REQUEST_ID, RAW_HEX)
      assert_requested(:post, 'https://api.mixin.one/safe/multisigs', times: 1)
    end

    def test_create_safe_multisig_request_sends_array_body_with_request_id_and_raw
      MixinBot.api.create_safe_multisig_request(REQUEST_ID, RAW_HEX)
      assert_requested(
        :post,
        'https://api.mixin.one/safe/multisigs',
        body: [{ request_id: REQUEST_ID, raw: RAW_HEX }]
      )
    end

    def test_sign_safe_multisig_request_posts_to_sign_subpath
      MixinBot.api.sign_safe_multisig_request(REQUEST_ID, RAW_HEX)
      assert_requested(:post, "https://api.mixin.one/safe/multisigs/#{REQUEST_ID}/sign", times: 1)
    end

    def test_sign_safe_multisig_request_sends_raw_as_payload
      MixinBot.api.sign_safe_multisig_request(REQUEST_ID, RAW_HEX)
      assert_requested(
        :post,
        "https://api.mixin.one/safe/multisigs/#{REQUEST_ID}/sign",
        body: { raw: RAW_HEX }
      )
    end

    def test_unlock_safe_multisig_request_posts_to_unlock_subpath
      MixinBot.api.unlock_safe_multisig_request(REQUEST_ID)
      assert_requested(:post, "https://api.mixin.one/safe/multisigs/#{REQUEST_ID}/unlock", times: 1)
    end

    def test_safe_multisig_request_gets_request_by_id
      MixinBot.api.safe_multisig_request(REQUEST_ID)
      assert_requested(:get, "https://api.mixin.one/safe/multisigs/#{REQUEST_ID}", times: 1)
    end

    def test_fetch_safe_multisig_request_is_alias_for_safe_multisig_request
      MixinBot.api.fetch_safe_multisig_request(REQUEST_ID)
      assert_requested(:get, "https://api.mixin.one/safe/multisigs/#{REQUEST_ID}", times: 1)
    end

    def test_create_multisig_raw_tx_calls_safe_keys_endpoint
      trace_id = SecureRandom.uuid
      MixinBot.api.create_multisig_raw_tx(
        _asset_id: ASSET_ID,
        senders: [MixinBot.config.app_id],
        receivers: [TEST_UID],
        threshold: 1,
        inputs: SAMPLE_INPUTS,
        amount: '0.5',
        trace_id:
      )
      # `create_multisig_raw_tx` derives two ghost-key recipients (output + change)
      # and forwards them to `create_safe_keys` (POST /safe/keys).
      # `build_safe_transaction` then adds a third change recipient and calls
      # `create_safe_keys` again via `generate_safe_keys`, so the total is 2.
      assert_requested(:post, 'https://api.mixin.one/safe/keys', times: 2)
    end

    def test_create_multisig_raw_tx_returns_a_hex_string
      trace_id = SecureRandom.uuid
      raw = MixinBot.api.create_multisig_raw_tx(
        _asset_id: ASSET_ID,
        senders: [MixinBot.config.app_id],
        receivers: [TEST_UID],
        threshold: 1,
        inputs: SAMPLE_INPUTS,
        amount: '0.5',
        trace_id:
      )
      assert_kind_of String, raw
      assert_match(/\A[0-9a-f]+\z/, raw)
      # 0x7777 magic header — every Mixin transaction starts with the two-byte magic.
      assert raw.start_with?('7777'), "expected raw to start with 0x7777 magic, got: #{raw[0, 8]}"
    end

    def test_create_multisig_raw_tx_decodes_round_trip
      trace_id = SecureRandom.uuid
      raw = MixinBot.api.create_multisig_raw_tx(
        _asset_id: ASSET_ID,
        senders: [MixinBot.config.app_id],
        receivers: [TEST_UID],
        threshold: 1,
        inputs: SAMPLE_INPUTS,
        amount: '0.5',
        trace_id:
      )
      decoded = MixinBot.utils.decode_raw_transaction(raw)
      assert_kind_of Hash, decoded
      assert decoded[:inputs].is_a?(Array)
      assert_equal SAMPLE_INPUTS.size, decoded[:inputs].size
    end

    def test_create_multisig_raw_tx_propagates_extra_field
      trace_id = SecureRandom.uuid
      extra_value = 'test of extra'
      raw = MixinBot.api.create_multisig_raw_tx(
        _asset_id: ASSET_ID,
        senders: [MixinBot.config.app_id],
        receivers: [TEST_UID],
        threshold: 1,
        inputs: SAMPLE_INPUTS,
        amount: '0.5',
        trace_id:,
        extra: extra_value
      )
      decoded = MixinBot.utils.decode_raw_transaction(raw)
      # The encoder treats `extra` as raw bytes (no hex round-trip), so the
      # decoded `extra` field is the same string the caller passed in.
      assert_equal extra_value, decoded[:extra]
    end

    def test_create_multisig_raw_tx_default_extra_is_empty
      trace_id = SecureRandom.uuid
      raw = MixinBot.api.create_multisig_raw_tx(
        _asset_id: ASSET_ID,
        senders: [MixinBot.config.app_id],
        receivers: [TEST_UID],
        threshold: 1,
        inputs: SAMPLE_INPUTS,
        amount: '0.5',
        trace_id:
      )
      decoded = MixinBot.utils.decode_raw_transaction(raw)
      assert_equal '', decoded[:extra]
    end

    def test_create_multisig_raw_tx_coerces_amount_string
      # `create_multisig_raw_tx` calls `amount.to_s` to coerce numeric input,
      # so the test can pass an Integer (e.g. `1`) without raising.
      trace_id = SecureRandom.uuid
      raw = MixinBot.api.create_multisig_raw_tx(
        _asset_id: ASSET_ID,
        senders: [MixinBot.config.app_id],
        receivers: [TEST_UID],
        threshold: 1,
        inputs: SAMPLE_INPUTS,
        amount: 1,
        trace_id:
      )
      assert_kind_of String, raw
      assert raw.length.positive?
    end
  end
end
