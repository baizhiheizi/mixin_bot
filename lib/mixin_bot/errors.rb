# frozen_string_literal: true

module MixinBot
  ##
  # Base error class for all MixinBot errors.
  #
  class Error < StandardError; end

  ##
  # Raised when invalid arguments are provided (local validation, not API code 400).
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
  # Base class for Mixin API error responses with structured metadata.
  #
  class APIError < Error
    attr_reader :code, :description, :status, :http_status, :request_id, :server_time,
                :retry_after, :extra, :path, :verb, :body

    # rubocop:disable Metrics/ParameterLists -- structured API error metadata
    def initialize(message = nil, code: nil, description: nil, status: nil, http_status: nil,
                   request_id: nil, server_time: nil, retry_after: nil, extra: nil,
                   path: nil, verb: nil, body: nil)
      @code = code&.to_i
      @description = description
      @status = status&.to_i
      @http_status = http_status&.to_i
      @request_id = request_id
      @server_time = server_time
      @retry_after = retry_after
      @extra = extra
      @path = path
      @verb = verb
      @body = body
      super(message || formatted_message)
    end
    # rubocop:enable Metrics/ParameterLists

    def client_error?
      c = code.to_i
      return true if c.between?(400, 499)
      return true if http_status == 202 && c.positive? && c < 500

      false
    end

    def retryable?
      false
    end

    def throttle?
      false
    end

    def formatted_message
      format(
        '%<verb>s | %<path>s | %<body>s, errcode: %<code>s, errmsg: %<description>s, ' \
        'request_id: %<request_id>s, server_time: %<server_time>s',
        verb: verb.to_s.upcase,
        path: path.to_s,
        body: body.to_s,
        code: code,
        description: description,
        request_id: request_id,
        server_time: server_time
      )
    end

    class << self
      def build(klass, verb:, path:, body:, response:, result:, code: nil, description: nil)
        err = result.is_a?(Hash) ? (result['error'] || {}) : {}
        resolved_code = code || err['code'] || infer_code_from_http(response)
        resolved_description = description || err['description'] || http_status_description(response&.status)
        headers = response&.headers || {}
        retry_after = headers['Retry-After'] if klass <= RateLimitError

        klass.new(
          code: resolved_code,
          description: resolved_description,
          status: err['status'],
          http_status: response&.status,
          request_id: headers['X-Request-Id'],
          server_time: headers['X-Server-Time'],
          retry_after: retry_after,
          extra: err['extra'],
          path: path,
          verb: verb,
          body: body
        )
      end

      private

      def infer_code_from_http(response)
        return nil unless response

        case response.status
        when 401 then 401
        when 403 then 403
        when 429 then 429
        else
          response.status if response.status >= 500
        end
      end

      def http_status_description(status)
        case status
        when 401 then 'Unauthorized'
        when 403 then 'Forbidden'
        when 429 then 'Too Many Requests'
        when 500.. then 'Internal Server Error'
        else
          "HTTP #{status}"
        end
      end
    end
  end

  ##
  # Raised when Mixin API returns an error response (unmapped or generic codes).
  #
  class ResponseError < APIError
    def retryable?
      code.to_i >= 500
    end
  end

  ##
  # Raised when a requested resource is not found (error code 404).
  #
  class NotFoundError < APIError; end

  ##
  # Raised when a user is not found (error code 10404).
  #
  class UserNotFoundError < APIError; end

  ##
  # Raised when authentication fails (error codes 401, 20121).
  #
  class UnauthorizedError < APIError; end

  ##
  # Raised when access is forbidden (error code 403).
  #
  class ForbiddenError < APIError; end

  ##
  # Raised when the API rate limit is exceeded (error code 429).
  #
  class RateLimitError < APIError
    def throttle?
      true
    end
  end

  ##
  # Raised when request data is invalid (error codes 400, 10002, 20131, 20150).
  #
  class ValidationError < APIError; end

  ##
  # Raised when a resource conflict or capacity limit applies (error codes 20116, 20123, 20125, 20133).
  #
  class ConflictError < APIError; end

  ##
  # Raised for transfer/withdraw amount or fee constraints.
  #
  class TransferError < APIError; end

  ##
  # Raised for transient conditions that may succeed on retry (error codes 10104, 10105).
  #
  class TransientError < APIError
    def retryable?
      true
    end
  end

  ##
  # Raised when the app must be updated (error code 10006).
  #
  class AppUpdateRequiredError < APIError; end

  ##
  # Raised when an address format is invalid (error code 30102).
  #
  class InvalidAddressFormatError < APIError; end

  ##
  # Raised for server-side failures (error codes 500, 7000, 7001).
  #
  class ServerError < APIError
    def retryable?
      true
    end
  end

  ##
  # Raised when there is insufficient balance for a transaction (error codes 20117, 20124).
  #
  class InsufficientBalanceError < APIError; end

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

    def initialize(message = nil, total_input: nil, total_output: nil, output_size: nil, **)
      super(message, **)
      @total_input = total_input
      @total_output = total_output
      @output_size = output_size
    end
  end

  ##
  # Raised when there is insufficient pool for a transaction (error code 30103).
  #
  class InsufficientPoolError < APIError; end

  ##
  # Raised when PIN verification fails (error codes 20118, 20119).
  #
  class PinError < APIError; end

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

  class << self
    ##
    # Canonical retry decision for API and network failures.
    #
    def retryable?(error)
      return true if error.is_a?(Faraday::TimeoutError) || error.is_a?(Faraday::ConnectionFailed)
      return error.retryable? if error.respond_to?(:retryable?)

      false
    end
  end
end
