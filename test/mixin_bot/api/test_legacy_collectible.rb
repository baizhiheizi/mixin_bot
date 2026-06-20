# frozen_string_literal: true

require 'test_helper'

module MixinBot
  class TestLegacyCollectible < Minitest::Test
    # 64-char (256-bit) hex string required by Nfo#mint_memo for the "extra" field.
    COLLECTION_UUID = '80722be0-1ec4-4356-a858-f328454c98de'
    VALID_EXTRA_HEX = 'a' * 64
    TOKEN_ID = 42

    def test_nft_asset_mixin_id_constant_matches_known_value
      assert_equal '1700941284a95f31b25ec8c546008f208f88eee4419ccdcdbe6e3195e60128ca',
                   MixinBot::API::LegacyCollectible::NFT_ASSET_MIXIN_ID
    end

    def test_nft_asset_mixin_id_constant_is_a_64_char_lowercase_hex_string
      value = MixinBot::API::LegacyCollectible::NFT_ASSET_MIXIN_ID
      assert_kind_of String, value
      assert_equal 64, value.length
      assert_match(/\A[0-9a-f]{64}\z/, value)
    end

    def test_collectible_transaction_arguments_constant_is_frozen
      # NOTE: defined directly on MixinBot::API (legacy placement) rather than the
      # LegacyCollectible submodule. Keeping the assertion at the API level so
      # the test documents where the constant actually lives.
      assert MixinBot::API::COLLECTIBLE_TRANSACTION_ARGUMENTS.frozen?,
             'expected COLLECTIBLE_TRANSACTION_ARGUMENTS to be frozen to prevent accidental mutation'
    end

    def test_collectible_transaction_arguments_constant_lists_required_keys
      expected = %i[collectible nfo receivers receivers_threshold]
      assert_equal expected.sort,
                   MixinBot::API::COLLECTIBLE_TRANSACTION_ARGUMENTS.sort
    end

    def test_nft_memo_returns_a_non_empty_memo_string
      memo = MixinBot.api.nft_memo(COLLECTION_UUID, TOKEN_ID, VALID_EXTRA_HEX)
      assert_kind_of String, memo
      refute_empty memo
    end

    def test_nft_memo_decodes_to_expected_collection_token_and_extra
      memo = MixinBot.api.nft_memo(COLLECTION_UUID, TOKEN_ID, VALID_EXTRA_HEX)
      decoded = MixinBot::Nfo.new(memo: memo).decode
      assert_equal COLLECTION_UUID, decoded.collection
      assert_equal TOKEN_ID, decoded.token
      assert_equal VALID_EXTRA_HEX, decoded.extra
    end

    def test_nft_memo_raises_for_blank_extra
      assert_raises(MixinBot::InvalidNfoFormatError) do
        MixinBot.api.nft_memo(COLLECTION_UUID, TOKEN_ID, '')
      end
    end

    def test_nft_memo_raises_for_short_extra
      # 32-char (128-bit) hex — half the required 256-bit size.
      assert_raises(MixinBot::InvalidNfoFormatError) do
        MixinBot.api.nft_memo(COLLECTION_UUID, TOKEN_ID, 'a' * 32)
      end
    end

    def test_create_collectible_request_raises_for_unknown_action
      # COLLECTABLE_REQUEST_ACTIONS is %i[sign unlock]; anything else must raise.
      assert_raises(ArgumentError) do
        MixinBot.api.create_collectible_request('approve', 'raw')
      end
    end

    def test_create_collectible_request_raises_for_unknown_action_as_symbol
      assert_raises(ArgumentError) do
        MixinBot.api.create_collectible_request(:approve, 'raw')
      end
    end

    def test_build_collectible_transaction_raises_for_missing_collectible
      assert_raises(ArgumentError) do
        MixinBot.api.build_collectible_transaction(
          nfo: 'aa' * 32,
          receivers: [TEST_UID],
          receivers_threshold: 1
        )
      end
    end

    def test_build_collectible_transaction_raises_for_missing_nfo
      assert_raises(ArgumentError) do
        MixinBot.api.build_collectible_transaction(
          collectible: { 'state' => 'unspent' },
          receivers: [TEST_UID],
          receivers_threshold: 1
        )
      end
    end

    def test_build_collectible_transaction_raises_for_missing_receivers
      assert_raises(ArgumentError) do
        MixinBot.api.build_collectible_transaction(
          collectible: { 'state' => 'unspent' },
          nfo: 'aa' * 32,
          receivers_threshold: 1
        )
      end
    end

    def test_build_collectible_transaction_raises_for_missing_receivers_threshold
      assert_raises(ArgumentError) do
        MixinBot.api.build_collectible_transaction(
          collectible: { 'state' => 'unspent' },
          nfo: 'aa' * 32,
          receivers: [TEST_UID]
        )
      end
    end

    def test_build_collectible_transaction_raises_when_collectible_is_spent
      # Spent collectibles cannot be re-transferred; the helper short-circuits
      # before delegating to build_raw_transaction.
      assert_raises(RuntimeError) do
        MixinBot.api.build_collectible_transaction(
          collectible: { 'state' => 'spent' },
          nfo: 'aa' * 32,
          receivers: [TEST_UID],
          receivers_threshold: 1
        )
      end
    end

    def test_build_collectible_transaction_returns_a_raw_transaction_hash
      # Receivers must include the configured app_id (OfflineConfig.app_id) so
      # build_raw_transaction's access_token guard does not trip.
      collectible = {
        'state' => 'unspent',
        'receivers' => [MixinBot.config.app_id, TEST_UID],
        'receivers_threshold' => 1,
        'transaction_hash' => 'a' * 64,
        'output_index' => 0
      }

      tx = MixinBot.api.build_collectible_transaction(
        collectible: collectible,
        nfo: 'aa' * 32,
        receivers: [TEST_UID],
        receivers_threshold: 1,
        hint: SecureRandom.uuid
      )

      assert_kind_of Hash, tx
    end
  end
end
