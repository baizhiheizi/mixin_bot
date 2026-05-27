# frozen_string_literal: true

require 'json'
require 'yaml'

module MixinBot
  ##
  # Structured and human-friendly stdout/stderr formatting for mixinbot.
  #
  module CLIOutput
    OUTPUT_FORMATS = %w[pretty json yaml].freeze

    def cli_options
      merged = options.dup
      merged = parent_options.merge(merged) if respond_to?(:parent_options) && parent_options.present?
      merged
    end

    def output_format
      opts = cli_options
      explicit = opts[:output].to_s.downcase if opts[:output].present?
      return explicit if OUTPUT_FORMATS.include?(explicit)

      return 'json' if opts.key?(:pretty) && opts[:pretty] == false

      $stdout.tty? ? 'pretty' : 'json'
    end

    def structured_output?
      %w[json yaml].include?(output_format)
    end

    def current_command_name
      @current_command_name || self.class.name.split('::').last.sub(/CLI\z/, '').downcase
    end

    def with_command_name(name)
      previous = @current_command_name
      @current_command_name = name
      yield
    ensure
      @current_command_name = previous
    end

    def emit_success(data, command: nil)
      command_name = command || current_command_name
      if structured_output?
        write_stdout(encode_output(envelope('ok', command_name, data)))
      else
        write_pretty(data)
      end
    end

    def emit_list(items:, total:, limit:, offset:, command: 'list')
      payload = {
        'items' => items,
        'total' => total,
        'limit' => limit,
        'offset' => offset
      }
      emit_success(payload, command:)
    end

    def emit_info(message)
      return if message.blank?

      if structured_output?
        warn(message)
      else
        warn(format_info(message))
      end
    end

    def abort_with_error(message, kind: nil, hint: nil, exception: nil)
      resolved_kind = kind || (exception && CLIErrors.kind_for_exception(exception)) || CLIErrors.kind_for_message(message)
      hint ||= default_error_hint

      if structured_output?
        error_body = {
          'status' => 'error',
          'error' => {
            'kind' => resolved_kind.to_s,
            'message' => message.to_s
          }
        }
        error_body['error']['hint'] = hint if hint.present?
        if exception.is_a?(MixinBot::APIError)
          error_body['error']['code'] = exception.code unless exception.code.nil?
          error_body['error']['request_id'] = exception.request_id if exception.request_id.present?
          error_body['error']['throttle'] = true if exception.respond_to?(:throttle?) && exception.throttle?
        end
        warn(JSON.generate(error_body))
      else
        warn(format_error(message))
      end
      exit(1)
    end

    def print_result(obj, data_only: false, command: nil)
      out =
        case obj
        when MixinBot::Models::ApiEnvelope
          data_only ? (obj['data'] || obj.to_h) : obj.to_h
        when Hash
          data_only ? (obj['data'] || obj) : obj
        else
          obj
        end

      emit_success(out, command:)
    end

    def log(obj)
      emit_success(obj)
    end

    def paginate_items(items, limit:, offset:)
      limit = limit.to_i
      offset = offset.to_i
      limit = 100 if limit <= 0
      offset = 0 if offset.negative?

      total = items.size
      slice = items.drop(offset).first(limit)
      [slice, total, limit, offset]
    end

    def select_fields(items, fields)
      return items if fields.blank?

      keys = fields.split(',').map(&:strip).reject(&:empty?)
      return items if keys.empty?

      items.map do |item|
        item.slice(*keys)
      end
    end

    private

    def envelope(status, command, data)
      {
        'status' => status,
        'command' => command,
        'data' => normalize_data(data)
      }
    end

    def normalize_data(data)
      case data
      when MixinBot::Models::ApiEnvelope
        data.to_h
      when Hash
        data.transform_keys(&:to_s)
      else
        data
      end
    end

    def encode_output(payload)
      case output_format
      when 'yaml'
        payload.to_yaml
      else
        JSON.generate(payload)
      end
    end

    def write_stdout(text)
      puts text
    end

    def write_pretty(obj)
      if obj.is_a?(String)
        puts obj
      else
        ap obj
      end
    end

    def format_info(message)
      if defined?(UI) && UI.respond_to?(:fmt)
        UI.fmt(message.to_s)
      else
        message.to_s
      end
    end

    def format_error(message)
      if defined?(UI) && UI.respond_to?(:fmt)
        UI.fmt("{{x}} #{message}")
      else
        "Error: #{message}"
      end
    end

    def default_error_hint
      'Run `mixinbot help` or `mixinbot schema -o json` for usage'
    end
  end
end
