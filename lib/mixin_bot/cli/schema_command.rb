# frozen_string_literal: true

module MixinBot
  class CLI
    desc 'schema', 'Emit machine-readable CLI schema (clispec-shaped)'
    long_desc <<-LONGDESC
      Discover mixinbot commands, arguments, and error kinds without parsing --help.

      Examples:

        $ mixinbot schema -o json
        $ mixinbot schema -o json | jq '.commands[].name'
        $ mixinbot schema -o yaml
    LONGDESC
    def schema
      with_command_name('schema') do
        emit_success(CLISchema.build, command: 'schema')
      end
    end
  end
end
