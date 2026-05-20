# frozen_string_literal: true

module MixinBot
  ##
  # Maps exceptions and messages to clispec error kinds for structured CLI output.
  #
  module CLIErrors
    ERROR_KINDS = {
      invalid_args: { retryable: false, description: 'Invalid or missing arguments' },
      auth: { retryable: false, description: 'Authentication or authorization failed' },
      not_found: { retryable: false, description: 'Requested resource was not found' },
      api_error: { retryable: false, description: 'Mixin API returned an error' },
      unsupported: { retryable: false, description: 'Operation is not supported in this context' },
      conflict: { retryable: false, description: 'Resource exists with incompatible configuration' },
      internal: { retryable: false, description: 'Unexpected internal error' }
    }.freeze

    module_function

    def schema_errors
      ERROR_KINDS.map do |kind, meta|
        {
          'kind' => kind.to_s,
          'retryable' => meta[:retryable],
          'description' => meta[:description]
        }
      end
    end

    def kind_for_exception(error)
      case error
      when MixinBot::ArgumentError, ::ArgumentError
        :invalid_args
      when UnauthorizedError, ForbiddenError, PinError, ConfigurationNotValidError
        :auth
      when NotFoundError, UserNotFoundError
        :not_found
      when ResponseError, RequestError, HttpError,
           InsufficientBalanceError, UtxoInsufficientError, InsufficientPoolError
        :api_error
      else
        :internal
      end
    end

    def kind_for_message(message)
      msg = message.to_s.downcase
      return :auth if msg.include?('unauthorized') || msg.include?('authentication')
      return :not_found if msg.include?('not found') || msg.include?('404')
      return :unsupported if msg.include?('unsupported') || msg.include?('not supported')
      return :invalid_args if msg.include?('invalid') || msg.include?('unknown')

      :internal
    end
  end
end
