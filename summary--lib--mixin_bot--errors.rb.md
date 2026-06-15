# lib/mixin_bot/errors.rb

Base `MixinBot::Error < StandardError`. `APIError` carries code/description/status/http_status/request_id/server_time/retry_after/extra/path/verb/body. Predicates: `client_error?` (400-499 range, or http_status==202 with positive sub-500 code), `retryable?` (false default), `throttle?` (false default).

Subclasses: ResponseError (retryable >=500), UnauthorizedError, ForbiddenError, RateLimitError (throttle? true), ValidationError, ConflictError, TransferError, TransientError (retryable true), ServerError (retryable true), InsufficientBalanceError, UtxoInsufficientError (subclass with total_input/total_output/output_size), InsufficientPoolError, PinError, NotFoundError, UserNotFoundError, AppUpdateRequiredError, InvalidAddressFormatError, HttpError, RequestError.

Non-API: ArgumentError, InsufficientAppBillingError (app_id/credit/cost/increment), InvalidNfoFormatError, InvalidUuidFormatError, InvalidTransactionFormatError, ConfigurationNotValidError, InvalidInvoiceFormatError.

Class helper: `MixinBot.retryable?(error)` returns true for Faraday::TimeoutError/ConnectionFailed, else delegates to error.retryable?.