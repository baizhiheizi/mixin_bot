# frozen_string_literal: true

require 'awesome_print'
require 'cli/ui'
require 'thor'
require 'yaml'
require 'json'

require_relative 'cli/base'

module MixinBot
  class CLI < Thor
    include CLIHelpers

    UI = ::CLI::UI

    class_option :apihost, type: :string, aliases: '-a', default: 'api.mixin.one', desc: 'Specify mixin api host'
    class_option :pretty, type: :boolean, aliases: '-r', default: true, desc: 'Print output in pretty'

    attr_reader :keystore, :api_instance

    desc 'version', 'Display MixinBot version'
    def version
      log MixinBot::VERSION
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
            format('failed to parse keystore JSON: %<path>s', path: options[:keystore])
          )
        end

      @api_instance = build_api_from_keystore(@keystore)
    rescue StandardError => e
      abort_with_error(
        format('failed to initialize API (check keystore): %<error>s', error: e.message)
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
        abort_with_error("#{label} must be a JSON object")
      end

      parsed.transform_keys(&:to_sym)
    rescue JSON::ParserError => e
      abort_with_error("invalid JSON for #{label}: #{e.message}")
    end

    def invoke_api(method_name, kwargs: {}, positional: [])
      sym = method_name.to_sym
      unless CLIHelpers.api_method_callable?(sym)
        abort_with_error(
          format('unknown or unsupported API method: %<method>s (run `mixinbot list`)', method: method_name)
        )
      end

      if CLIHelpers::INTERACTIVE_API_METHODS.include?(sym)
        abort_with_error(
          format('%<method>s is interactive and not supported from the CLI', method: method_name)
        )
      end

      api_instance.public_send(sym, *positional, **kwargs)
    rescue ArgumentError => e
      abort_with_error(
        format('invalid arguments for %<method>s: %<error>s', method: method_name, error: e.message)
      )
    end

    def invoke_utils(method_name, kwargs: {}, positional: [])
      sym = method_name.to_sym
      unless CLIHelpers.utils_callable_methods.include?(sym)
        abort_with_error(
          format('unknown utils method: %<method>s', method: method_name)
        )
      end

      MixinBot.utils.public_send(sym, *positional, **kwargs)
    rescue ArgumentError => e
      abort_with_error(
        format('invalid arguments for utils.%<method>s: %<error>s', method: method_name, error: e.message)
      )
    end

    def print_result(obj, data_only: false)
      out =
        case obj
        when MixinBot::Models::ApiEnvelope
          data_only ? (obj['data'] || obj.to_h) : obj.to_h
        when Hash
          data_only ? (obj['data'] || obj) : obj
        else
          obj
        end

      log(out)
    end

    def abort_with_error(message)
      $stderr.puts(UI.fmt("{{x}} #{message}"))
      exit(1)
    end

    def warn_deprecated(message)
      $stderr.puts(UI.fmt("{{yellow}} warning: #{message}"))
    end

    def log(obj)
      if options[:pretty]
        if obj.is_a?(String)
          puts obj
        else
          ap obj
        end
      else
        puts obj.inspect
      end
    end
  end
end

require_relative 'cli/call'
require_relative 'cli/api'
require_relative 'cli/node'
require_relative 'cli/utils'

module MixinBot
  class CLI
    if system('which mixin > /dev/null 2>&1')
      desc 'node SUBCOMMAND', 'Experimental mixin node CLI helpers (requires `mixin` binary)'
      subcommand 'node', NodeCLI
    end
  end
end
