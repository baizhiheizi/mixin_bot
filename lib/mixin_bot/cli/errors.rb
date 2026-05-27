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
      rate_limit: { retryable: false, description: 'API rate limit exceeded; slow down globally' },
      api_error: { retryable: false, description: 'Mixin API returned an error' },
      unsupported: { retryable: false, description: 'Operation is not supported in this context' },
      conflict: { retryable: false, description: 'Resource exists with incompatible configuration' },
      billing: { retryable: false, description: 'App billing credit insufficient for the operation' },
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
      when MixinBot::ArgumentError, ::ArgumentError, ValidationError, InvalidAddressFormatError
        :invalid_args
      when RateLimitError
        :rate_limit
      when UnauthorizedError, ForbiddenError, PinError, ConfigurationNotValidError
        :auth
      when NotFoundError, UserNotFoundError
        :not_found
      when InsufficientAppBillingError
        :billing
      when ResponseError, RequestError, HttpError, ServerError,
           InsufficientBalanceError, UtxoInsufficientError, InsufficientPoolError,
           ConflictError, TransferError, TransientError, AppUpdateRequiredError
        :api_error
      else
        :internal
      end
    end

    def kind_for_message(message)
      msg = message.to_s.downcase
      return :auth if msg.include?('unauthorized') || msg.include?('authentication')
      return :not_found if msg.include?('not found') || msg.include?('404')
      return :rate_limit if msg.include?('too many requests') || msg.include?('errcode: 429')
      return :unsupported if msg.include?('unsupported') || msg.include?('not supported')
      return :invalid_args if msg.include?('invalid') || msg.include?('unknown')

      :internal
    end
  end
end
