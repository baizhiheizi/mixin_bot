# frozen_string_literal: true

require 'test_helper'
require 'open3'
require 'rbconfig'

class GeneratorIsolationTest < Minitest::Test
  def test_mixin_bot_loads_cleanly_without_rails
    script = <<~RUBY
      require 'mixin_bot'
      raise 'MixinBot::Generators loaded outside Rails' if defined?(MixinBot::Generators)
      if $LOADED_FEATURES.any? { |f| f.include?('generators/mixin_bot') }
        raise 'generator files were loaded without rails'
      end
      print 'OK'
    RUBY

    repo_root = File.expand_path('../..', __dir__)
    output, status = Open3.capture2(RbConfig.ruby, '-I', 'lib', '-e', script, chdir: repo_root)

    assert status.success?, "expected `require \"mixin_bot\"` to load without rails, got:\n#{output}"
    assert_equal 'OK', output
  end
end
