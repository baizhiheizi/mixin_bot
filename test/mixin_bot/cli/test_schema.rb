# frozen_string_literal: true

require 'test_helper'
require 'json'

module MixinBot
  class TestCLISchema < Minitest::Test
    def setup
      CLI::UI::StdoutRouter.enable
    end

    def test_schema_json_includes_core_commands
      body = capture_cli_json(%w[schema -o json])
      assert_equal 'mixinbot', body.dig('data', 'name')
      assert_equal MixinBot::VERSION, body.dig('data', 'version')
      names = body.dig('data', 'commands').map { |c| c['name'] }
      assert_includes names, 'call'
      assert_includes names, 'list'
      assert_includes names, 'schema'
      assert_includes names, 'transfer'
    end

    def test_schema_includes_error_kinds
      body = capture_cli_json(%w[schema -o json])
      kinds = body.dig('data', 'errors').map { |e| e['kind'] }
      assert_includes kinds, 'invalid_args'
      assert_includes kinds, 'auth'
      assert_includes kinds, 'api_error'
      assert_includes kinds, 'billing'
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
