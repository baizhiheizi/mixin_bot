# frozen_string_literal: true

require 'test_helper'

module MixinBot
  class TestErrorMapper < Minitest::Test
    OFFICIAL_CODE_MAP = {
      400 => ValidationError,
      401 => UnauthorizedError,
      403 => ForbiddenError,
      404 => NotFoundError,
      429 => RateLimitError,
      10_002 => ValidationError,
      10_006 => AppUpdateRequiredError,
      10_104 => TransientError,
      10_105 => TransientError,
      20_116 => ConflictError,
      20_117 => InsufficientBalanceError,
      20_120 => TransferError,
      20_123 => ConflictError,
      20_124 => InsufficientBalanceError,
      20_125 => ConflictError,
      20_127 => TransferError,
      20_131 => ValidationError,
      20_133 => ConflictError,
      20_134 => TransferError,
      20_135 => TransferError,
      20_150 => ValidationError,
      30_102 => InvalidAddressFormatError,
      500 => ServerError,
      7000 => ServerError,
      7001 => ServerError
    }.freeze

    LEGACY_CODE_MAP = {
      20_121 => UnauthorizedError,
      20_118 => PinError,
      20_119 => PinError,
      30_103 => InsufficientPoolError,
      10_404 => UserNotFoundError
    }.freeze

    def setup
      @verb = 'get'
      @path = '/me'
      @body = '{}'
    end

    def test_official_catalog_maps_to_expected_classes
      OFFICIAL_CODE_MAP.each do |code, expected_class|
        error = assert_mapped_error(code, expected_class)
        assert_equal code, error.code, "code #{code} should set error.code"
        assert_equal 'test-req-id', error.request_id
      end
    end

    def test_legacy_codes_map_to_expected_classes
      LEGACY_CODE_MAP.each do |code, expected_class|
        assert_mapped_error(code, expected_class)
      end
    end

    def test_unknown_code_raises_response_error
      error = assert_mapped_error(499, ResponseError)
      assert_equal 499, error.code
      refute MixinBot.retryable?(error)
    end

    def test_unknown_server_code_is_retryable
      error = assert_mapped_error(99_501, ResponseError)
      assert MixinBot.retryable?(error)
    end

    def test_rate_limit_throttle_and_not_retryable
      error = assert_mapped_error(429, RateLimitError)
      assert error.throttle?
      refute error.retryable?
      refute MixinBot.retryable?(error)
    end

    def test_rate_limit_captures_retry_after_header
      response = stub_response(headers: { 'Retry-After' => '60', 'X-Request-Id' => 'test-req-id' })
      result = api_result(429, description: 'Too Many Requests')
      error = assert_raises(RateLimitError) do
        Client::ErrorMapper.raise_for!(verb: @verb, path: @path, body: @body, response:, result:)
      end
      assert_equal '60', error.retry_after
    end

    def test_transient_errors_are_retryable
      [10_104, 10_105].each do |code|
        error = assert_mapped_error(code, TransientError)
        assert MixinBot.retryable?(error), "code #{code} should be retryable"
      end
    end

    def test_insufficient_balance_not_retryable
      error = assert_mapped_error(20_117, InsufficientBalanceError)
      refute MixinBot.retryable?(error)
    end

    def test_validation_error_exposes_extra
      result = api_result(10_002, description: 'Invalid field', extra: { 'field' => 'name' })
      response = stub_response
      error = assert_raises(ValidationError) do
        Client::ErrorMapper.raise_for!(verb: @verb, path: @path, body: @body, response:, result:)
      end
      assert_equal({ 'field' => 'name' }, error.extra)
    end

    def test_forbidden_error_maps_only_code403
      assert_mapped_error(403, ForbiddenError)
      assert_mapped_error(429, RateLimitError)
      assert_mapped_error(10_002, ValidationError)
      assert_mapped_error(20_116, ConflictError)
    end

    def test_http_429_fallback_without_json_error
      client = Client.new(MixinBot.config)
      response = stub_response(status: 429, body: { 'data' => nil })
      error = assert_raises(RateLimitError) do
        client.send(:parse_response!, verb: 'GET', path: '/me', body: '', response:)
      end
      assert_equal 429, error.code
      assert error.throttle?
    end

    def test_http_401_fallback_without_json_error
      client = Client.new(MixinBot.config)
      response = stub_response(status: 401, body: {})
      assert_raises(UnauthorizedError) do
        client.send(:parse_response!, verb: 'GET', path: '/me', body: '', response:)
      end
    end

    def test_http_403_fallback_without_json_error
      client = Client.new(MixinBot.config)
      response = stub_response(status: 403, body: {})
      assert_raises(ForbiddenError) do
        client.send(:parse_response!, verb: 'GET', path: '/me', body: '', response:)
      end
    end

    def test_http_500_fallback_without_json_error
      client = Client.new(MixinBot.config)
      response = stub_response(status: 500, body: {})
      error = assert_raises(ServerError) do
        client.send(:parse_response!, verb: 'GET', path: '/me', body: '', response:)
      end
      assert MixinBot.retryable?(error)
    end

    def test_json_error_on_http_202_unchanged
      client = Client.new(MixinBot.config)
      result = api_result(429, description: 'Too Many Requests')
      response = stub_response(status: 202, body: result)
      error = assert_raises(RateLimitError) do
        client.send(:parse_response!, verb: 'GET', path: '/me', body: '', response:)
      end
      assert_equal 429, error.code
    end

    def test_success_envelope_when_no_error
      client = Client.new(MixinBot.config)
      response = stub_response(status: 200, body: { 'data' => { 'user_id' => OfflineConfig.app_id } })
      envelope = client.send(:parse_response!, verb: 'GET', path: '/me', body: '', response:)
      assert_equal OfflineConfig.app_id, envelope['data']['user_id']
    end

    private

    def assert_mapped_error(code, expected_class, description: 'Error')
      result = api_result(code, description: description)
      response = stub_response
      error = assert_raises(expected_class) do
        Client::ErrorMapper.raise_for!(verb: @verb, path: @path, body: @body, response:, result:)
      end
      assert_equal code, error.code
      assert_equal 'test-req-id', error.request_id
      error
    end

    def api_result(code, description: 'Error', extra: nil, status: nil)
      err = { 'code' => code, 'description' => description }
      err['status'] = status if status
      err['extra'] = extra if extra
      { 'error' => err }
    end

    def stub_response(status: 202, headers: { 'X-Request-Id' => 'test-req-id', 'X-Server-Time' => '0' }, body: nil)
      body ||= { 'data' => nil, 'error' => nil }
      Struct.new(:status, :headers, :body).new(status, headers, body)
    end
  end
end
