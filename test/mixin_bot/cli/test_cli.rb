# frozen_string_literal: true

require 'test_helper'
require 'json'

module MixinBot
  class TestCLI < Minitest::Test
    KEYSTORE_PATH = File.expand_path('../../fixtures/keystore.json', __dir__)

    def setup
      CLI::UI::StdoutRouter.enable
      @keystore_json = keystore_inline_json
    end

    def test_api_callable_methods_excludes_infra
      methods = CLIHelpers.api_callable_methods
      refute_includes methods, :initialize
      refute_includes methods, :client
      refute_includes methods, :access_token
      refute_includes methods, :start_blaze_connect
    end

    def test_list_includes_me
      out = capture_cli_output(%w[list me -o pretty])
      assert_includes out, 'me'
    end

    def test_call_me_with_keystore
      body = capture_cli_json(['call', 'me', '-k', @keystore_json, '--data-only'])
      assert_equal 'ok', body['status']
      assert_includes body.dig('data', 'user_id') || body['data'].to_s, OfflineConfig.app_id
    end

    def test_call_user_positional
      body = capture_cli_json(['call', 'user', TEST_UID, '-k', @keystore_json, '--data-only'])
      assert_equal 'ok', body['status']
      data = body['data']
      assert(data.key?('user_id') || data.key?('error'))
    end

    def test_invalid_json_exits_nonzero
      _out, err, status = capture_cli_exit(['call', 'me', '-k', @keystore_json, '-d', '{bad', '-o', 'json'])
      assert_equal 1, status
      err_body = JSON.parse(err)
      assert_equal 'error', err_body['status']
      assert_match(/invalid JSON/i, err_body.dig('error', 'message'))
    end

    def test_api_me_command
      body = capture_cli_json(['api', '/me', '-k', @keystore_json])
      assert_equal 'ok', body['status']
      assert_includes body['data'].to_s, OfflineConfig.app_id
    end

    def test_build_api_from_keystore_includes_spend_key
      cli = CLI.new
      cli.instance_variable_set(:@options, {
                                  keystore: @keystore_json,
                                  apihost: 'api.mixin.one',
                                  pretty: false,
                                  output: 'json'
                                })
      cli.send(:setup_api_instance!)
      spend = cli.api_instance.config.spend_key
      refute_nil spend
      assert_equal OfflineConfig.spend_key_hex, spend.unpack1('H*')
    end

    def test_nftmemo
      collection = SecureRandom.uuid
      body = capture_cli_json([
                                'nftmemo',
                                '-c', collection,
                                '-t', '1',
                                '-h', 'ab' * 32,
                                '-o', 'json'
                              ])
      refute_empty body['data'].to_s.strip
    end

    def test_utils_unique_uuid
      body = capture_cli_json(['unique', TEST_UID, TEST_UID_2, '-o', 'json'])
      uuid = body['data']
      assert_match(/\A[0-9a-f-]{36}\z/i, uuid)
    end

    def test_transfer_safe_pipeline
      body = capture_cli_json([
                                'transfer', TEST_UID,
                                '-k', @keystore_json,
                                '--asset', CNB_ASSET_ID,
                                '--amount', '0.001',
                                '--memo', 'cli test',
                                '-o', 'json'
                              ])
      data = body['data']
      assert(
        data.key?('transaction_hash') ||
        data.to_s.match?(/transaction_hash|snapshot_id/i)
      )
    end

    private

    def keystore_inline_json
      {
        'app_id' => OfflineConfig.app_id,
        'session_id' => OfflineConfig.session_id,
        'session_private_key' => OfflineConfig.session_private_key_hex,
        'server_public_key' => OfflineConfig.server_public_key_hex,
        'spend_key' => OfflineConfig.spend_key_hex,
        'pin' => '123456',
        'client_secret' => 'offline-test-client-secret'
      }.to_json
    end

    def capture_cli_json(argv)
      out = capture_cli_output(argv)
      JSON.parse(out)
    end

    def capture_cli_output(argv)
      out, = capture_cli_exit(argv)
      out
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
      out = captured[0]
      err = captured[1]
      [out, err, status]
    end
  end
end
