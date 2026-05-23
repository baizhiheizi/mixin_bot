# frozen_string_literal: true

module MixinBot
  ##
  # Base error class for all MixinBot errors.
  #
  class Error < StandardError; end

  ##
  # Raised when invalid arguments are provided.
  #
  class ArgumentError < StandardError; end

  ##
  # Raised when HTTP request fails.
  #
  class HttpError < Error; end

  ##
  # Raised when a request to Mixin API fails.
  #
  class RequestError < Error; end

  ##
  # Raised when Mixin API returns an error response.
  #
  class ResponseError < Error; end

  ##
  # Raised when a requested resource is not found (HTTP 404).
  #
  class NotFoundError < Error; end

  ##
  # Raised when a user is not found (error code 10404).
  #
  class UserNotFoundError < Error; end

  ##
  # Raised when authentication fails (HTTP 401).
  #
  class UnauthorizedError < Error; end

  ##
  # Raised when access is forbidden (HTTP 403).
  #
  class ForbiddenError < Error; end

  ##
  # Raised when there is insufficient balance for a transaction (error code 20117).
  #
  class InsufficientBalanceError < Error; end

  ##
  # Raised when app prepaid billing credit lacks headroom for a billed operation.
  #
  class InsufficientAppBillingError < Error
    attr_reader :app_id, :credit, :cost, :increment

    def initialize(app_id:, credit:, cost:, increment:)
      @app_id = app_id
      @credit = credit
      @cost = cost
      @increment = increment
      super(
        format(
          'app billing insufficient: credit %<credit>s <= cost %<cost>s + increment %<increment>s (app_id=%<app_id>s)',
          credit:, cost:, increment:, app_id:
        )
      )
    end
  end

  ##
  # Raised when selected UTXOs cannot cover the requested amount (mirrors Go +UtxoInsufficientError+).
  #
  class UtxoInsufficientError < InsufficientBalanceError
    attr_reader :total_input, :total_output, :output_size

    def initialize(message, total_input: nil, total_output: nil, output_size: nil)
      super(message)
      @total_input = total_input
      @total_output = total_output
      @output_size = output_size
    end
  end

  ##
  # Raised when there is insufficient pool for a transaction (error code 30103).
  #
  class InsufficientPoolError < Error; end

  ##
  # Raised when PIN verification fails (error codes 20118, 20119).
  #
  class PinError < Error; end

  ##
  # Raised when NFO memo format is invalid.
  #
  class InvalidNfoFormatError < Error; end

  ##
  # Raised when UUID format is invalid.
  #
  class InvalidUuidFormatError < Error; end

  ##
  # Raised when transaction format is invalid.
  #
  class InvalidTransactionFormatError < Error; end

  ##
  # Raised when configuration is not valid or incomplete.
  #
  class ConfigurationNotValidError < Error; end

  ##
  # Raised when invoice format is invalid.
  #
  class InvalidInvoiceFormatError < Error; end
end
