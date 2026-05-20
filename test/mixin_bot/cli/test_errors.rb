# frozen_string_literal: true

require 'test_helper'
require 'json'

module MixinBot
  class TestCLIErrors < Minitest::Test
    def setup
      CLI::UI::StdoutRouter.enable
      @keystore_json = {
        'app_id' => OfflineConfig.app_id,
        'session_id' => OfflineConfig.session_id,
        'session_private_key' => OfflineConfig.session_private_key_hex,
        'server_public_key' => OfflineConfig.server_public_key_hex,
        'spend_key' => OfflineConfig.spend_key_hex
      }.to_json
    end

    def test_unknown_method_structured_error
      _out, err, status = capture_cli_exit(['call', 'not_a_real_method', '-k', @keystore_json, '-o', 'json'])
      assert_equal 1, status
      body = JSON.parse(err)
      assert_equal 'error', body['status']
      assert_equal 'unsupported', body.dig('error', 'kind')
      assert_match(/not_a_real_method/, body.dig('error', 'message'))
    end

    def test_transfer_dry_run
      body = capture_cli_json([
                                'transfer', TEST_UID,
                                '-k', @keystore_json,
                                '--asset', CNB_ASSET_ID,
                                '--amount', '0.001',
                                '--dry-run',
                                '-o', 'json'
                              ])
      assert_equal true, body.dig('data', 'dry_run')
      assert_equal 'create_safe_transfer', body.dig('data', 'method')
      refute_nil body.dig('data', 'kwargs')
    end

    private

    def capture_cli_json(argv)
      out = capture_cli_exit(argv).first
      JSON.parse(out)
    end

    def capture_cli_exit(argv)
      status = 0
      capture_io do
        CLI::UI::StdoutRouter.enable
        begin
          CLI.start(argv.dup, debug: true)
        rescue SystemExit => e
          status = e.status.to_i
        end
      end => captured
      [captured[0], captured[1], status]
    end
  end
end
