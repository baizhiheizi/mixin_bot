# frozen_string_literal: true

require 'test_helper'

module MixinBot
  class TestChain < Minitest::Test
    def test_chain_name_returns_human_readable_label_for_known_id
      assert_equal 'Ethereum', MixinBot.api.chain_name('43d61dcd-e413-450d-80b8-101d5e903357')
      assert_equal 'Bitcoin', MixinBot.api.chain_name('c6d0c728-2624-429b-8e0d-d9d19b6592fa')
    end

    def test_chain_name_falls_back_for_unknown_id
      assert_equal 'Not Supported Chain', MixinBot.api.chain_name('not-a-real-id')
      assert_equal 'Not Supported Chain', MixinBot.api.chain_name('')
    end

    def test_chain_name_aliased_to_get_chain_name
      assert_equal MixinBot.api.chain_name('43d61dcd-e413-450d-80b8-101d5e903357'),
                   MixinBot.api.get_chain_name('43d61dcd-e413-450d-80b8-101d5e903357')
    end

    def test_chain_id_predicate_true_for_known_id
      assert MixinBot.api.chain_id?('43d61dcd-e413-450d-80b8-101d5e903357')
    end

    def test_chain_id_predicate_false_for_unknown_id
      refute MixinBot.api.chain_id?('not-a-real-id')
      refute MixinBot.api.chain_id?('')
    end

    def test_chain_id_predicate_aliased_to_is_chain_id
      assert_equal MixinBot.api.chain_id?('43d61dcd-e413-450d-80b8-101d5e903357'),
                   MixinBot.api.is_chain_id('43d61dcd-e413-450d-80b8-101d5e903357')
    end

    def test_full_chains_returns_one_entry_per_supported_chain
      chains = MixinBot.api.full_chains
      assert_kind_of Hash, chains
      assert_equal MixinBot::API::Chain::CHAIN_NAMES.length, chains.length
    end

    def test_full_chains_values_are_all_true
      chains = MixinBot.api.full_chains
      refute_empty chains
      assert chains.values.all?, 'expected every full_chains value to be true'
    end

    def test_full_chains_keys_match_chain_names_keys
      assert_equal MixinBot::API::Chain::CHAIN_NAMES.keys, MixinBot.api.full_chains.keys
    end

    def test_full_chains_aliased_to_get_full_chains
      assert_equal MixinBot.api.full_chains, MixinBot.api.get_full_chains
    end

    def test_chain_names_constant_is_frozen
      assert MixinBot::API::Chain::CHAIN_NAMES.frozen?,
             'expected CHAIN_NAMES to be frozen to prevent accidental mutation'
    end

    def test_xin_asset_id_constant
      assert_equal 'c94ac88f-4671-3976-b60a-09064f1811e8', MixinBot::API::Chain::XIN_ASSET_ID
    end

    def test_vaulta_asset_id_constant
      assert_equal 'ac2b79f3-ec9c-3d87-b4ca-3e825228dda5', MixinBot::API::Chain::VAULTA_ASSET_ID
    end
  end
end
