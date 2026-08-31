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

    def test_upstream_2026_chains_are_registered
      {
        'HyperEVM' => '36d23d9e-bf4e-3ede-a12d-26f1f1f9fd2f',
        'X Layer' => '37f5a4d1-905f-3b34-8291-c37438c7dcfc',
        'Robinhood' => 'b304e03d-d004-3102-875b-8266f8407a1a',
        'Pearl' => 'e1bf305c-0d49-397d-85bd-55b9eaadafba'
      }.each do |name, chain_id|
        assert_equal name, MixinBot.api.chain_name(chain_id)
        assert MixinBot.api.chain_id?(chain_id)
      end
    end

    def test_sui_chain_id_matches_upstream_fix
      assert_equal 'Sui', MixinBot.api.chain_name('3acb25e4-6216-35c3-b1ca-87184269ee08')
      assert MixinBot.api.chain_id?('3acb25e4-6216-35c3-b1ca-87184269ee08')
      refute MixinBot.api.chain_id?('2bd97283-2582-33a8-bcba-f4b8ed189572'),
             'obsolete pre-fix Sui id should not resolve anymore'
    end

    def test_chain_stablecoin_asset_ids
      assert_equal '3782f986-a053-33ae-b6bf-460abb62ce49', MixinBot::API::Chain::USDT_HYPEREVM
      assert_equal 'c4d9746a-20be-321c-baca-d378534dd4eb', MixinBot::API::Chain::USDT_XLAYER
      assert_equal '1e01fede-51fa-3791-9b06-5c18801b272c', MixinBot::API::Chain::USDC_HYPEREVM
      assert_equal '8d706a25-514c-3c73-9446-c25fd07d0ae2', MixinBot::API::Chain::USDC_XLAYER
      assert_equal 'a0f7ad61-3b9f-30f3-a1de-cd831aec33ff', MixinBot::API::Chain::USDC_SUI

      stablecoins = MixinBot::API::Chain::CHAIN_STABLECOIN_ASSET_IDS
      assert_equal({ usdt: MixinBot::API::Chain::USDT_HYPEREVM, usdc: MixinBot::API::Chain::USDC_HYPEREVM },
                   stablecoins['36d23d9e-bf4e-3ede-a12d-26f1f1f9fd2f'])
      assert_equal({ usdt: MixinBot::API::Chain::USDT_XLAYER, usdc: MixinBot::API::Chain::USDC_XLAYER },
                   stablecoins['37f5a4d1-905f-3b34-8291-c37438c7dcfc'])
      assert_equal({ usdc: MixinBot::API::Chain::USDC_SUI },
                   stablecoins['3acb25e4-6216-35c3-b1ca-87184269ee08'])
    end

    def test_stablecoin_asset_ids_accessor_uses_chain_id
      assert_equal({ usdc: 'a0f7ad61-3b9f-30f3-a1de-cd831aec33ff' },
                   MixinBot.api.stablecoin_asset_ids('3acb25e4-6216-35c3-b1ca-87184269ee08'))
      assert_nil MixinBot.api.stablecoin_asset_ids('43d61dcd-e413-450d-80b8-101d5e903357')
      assert_nil MixinBot.api.stablecoin_asset_ids('not-a-real-id')
    end
  end
end
