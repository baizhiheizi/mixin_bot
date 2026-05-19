# frozen_string_literal: true

require 'test_helper'

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
      out = capture_cli_output(%w[list me])
      assert_includes out, 'me'
    end

    def test_call_me_with_keystore
      out = capture_cli_output(['call', 'me', '-k', @keystore_json, '--data-only'])
      assert_includes out, OfflineConfig.app_id
    end

    def test_call_user_positional
      out = capture_cli_output(['call', 'user', TEST_UID, '-k', @keystore_json, '--data-only'])
      assert_match(/user_id|error/, out)
    end

    def test_invalid_json_exits_nonzero
      _out, err, status = capture_cli_exit(['call', 'me', '-k', @keystore_json, '-d', '{bad'])
      assert_equal 1, status
      assert_match(/invalid JSON/i, err)
    end

    def test_api_me_command
      out = capture_cli_output(['api', '/me', '-k', @keystore_json])
      assert_includes out, OfflineConfig.app_id
    end

    def test_build_api_from_keystore_includes_spend_key
      cli = CLI.new
      cli.instance_variable_set(:@options, {
                                  keystore: @keystore_json,
                                  apihost: 'api.mixin.one',
                                  pretty: false
                                })
      cli.send(:setup_api_instance!)
      spend = cli.api_instance.config.spend_key
      refute_nil spend
      assert_equal OfflineConfig.spend_key_hex, spend.unpack1('H*')
    end

    def test_nftmemo
      collection = SecureRandom.uuid
      out = capture_cli_output([
                                 'nftmemo',
                                 '-c', collection,
                                 '-t', '1',
                                 '-h', 'ab' * 32
                               ])
      refute_empty out.strip
    end

    def test_utils_unique_uuid
      out = capture_cli_output(['unique', TEST_UID, TEST_UID_2])
      uuid = out.strip
      assert_match(/\A[0-9a-f-]{36}\z/i, uuid)
    end

    def test_transfer_safe_pipeline
      out = capture_cli_output([
                                 'transfer', TEST_UID,
                                 '-k', @keystore_json,
                                 '--asset', CNB_ASSET_ID,
                                 '--amount', '0.001',
                                 '--memo', 'cli test'
                               ])
      assert_match(/transaction_hash|Submitted/i, out)
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

    def capture_cli_output(argv)
      out, = capture_cli_exit(argv)
      out
    end

    def capture_cli_exit(argv)
      out = err = ''
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
