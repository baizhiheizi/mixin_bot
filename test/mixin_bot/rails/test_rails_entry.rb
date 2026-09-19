# frozen_string_literal: true

require 'test_helper'
require 'open3'
require 'rbconfig'
require 'tmpdir'

module MixinBot
  # NOTE: test classes must not define a MixinBot::Rails constant — it would
  # lexically shadow ::Rails for gem code under module MixinBot.
  class RailsEntryTest < Minitest::Test
    REPO_ROOT = File.expand_path('../../..', __dir__)

    def test_rails_entry_raises_named_error_when_rails_is_missing
      Dir.mktmpdir do |poison_dir|
        # A rails.rb that raises LoadError simulates an environment without
        # rails, deterministic even in bundles that carry railties.
        File.write(File.join(poison_dir, 'rails.rb'),
                   %(raise LoadError, "cannot load such file -- rails (simulated)\n"))

        script = <<~RUBY
          begin
            require 'mixin_bot/rails'
            abort 'expected require "mixin_bot/rails" to raise LoadError'
          rescue LoadError => e
            abort 'error does not name rails' unless e.message.include?('rails gem')
            abort 'error does not mention the SDK-only escape hatch' unless e.message.include?('mixin_bot/rails')
          end
          print 'OK'
        RUBY

        stdout, _stderr, status = run_ruby(script, load_path_extra: poison_dir)

        assert status.success?, "expected a LoadError naming rails, stdout:\n#{stdout}"
        assert_equal 'OK', stdout
      end
    end

    def test_rails_entry_loads_railtie_when_rails_present
      script = <<~RUBY
        require 'mixin_bot/rails'
        raise 'Railtie not defined' unless defined?(MixinBot::Railtie)
        raise 'wrong railtie parent' unless MixinBot::Railtie < ::Rails::Railtie
        print 'OK'
      RUBY

      stdout, _stderr, status = run_ruby(script)

      assert status.success?, "expected the railtie to load under rails, stdout:\n#{stdout}"
      assert_equal 'OK', stdout
    end

    private

    def run_ruby(script, load_path_extra: nil)
      args = [RbConfig.ruby]
      args += ['-I', load_path_extra] if load_path_extra
      args += ['-I', File.join(REPO_ROOT, 'lib'), '-e', script]

      bundler_env = { 'BUNDLE_GEMFILE' => File.join(REPO_ROOT, 'Gemfile') }
      Open3.capture3(bundler_env, *args, chdir: REPO_ROOT)
    end
  end
end
