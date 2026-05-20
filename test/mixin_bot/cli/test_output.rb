# frozen_string_literal: true

require 'test_helper'
require 'json'

module MixinBot
  class TestCLIOutput < Minitest::Test
    def setup
      CLI::UI::StdoutRouter.enable
      @cli = CLI.new
    end

    def test_output_format_defaults_to_json_when_not_tty
      with_stdout_tty(false) do
        @cli.options = { output: nil, pretty: true }
        assert_equal 'json', @cli.send(:output_format)
      end
    end

    def test_output_format_explicit_json
      @cli.options = { output: 'json', pretty: true }
      assert_equal 'json', @cli.send(:output_format)
    end

    def test_output_format_pretty_false_maps_to_json
      @cli.options = { output: nil, pretty: false }
      assert_equal 'json', @cli.send(:output_format)
    end

    def test_emit_success_json_envelope
      @cli.options = { output: 'json', pretty: true }
      out = capture_io do
        @cli.send(:emit_success, { 'user_id' => 'abc' }, command: 'call')
      end.first
      body = JSON.parse(out)
      assert_equal 'ok', body['status']
      assert_equal 'call', body['command']
      assert_equal 'abc', body.dig('data', 'user_id')
    end

    def test_abort_with_error_json_stderr
      @cli.options = { output: 'json', pretty: true }
      err = capture_io do
        assert_raises(SystemExit) do
          @cli.send(:abort_with_error, 'bad method', kind: :unsupported, hint: 'mixinbot list')
        end
      end.last
      body = JSON.parse(err)
      assert_equal 'error', body['status']
      assert_equal 'unsupported', body.dig('error', 'kind')
      assert_equal 'mixinbot list', body.dig('error', 'hint')
    end

    def test_paginate_items
      items = (1..5).map { |i| { 'name' => "m#{i}" } }
      page, total, limit, offset = @cli.send(:paginate_items, items, limit: 2, offset: 1)
      assert_equal 5, total
      assert_equal 2, limit
      assert_equal 1, offset
      assert_equal 2, page.size
      assert_equal 'm2', page.first['name']
    end

    private

    def with_stdout_tty(value)
      original = $stdout.method(:tty?)
      $stdout.define_singleton_method(:tty?) { value }
      yield
    ensure
      $stdout.define_singleton_method(:tty?, original)
    end
  end
end
