# frozen_string_literal: true

require 'test_helper'

module MixinBot
  class TestNetwork < Minitest::Test
    include WebMock::API

    def setup
      WebMock.reset!
      MixinApiStubs.register!
    end

    # ----- Network module -------------------------------------------------

    def test_network_assets
      res = MixinBot.api.network_assets

      assert_kind_of Hash, res['data']
      assert res['data'].key?('assets'), 'expected stub data to expose an assets key'
    end

    def test_network_assets_hits_network_root_path
      MixinBot.api.network_assets
      assert_requested :get, 'https://api.mixin.one/network'
    end

    def test_network_assets_aliased_to_read_network_assets
      assert_equal MixinBot.api.network_assets, MixinBot.api.read_network_assets
    end

    def test_network_assets_top
      res = MixinBot.api.network_assets_top

      assert_kind_of Array, res['data']
    end

    def test_network_assets_top_hits_correct_path
      MixinBot.api.network_assets_top
      assert_requested :get, 'https://api.mixin.one/network/assets/top'
    end

    def test_network_assets_top_aliased_to_read_network_assets_top
      assert_equal MixinBot.api.network_assets_top, MixinBot.api.read_network_assets_top
    end

    # ----- NetworkAsset module --------------------------------------------

    def test_network_asset_returns_stub_data_for_known_id
      res = MixinBot.api.network_asset(CNB_ASSET_ID)

      assert_equal CNB_ASSET_ID, res['data']['asset_id']
    end

    def test_network_asset_hits_path_with_asset_id
      MixinBot.api.network_asset(CNB_ASSET_ID)
      assert_requested :get, "https://api.mixin.one/network/assets/#{CNB_ASSET_ID}"
    end

    def test_network_asset_aliased_to_read_asset
      assert_equal MixinBot.api.network_asset(CNB_ASSET_ID),
                   MixinBot.api.read_asset(CNB_ASSET_ID)
    end

    def test_network_ticker_with_default_offset
      MixinBot.api.network_ticker(CNB_ASSET_ID)

      assert_requested(:get, 'https://api.mixin.one/network/ticker', query: { 'asset' => CNB_ASSET_ID })
    end

    def test_network_ticker_with_explicit_offset
      MixinBot.api.network_ticker(CNB_ASSET_ID, offset: '2024-01-01T00:00:00Z')

      assert_requested(:get, 'https://api.mixin.one/network/ticker', query: { 'asset' => CNB_ASSET_ID, 'offset' => '2024-01-01T00:00:00Z' })
    end

    def test_network_ticker_omits_offset_when_nil
      MixinBot.api.network_ticker(CNB_ASSET_ID, offset: nil)

      assert_not_requested(:get, 'https://api.mixin.one/network/ticker', query: { 'offset' => '2024-01-01T00:00:00Z' })
      assert_requested(:get, 'https://api.mixin.one/network/ticker', query: { 'asset' => CNB_ASSET_ID })
    end

    def test_network_ticker_accepts_explicit_access_token
      MixinBot.api.network_ticker(CNB_ASSET_ID, access_token: 'my-token')

      assert_requested(:get, 'https://api.mixin.one/network/ticker', query: { 'asset' => CNB_ASSET_ID })
    end

    def test_network_ticker_aliased_to_read_asset_ticker
      assert_equal MixinBot.api.network_ticker(CNB_ASSET_ID),
                   MixinBot.api.read_asset_ticker(CNB_ASSET_ID)
    end

    def test_network_asset_search_url_encodes_slash
      MixinBot.api.network_asset_search('Ethereum/ETH')

      assert_requested :get,
                       'https://api.mixin.one/network/assets/search/Ethereum%2FETH'
    end

    def test_network_asset_search_url_encodes_spaces_as_plus
      MixinBot.api.network_asset_search('Mixin Network Token')

      assert_requested :get,
                       'https://api.mixin.one/network/assets/search/Mixin+Network+Token'
    end

    def test_network_asset_search_handles_special_chars
      MixinBot.api.network_asset_search('BTC+ETH')

      assert_requested :get,
                       'https://api.mixin.one/network/assets/search/BTC%2BETH'
    end

    def test_network_asset_search_aliased_to_asset_search
      assert_equal MixinBot.api.network_asset_search('BTC'),
                   MixinBot.api.asset_search('BTC')
    end
  end
end
