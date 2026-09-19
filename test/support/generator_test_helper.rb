# frozen_string_literal: true

# Minimal railties environment for testing the mixin_bot Rails generators.
# No full Rails app is booted: actions that would shell out (rails_command,
# bundle_command) are replaced by the recorder module below.

require 'rails'
require 'rails/generators'
require 'rails/generators/test_case'
require 'generators/mixin_bot/authentication/authentication_generator'

# Records (instead of executing) the bundler/rails shell-outs a generator
# would perform. Prepended onto the generator class under test.
module GeneratorCommandRecorder
  def bundle_command(*args)
    self.class.recorded_bundle_commands << args
  end

  def rails_command(*args)
    self.class.recorded_rails_commands << args
  end
end
