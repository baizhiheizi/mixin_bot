# frozen_string_literal: true

require 'test_helper'

module MixinBot
  class TestLegacySnapshot < Minitest::Test
    def setup
    end

    def test_public_snapshots
      res = MixinBot.api.network_snapshots(limit: 5)

      assert_equal res['data'][0]['type'], 'snapshot'
    end

    def test_public_snapshot
      snapshot_id = '9b096575-a0fd-4af1-84eb-ef87963a762d'
      res = MixinBot.api.network_snapshot(snapshot_id)

      assert_equal res['snapshot_id'], snapshot_id
    end

    def test_private_snapshots
      res = MixinBot.api.snapshots(limit: 1)

      assert res['data'][0]['type'] != 'snapshot'
    end
  end
end
