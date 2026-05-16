# frozen_string_literal: true

require 'test_helper'

module MixinBot
  class TestApp < Minitest::Test
    def setup
      @opponent_app_id = 'c1412f68-6152-40ad-a193-f7fadf9328a1'
    end

    def test_add_favorite_app
      r = MixinBot.api.add_favorite_app @opponent_app_id

      refute_nil r['data']
    end

    def test_remove_favorite_app
      r = MixinBot.api.remove_favorite_app @opponent_app_id

      refute_nil r['data']
    end

    def test_favorite_apps
      r = MixinBot.api.favorite_apps

      assert r['data'].is_a?(Array)
    end
  end
end
