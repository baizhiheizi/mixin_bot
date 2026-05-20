# frozen_string_literal: true

require 'test_helper'
require 'json'

module MixinBot
  class TestCLIList < Minitest::Test
    def setup
      CLI::UI::StdoutRouter.enable
    end

    def test_list_json_pagination
      body = capture_cli_json(%w[list -o json --limit 3 --offset 0])
      data = body['data']
      assert_equal 'ok', body['status']
      assert_equal 3, data['items'].size
      assert_operator data['total'], :>, 3
      assert_equal 3, data['limit']
      assert_equal 0, data['offset']
    end

    def test_list_json_fields
      body = capture_cli_json(%w[list transfer -o json --limit 5 --fields name])
      item = body.dig('data', 'items')&.first
      refute_nil item
      assert_equal ['name'], item.keys
    end

    def test_utils_list_json
      body = capture_cli_json(%w[utils list -o json --limit 5])
      assert_equal 'ok', body['status']
      assert_operator body.dig('data', 'items').size, :<=, 5
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
