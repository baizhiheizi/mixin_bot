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

    def test_blocking_users
      r = MixinBot.api.blocking_users
      assert r['data'].is_a?(Array)
    end

    def test_rotate_user_code
      r = MixinBot.api.rotate_user_code
      refute_nil r['data']['code_id']
    end

    def test_user_logs
      r = MixinBot.api.user_logs(limit: 10)
      assert r['data'].is_a?(Array)
    end
  end
end
