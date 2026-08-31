# frozen_string_literal: true

require 'test_helper'

module MixinBot
  class TestAuth < Minitest::Test
    include WebMock::API

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

    def test_oauth_code_params_derives_challenge_from_verifier
      params = MixinBot.api.oauth_code_params(
        app_id: @opponent_app_id,
        scope: 'PROFILE:READ',
        code_verifier: 'test-verifier-123'
      )

      assert_equal @opponent_app_id, params[:client_id]
      assert_equal 'PROFILE:READ', params[:scope]
      assert_equal MixinBot.utils.oauth_code_challenge('test-verifier-123'), params[:code_challenge]
    end

    def test_oauth_code_params_keeps_empty_challenge_without_verifier
      params = MixinBot.api.oauth_code_params(app_id: @opponent_app_id, scope: 'PROFILE:READ')

      assert_equal '', params[:code_challenge]
      assert_equal '', params[:authorization_id]
    end

    def test_authorize_code
      r = MixinBot.api.authorize_code(
        app_id: @opponent_app_id,
        pin: PIN_CODE
      )
      refute_nil r
    end

    def test_authorizations
      r = MixinBot.api.authorizations
      refute_nil r['data']
    end

    def test_revoke_authorization
      r = MixinBot.api.revoke_authorization(@opponent_app_id)
      assert r['data']
    end

    def test_oauth_token_sends_code_verifier_when_given
      MixinBot.api.oauth_token('test-code', code_verifier: 'my-verifier')

      assert_requested :post, 'https://api.mixin.one/oauth/token',
                       body: hash_including('code' => 'test-code', 'code_verifier' => 'my-verifier')
    end

    def test_oauth_token_omits_code_verifier_when_absent
      MixinBot.api.oauth_token('test-code')

      assert_requested :post, 'https://api.mixin.one/oauth/token', body: hash_excluding('code_verifier')
    end

    def test_authorize_code_accepts_string_scope
      r = MixinBot.api.authorize_code(app_id: @opponent_app_id, pin: PIN_CODE, scope: 'PROFILE:READ CODE:READ')

      refute_nil r
    end
  end
end
