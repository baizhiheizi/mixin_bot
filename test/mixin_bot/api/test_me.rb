# frozen_string_literal: true

require 'test_helper'

module MixinBot
  class TestMe < Minitest::Test
    def setup
    end

    def test_me
      r = MixinBot.api.me
      assert r['data']['user_id'] == MixinBot.config.app_id
    end

    def test_update_me
      r = MixinBot.api.update_me(full_name: 'MixinBot')

      assert r['data']['full_name'] == 'MixinBot'
    end

    def test_friends
      r = MixinBot.api.friends
      assert r['data'].is_a?(Array)
    end

    def test_safe_me
      r = MixinBot.api.safe_me
      assert r['data']['user_id'] == MixinBot.config.app_id
    end
  end
end
