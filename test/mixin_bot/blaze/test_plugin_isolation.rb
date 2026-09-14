# frozen_string_literal: true

require 'test_helper'

module MixinBot
  module Blaze
    # The gem must stay loadable (and puma-free) in processes that never run
    # the Puma plugin: the plugin file is only ever required BY puma itself.
    # Verified in a subprocess, since other tests load puma directly.
    class TestPluginIsolation < Minitest::Test
      def test_requiring_mixin_bot_does_not_load_puma_or_the_plugin
        script = <<~RUBY
          require 'mixin_bot'
          puma_free = $LOADED_FEATURES.none? do |path|
            path.include?('/puma/') || path.end_with?('/puma.rb')
          end
          exit(puma_free ? 0 : 1)
        RUBY

        assert system({ 'RUBYOPT' => '-rbundler/setup' }, Gem.ruby, '-Ilib', '-e', script),
               'requiring mixin_bot must not load puma'
      end
    end
  end
end
