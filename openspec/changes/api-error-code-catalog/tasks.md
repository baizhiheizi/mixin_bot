## 1. Tests first (ErrorMapper)

- [x] 1.1 Add `test/mixin_bot/client/test_error_mapper.rb` with helpers to invoke `ErrorMapper.raise_for!` using stub Faraday responses
- [x] 1.2 Add failing tests for every official error code in the catalog (expected exception class per spec table)
- [x] 1.3 Add failing tests for legacy codes (20121, 20118, 20119, 30103, 10404) and unknown code 99999 → `ResponseError`
- [x] 1.4 Add failing tests for `retryable?`, `throttle?`, and `Retry-After` on `RateLimitError`
- [x] 1.5 Add failing tests for HTTP status fallback (429/401/403/500 with blank JSON error) via `Client#parse_response!`

## 2. APIError base and exception classes

- [x] 2.1 Add `MixinBot::APIError` base class in `lib/mixin_bot/errors.rb` with structured readers and default `retryable?` / `throttle?` / `client_error?`
- [x] 2.2 Add new subclasses: `RateLimitError`, `ValidationError`, `ConflictError`, `TransferError`, `TransientError`, `AppUpdateRequiredError`, `InvalidAddressFormatError`, `ServerError`
- [x] 2.3 Migrate existing API exception classes (`UnauthorizedError`, `ForbiddenError`, `NotFoundError`, `InsufficientBalanceError`, `PinError`, `UserNotFoundError`, `InsufficientPoolError`, `ResponseError`) to inherit from `APIError` with backward-compatible `#message`
- [x] 2.4 Add `MixinBot.retryable?(error)` module function in `lib/mixin_bot/errors.rb` (or dedicated module) implementing canonical policy

## 3. ErrorMapper refactor

- [x] 3.1 Replace `case code` branch with `ErrorMapper::CODE_MAP` registry aligned to official docs + legacy codes
- [x] 3.2 Implement `APIError.build(verb:, path:, body:, response:, result:)` factory populating all structured fields including `extra` and `retry_after`
- [x] 3.3 Split `429` → `RateLimitError`; restrict `ForbiddenError` to code `403`; reclassify `10002`, `20116` per design

## 4. Client parse_response! HTTP fallback

- [x] 4.1 Update `Client#parse_response!` to check HTTP status when `result['error']` is blank (429, 401, 403, >=500)
- [x] 4.2 Ensure primary JSON error path on HTTP 202 remains unchanged

## 5. Monitor and CLI alignment

- [x] 5.1 Update `Monitor.check_retryable_error` to delegate to `MixinBot.retryable?(error)`
- [x] 5.2 Add `rate_limit` to `CLIErrors::ERROR_KINDS` and map `RateLimitError` in `kind_for_exception`
- [x] 5.3 Map `ValidationError` and `InvalidAddressFormatError` to `invalid_args` kind
- [x] 5.4 Extend structured CLI error output with `code`, `request_id`, and `throttle` when available
- [x] 5.5 Add/update tests in `test/mixin_bot/cli/test_errors.rb` and monitor tests

## 6. Documentation and release

- [x] 6.1 Bump `MixinBot::VERSION` to `2.3.0`
- [x] 6.2 Add CHANGELOG entry documenting **BREAKING** exception reclassification and migration guide
- [x] 6.3 Update README error handling section and `docs/agent/cli.md` with new kinds and `MixinBot.retryable?`
- [x] 6.4 Run `rake` (tests + rubocop) and fix any failures
