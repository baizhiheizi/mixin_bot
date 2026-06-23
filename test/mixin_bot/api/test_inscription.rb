# frozen_string_literal: true

require 'test_helper'

module MixinBot
  class TestInscription < Minitest::Test
    include WebMock::API

    # Arbitrary 64-char hex strings to exercise the URL-path builders.
    COLLECTION_HASH = 'aa' * 32
    COLLECTIBLE_HASH = 'bb' * 32

    def setup
      WebMock.reset!
      MixinApiStubs.register!
    end

    def teardown
      WebMock.reset!
      MixinApiStubs.register!
    end

    # --- URL path construction (Safe inscriptions endpoints) ---

    def test_collection_uses_safe_inscriptions_collections_endpoint
      MixinBot.api.collection(COLLECTION_HASH)
      assert_requested :get,
                       "https://api.mixin.one/safe/inscriptions/collections/#{COLLECTION_HASH}"
    end

    def test_collectible_uses_safe_inscriptions_items_endpoint
      MixinBot.api.collectible(COLLECTIBLE_HASH)
      assert_requested :get,
                       "https://api.mixin.one/safe/inscriptions/items/#{COLLECTIBLE_HASH}"
    end

    def test_collection_collectibles_uses_collections_items_endpoint_with_offset
      MixinBot.api.collection_collectibles(COLLECTION_HASH, offset: 42)
      assert_requested(
        :get,
        "https://api.mixin.one/safe/inscriptions/collections/#{COLLECTION_HASH}/items?offset=42"
      )
    end

    # --- collectibles filter ---

    def test_collectibles_filters_to_only_outputs_with_inscription_hash
      # The default MixinApiStubs register a mix of plain UTXOs and inscription-
      # bearing UTXOs in their /safe/outputs response. Inscription#collectibles
      # must keep only the entries that carry an `inscription_hash`.
      result = MixinBot.api.collectibles(members: [TEST_UID])
      assert_kind_of Array, result
      refute_empty result, 'expected at least one inscription-bearing UTXO from the stub'
      assert(result.all? { |u| u['inscription_hash'].present? },
             'expected every entry in the filtered list to carry inscription_hash')
    end

    def test_collectibles_returns_empty_when_no_utxos_have_inscription_hash
      WebMock.reset!
      stub_safe_outputs([
                          {
                            'output_id' => 'plain-1',
                            'transaction_hash' => 'ab' * 32,
                            'output_index' => 0,
                            'amount' => '1',
                            'asset_id' => CNB_ASSET_ID,
                            'receivers' => [MixinBot.config.app_id],
                            'receivers_threshold' => 1,
                            'state' => 'unspent'
                          }
                        ])

      result = MixinBot.api.collectibles(members: [TEST_UID])
      assert_equal [], result
    end

    def test_collectibles_default_state_is_unspent
      MixinBot.api.collectibles(members: [TEST_UID])
      assert_requested(:get, %r{state=unspent})
    end

    def test_collectibles_supports_state_kwarg
      MixinBot.api.collectibles(members: [TEST_UID], state: :spent)
      assert_requested(:get, %r{state=spent})
    end

    # --- create_collectible_transfer validation ---

    def test_create_collectible_transfer_raises_mixin_bot_argument_error_for_missing_inscription_hash
      # The inscription_hash guard raises the custom MixinBot::ArgumentError.
      utxo = inscription_utxo.merge('inscription_hash' => nil)

      error = assert_raises(MixinBot::ArgumentError) do
        MixinBot.api.create_collectible_transfer(utxo, members: [TEST_UID])
      end
      assert_match(/not a valid collectible/, error.message)
    end

    def test_create_collectible_transfer_raises_bare_argument_error_for_empty_members
      # The members guard raises the bare ::ArgumentError (NOT MixinBot::ArgumentError).
      # Inside `module MixinBot`, unqualified `ArgumentError` resolves to
      # MixinBot::ArgumentError, so the fully-qualified form is needed in tests.
      utxo = inscription_utxo

      error = assert_raises(::ArgumentError) do
        MixinBot.api.create_collectible_transfer(utxo, members: [])
      end
      assert_match(/members required/, error.message)
    end

    def test_create_collectible_transfer_raises_bare_argument_error_for_nil_members
      utxo = inscription_utxo

      error = assert_raises(::ArgumentError) do
        MixinBot.api.create_collectible_transfer(utxo, members: nil)
      end
      assert_match(/members required/, error.message)
    end

    def test_create_collectible_transfer_passes_validation_guards_with_minimal_inputs
      # When both guards pass, the multi-step Safe pipeline runs. We don't
      # assert anything about the result — only that neither guard trips.
      # Any subsequent HTTP / signature / encoding error is acceptable.
      begin
        MixinBot.api.create_collectible_transfer(inscription_utxo, members: [TEST_UID])
      rescue MixinBot::ArgumentError, ::ArgumentError => e
        flunk "expected the validation guards to pass, but got #{e.class}: #{e.message}"
      rescue StandardError
        # Pipeline errors are fine here.
      end
      pass
    end

    # --- helpers ---

    private

    def stub_safe_outputs(utxos)
      WebMock.stub_request(:get, %r{\Ahttps://api\.mixin\.one/safe/outputs\?})
             .to_return(status: 200,
                        body: JSON.dump('data' => utxos, 'error' => nil),
                        headers: { 'Content-Type' => 'application/json' })
    end

    def inscription_utxo
      {
        'output_id' => 'coll-1',
        'transaction_hash' => 'cd' * 32,
        'output_index' => 0,
        'amount' => '1',
        'asset_id' => CNB_ASSET_ID,
        'inscription_hash' => 'ee' * 32,
        'receivers' => [MixinBot.config.app_id],
        'receivers_threshold' => 1,
        'state' => 'unspent'
      }
    end
  end
end
