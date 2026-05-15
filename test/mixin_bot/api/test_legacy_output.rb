# frozen_string_literal: true

require 'test_helper'

module MixinBot
  class TestLegacyOutput < Minitest::Test
    def setup
    end

    def test_outputs
      # {"data"=>[{"type"=>"multisig_utxo", "user_id"=>"0508a116-1239-4e28-b150-85a8e3e6b400", "utxo_id"=>"684ac1de-cdc5-36f3-9034-ef3b74de0338", "asset_id"=>"965e5c6e-434c-3fa9-b780-c50f43cd955c", "transaction_hash"=>"ed567043fbeab439105570bd77e57fb717dfd24eeef83476f5e0837bb53805cb", "output_index"=>0, "amount"=>"1", "threshold"=>2, "members"=>["0508a116-1239-4e28-b150-85a8e3e6b400", "7ed9292d-7c95-4333-aa48-a8c640064186", "a67c6e87-1c9e-4a1c-b81c-47a9f4f1bff1"], "memo"=>"test for multi sign", "state"=>"unspent", "created_at"=>"2019-12-11T07:32:42.606383Z", "signed_by"=>"", "signed_tx"=>""}]}
      res = MixinBot.api.outputs

      assert_equal res['data'].class, Array
    end

    def test_create_output
      # {"data"=>{"type"=>"ghost_key", "mask"=>"1bb3c2718f22fd6ea9c20655e4246552890ef23d7a07edacd8fa4e1125604260", "keys"=>["9b36d8f4110d6fb82f7d100ae879817cad118835cd91f40dbd1e8e47e60d1b6b", "1fee396d8fdfb858684e81788d2934c5c47bd54ed19cb2a9b295c3c14fe3460a", "d6f5f1d26b0e45a621422a6c01ceca25783d1b12b8dc2a1dd7bbea94f3a7a690"]}}
      res = MixinBot.api.create_output(receivers: MULTI_SIGN_MEMBERS, index: 0, hint: SecureRandom.uuid)

      assert_equal 'ghost_key', res['data']['type']
    end
  end
end
