# frozen_string_literal: true

require 'test_helper'

module MixinBot
  class TestCollectible < Minitest::Test
    def setup
    end

    def test_collectible
      token = 'abfe580a-1fa0-3237-8c43-52c7de5c80ae'
      r = MixinBot.api.collectible token

      assert r['data'].is_a?(Hash)
    end

    def test_collection
      collection = '80722be0-1ec4-4356-a858-f328454c98de'
      r = MixinBot.api.collection collection

      assert r['data'].is_a?(Hash)
    end

    def test_collectibles
      r = MixinBot.api.collectibles

      assert_kind_of Array, r
    end

    def test_create_collectible_sign_request
      collectible = MixinBot.api.collectibles(state: :unspent).first

      nfo = MixinBot.api.collectible(collectible['token_id'])['data']['nfo']
      tx = MixinBot.api.build_collectible_transaction(
        collectible:,
        nfo:,
        receivers: [TEST_UID],
        receivers_threshold: 1
      )

      raw = MixinBot.api.encode_raw_transaction tx
      request = MixinBot.api.create_sign_collectible_request raw

      r = MixinBot.api.sign_collectible_request request['request_id'], PIN_CODE

      refute_nil r['data']
    end

    def test_send_collectible_raw_transaction
      collectible = MixinBot.api.collectibles(state: :signed).first

      raw = collectible['signed_tx']
      r = MixinBot.api.send_raw_transaction raw

      refute_nil r['data']
    end

    def test_create_collectible_unlock_request
      collectible = MixinBot.api.collectibles(state: :signed).first

      request = MixinBot.api.create_unlock_collectible_request collectible['signed_tx']
      r = MixinBot.api.unlock_collectible_request request['request_id'], PIN_CODE

      refute_nil r['data']
    end

    def test_create_mint_nft_payment
      collection = ''
      token_id = 999
      meta = {
        collection: {
          id: collection,
          name: 'TEST_COLLECTION',
          description: 'very cool test',
          icon: {
            hash: 'hash of the collection icon',
            url: 'https://mixin.one/assets/8cb83bab76f849798c8e74e8c6a968d3.png'
          }
        },
        token: {
          id: token_id,
          name: 'No.999 Token',
          description: 'unique token',
          icon: {
            hash: 'hash of the token icon',
            url: 'https://mixin.one/assets/8cb83bab76f849798c8e74e8c6a968d3.png'
          },
          media: {}
        }
      }
      metahash = SHA3::Digest::SHA256.hexdigest [meta[:collection][:id], meta[:collection][:name], meta[:token][:id],
                                                 meta[:token][:name]].join
      memo = MixinBot.api.nft_memo collection, token_id, metahash

      payment = MixinBot.api.create_multisig_payment(
        asset_id: XIN_ASSET_ID,
        amount: 0.001,
        memo:,
        receivers: NFO_MTG,
        threshold: NFO_THRESHOLD
      )

      assert payment['data'].is_a?(Hash)
    end
  end
end
