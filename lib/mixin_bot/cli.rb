# frozen_string_literal: true

require 'awesome_print'
require 'cli/ui'
require 'thor'
require 'yaml'
require 'json'

require_relative 'cli/base'
require_relative 'cli/errors'
require_relative 'cli/output'
require_relative 'cli/schema'

module MixinBot
  class CLI < Thor
    include CLIHelpers
    include CLIOutput

    UI = ::CLI::UI

    class_option :apihost, type: :string, aliases: '-a', default: 'api.mixin.one', desc: 'Specify mixin api host'
    class_option :output, type: :string, aliases: '-o', enum: CLIOutput::OUTPUT_FORMATS,
                          desc: 'Output format: pretty, json, yaml (default: pretty in TTY, json when piped)'
    class_option :pretty, type: :boolean, aliases: '-r', default: true,
                         desc: 'Pretty-print output (alias for --output pretty when set false → json)'

    attr_reader :keystore, :api_instance

    desc 'version', 'Display MixinBot version'
    def version
      with_command_name('version') do
        emit_success({ 'version' => MixinBot::VERSION }, command: 'version')
      end
    end

    def self.exit_on_failure?
      true
    end

    private

    def setup_api_instance!
      MixinBot.config.api_host = options[:apihost] if options[:apihost].present?

      if options[:keystore].blank?
        @api_instance = MixinBot::API.new
        return @api_instance
      end

      raw =
        if File.file?(options[:keystore])
          File.read(options[:keystore])
        else
          options[:keystore]
        end

      @keystore =
        begin
          JSON.parse(raw)
        rescue JSON::ParserError
          abort_with_error(
            format('failed to parse keystore JSON: %<path>s', path: options[:keystore]),
            kind: :invalid_args,
            hint: 'mixinbot call me -k keystore.json'
          )
        end

      @api_instance = build_api_from_keystore(@keystore)
    rescue StandardError => e
      abort_with_error(
        format('failed to initialize API (check keystore): %<error>s', error: e.message),
        kind: CLIErrors.kind_for_exception(e),
        exception: e
      )
    end

    def build_api_from_keystore(store)
      MixinBot::API.new(
        app_id: store['app_id'] || store['client_id'],
        session_id: store['session_id'],
        server_public_key: store['server_public_key'] || store['pin_token'],
        session_private_key: store['session_private_key'] || store['private_key'],
        spend_key: store['spend_key'],
        client_secret: store['client_secret'],
        pin: store['pin']
      )
    end

    def parse_json_data(json_string, label: 'data')
      return {} if json_string.blank?

      parsed = JSON.parse(json_string)
      unless parsed.is_a?(Hash)
        abort_with_error("#{label} must be a JSON object", kind: :invalid_args)
      end

      parsed.transform_keys(&:to_sym)
    rescue JSON::ParserError => e
      abort_with_error("invalid JSON for #{label}: #{e.message}", kind: :invalid_args)
    end

    def invoke_api(method_name, kwargs: {}, positional: [])
      sym = method_name.to_sym
      unless CLIHelpers.api_method_callable?(sym)
        abort_with_error(
          format('unknown or unsupported API method: %<method>s (run `mixinbot list`)', method: method_name),
          kind: :unsupported,
          hint: 'mixinbot list'
        )
      end

      if CLIHelpers::INTERACTIVE_API_METHODS.include?(sym)
        abort_with_error(
          format('%<method>s is interactive and not supported from the CLI', method: method_name),
          kind: :unsupported,
          hint: 'Use the Ruby API for Blaze WebSocket (see examples/blaze.rb)'
        )
      end

      api_instance.public_send(sym, *positional, **kwargs)
    rescue ::ArgumentError => e
      abort_with_error(
        format('invalid arguments for %<method>s: %<error>s', method: method_name, error: e.message),
        kind: :invalid_args,
        hint: format('mixinbot list %<method>s', method: method_name)
      )
    rescue MixinBot::Error => e
      abort_with_error(e.message, exception: e)
    end

    def invoke_utils(method_name, kwargs: {}, positional: [])
      sym = method_name.to_sym
      unless CLIHelpers.utils_callable_methods.include?(sym)
        abort_with_error(
          format('unknown utils method: %<method>s', method: method_name),
          kind: :unsupported,
          hint: 'mixinbot utils list'
        )
      end

      MixinBot.utils.public_send(sym, *positional, **kwargs)
    rescue ::ArgumentError => e
      abort_with_error(
        format('invalid arguments for utils.%<method>s: %<error>s', method: method_name, error: e.message),
        kind: :invalid_args
      )
    end

    def warn_deprecated(message)
      emit_info("warning: #{message}")
    end
  end
end

require_relative 'cli/call'
require_relative 'cli/api'
require_relative 'cli/node'
require_relative 'cli/utils'
require_relative 'cli/schema_command'

module MixinBot
  class CLI
    if system('which mixin > /dev/null 2>&1')
      desc 'node SUBCOMMAND', 'Experimental mixin node CLI helpers (requires `mixin` binary)'
      subcommand 'node', NodeCLI
    end
  end
end
