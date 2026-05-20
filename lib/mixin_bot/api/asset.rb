# frozen_string_literal: true

module MixinBot
  class API
    ##
    # API methods for asset management.
    #
    # Provides methods to:
    # - List all assets in bot's wallet
    # - Read specific asset information
    # - Get asset ticker/price data
    #
    module Asset
      ##
      # Retrieves all assets in the bot's wallet.
      #
      # Returns an array of asset objects, each containing:
      # - asset_id: the asset UUID
      # - symbol: the asset symbol (e.g., "BTC", "ETH")
      # - name: the full asset name
      # - icon_url: URL to the asset icon
      # - balance: current balance
      # - destination: deposit address
      # - tag: deposit memo/tag (if applicable)
      # - price_btc: price in BTC
      # - price_usd: price in USD
      # - chain_id: the blockchain UUID
      # - change_btc: 24h price change in BTC
      # - change_usd: 24h price change in USD
      # - confirmations: required confirmations
      # - asset_key: the asset key for deposit
      #
      # @param access_token [String, nil] optional access token
      # @return [Array<Hash>] array of asset objects
      #
      # @example
      #   assets = api.assets
      #   assets.each do |asset|
      #     puts "#{asset['symbol']}: #{asset['balance']}"
      #   end
      #
      # @see https://developers.mixin.one/docs/api/assets/assets
      #
      def assets(access_token: nil)
        path = '/assets'
        client.get path, access_token:
      end

      ##
      # Retrieves information for a specific asset.
      #
      # Returns detailed information about a single asset including:
      # - Current balance
      # - Price information
      # - Deposit address
      # - Network details
      #
      # @param asset_id [String] the asset UUID
      # @param access_token [String, nil] optional access token
      # @return [Hash] the asset information
      #
      # @example
      #   # Get Bitcoin information
      #   btc = api.asset('c6d0c728-2624-429b-8e0d-d9d19b6592fa')
      #   puts "BTC Balance: #{btc['balance']}"
      #   puts "BTC Price: $#{btc['price_usd']}"
      #
      # @see https://developers.mixin.one/docs/api/assets/asset
      #
      def asset(asset_id, access_token: nil)
        path = format('/assets/%<asset_id>s', asset_id:)
        client.get path, access_token:
      end

      ##
      # Retrieves ticker/price data for an asset.
      #
      # Returns historical price and volume data for an asset,
      # useful for charts and price tracking.
      #
      # @param asset_id [String] the asset UUID
      # @param kwargs [Hash] query options
      # @option kwargs [String, DateTime, Time] :offset the time offset for historical data
      # @option kwargs [String] :access_token optional access token
      # @return [Hash] ticker data including price and volume
      #
      # @example
      #   # Get current ticker
      #   ticker = api.ticker('c6d0c728-2624-429b-8e0d-d9d19b6592fa')
      #   puts "Price: $#{ticker['price_usd']}"
      #
      #   # Get historical ticker
      #   ticker = api.ticker(
      #     'c6d0c728-2624-429b-8e0d-d9d19b6592fa',
      #     offset: 1.day.ago
      #   )
      #
      # @see https://developers.mixin.one/docs/api/assets/ticker
      #
      def ticker(asset_id, **kwargs)
        offset = kwargs[:offset]
        offset = DateTime.rfc3339(offset) if offset.is_a? String
        offset = offset.rfc3339 if offset.is_a?(DateTime) || offset.is_a?(Time)

        path = '/ticker'
        client.get path, asset_id:, offset:, access_token: kwargs[:access_token]
      end

      def fetch_assets(asset_ids, access_token: nil)
        client.fetch_post_array '/safe/assets/fetch', Array(asset_ids), access_token:
      end

      def asset_fee(asset_id, destination:, access_token: nil)
        path = format('/safe/assets/%<asset_id>s/fees', asset_id:)
        client.get path, destination:, access_token:
      end
      alias read_asset_fee asset_fee

      def asset_balance(asset_id)
        outputs = safe_outputs(asset: asset_id, state: 'unspent')
        Array(outputs['data']).sum { |o| o['amount'].to_d }
      end
      alias asset_balance_with_safe_user asset_balance

      def user_asset_balance(user_id, asset_id, access_token: nil)
        members_hash = MixinBot.utils.hash_members([user_id])
        path = '/safe/outputs'
        response = client.get(
          path,
          members: members_hash,
          threshold: 1,
          asset: asset_id,
          state: 'unspent',
          access_token:
        )
        Array(response['data']).sum { |o| o['amount'].to_d }
      end
    end
  end
end
