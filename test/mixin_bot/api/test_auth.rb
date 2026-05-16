# frozen_string_literal: true

require 'test_helper'

module MixinBot
  class TestAuth < Minitest::Test
    def setup
      @opponent_app_id = '54ca315c-d936-4158-97ef-04ab003a60ac'
    end

    def test_request_oauth
      url = MixinBot.api.request_oauth
      assert url.start_with? "https://mixin.one/oauth/authorize?client_id=#{MixinBot.config.app_id}"
    end

    def test_authorization_data
      data = MixinBot.api.authorization_data @opponent_app_id
      refute_nil data
    end

    def test_authorize_code
      r = MixinBot.api.authorize_code(
        app_id: @opponent_app_id,
        pin: PIN_CODE
      )
      refute_nil r
    end
  end
end
