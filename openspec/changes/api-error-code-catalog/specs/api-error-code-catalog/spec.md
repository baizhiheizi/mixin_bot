## ADDED Requirements

### Requirement: APIError structured base class

The SDK SHALL define `MixinBot::APIError` as the base class for exceptions raised from Mixin API error responses.

Each `APIError` instance SHALL expose readers for `code`, `description`, `status`, `http_status`, `request_id`, `server_time`, `path`, `verb`, and `body`.

When the API error object includes an `extra` field, the SDK SHALL expose it via an `extra` reader.

The `#message` string SHALL retain the existing formatted shape including verb, path, errcode, errmsg, request_id, and server_time.

#### Scenario: Structured fields populated from API response

- **WHEN** the API returns `{ "error": { "code": 403, "description": "Forbidden", "status": 403 } }`
- **THEN** the raised exception is a `APIError` subclass
- **AND** `error.code` equals `403`
- **AND** `error.description` equals `"Forbidden"`
- **AND** `error.request_id` is populated from the `X-Request-Id` response header when present

### Requirement: Official error code catalog mapping

The SDK SHALL map every error code listed in the [Mixin API error codes documentation](https://developers.mixin.one/docs/api/error-codes) to a dedicated typed exception as defined below.

| Code | Exception class |
|------|-----------------|
| 400 | `ValidationError` |
| 401 | `UnauthorizedError` |
| 403 | `ForbiddenError` |
| 404 | `NotFoundError` |
| 429 | `RateLimitError` |
| 10002 | `ValidationError` |
| 10006 | `AppUpdateRequiredError` |
| 10104 | `TransientError` |
| 10105 | `TransientError` |
| 20116 | `ConflictError` |
| 20117 | `InsufficientBalanceError` |
| 20120 | `TransferError` |
| 20123 | `ConflictError` |
| 20124 | `InsufficientBalanceError` |
| 20125 | `ConflictError` |
| 20127 | `TransferError` |
| 20131 | `ValidationError` |
| 20133 | `ConflictError` |
| 20134 | `TransferError` |
| 20135 | `TransferError` |
| 20150 | `ValidationError` |
| 30102 | `InvalidAddressFormatError` |
| 500 | `ServerError` |
| 7000 | `ServerError` |
| 7001 | `ServerError` |

#### Scenario: Rate limit code 429

- **WHEN** the API returns error code `429`
- **THEN** the SDK raises `MixinBot::RateLimitError`
- **AND** does not raise `ForbiddenError`

#### Scenario: Invalid field code 10002

- **WHEN** the API returns error code `10002` with an `extra` payload
- **THEN** the SDK raises `MixinBot::ValidationError`
- **AND** `error.extra` contains the API `extra` value

#### Scenario: Group full code 20116

- **WHEN** the API returns error code `20116`
- **THEN** the SDK raises `MixinBot::ConflictError`
- **AND** does not raise `ForbiddenError`

#### Scenario: Locked by another transaction code 10105

- **WHEN** the API returns error code `10105`
- **THEN** the SDK raises `MixinBot::TransientError`

#### Scenario: Server error code 500

- **WHEN** the API returns error code `500`
- **THEN** the SDK raises `MixinBot::ServerError`

### Requirement: Legacy undocumented code mapping

The SDK SHALL continue to map the following undocumented codes to their existing exception types with structured `APIError` fields:

| Code | Exception class |
|------|-----------------|
| 20121 | `UnauthorizedError` |
| 20118 | `PinError` |
| 20119 | `PinError` |
| 30103 | `InsufficientPoolError` |
| 10404 | `UserNotFoundError` |

#### Scenario: PIN error code 20118

- **WHEN** the API returns error code `20118`
- **THEN** the SDK raises `MixinBot::PinError` with structured fields

### Requirement: Unknown error codes

When the API returns an error code not in the catalog or legacy list, the SDK SHALL raise `MixinBot::ResponseError` with populated `APIError` fields.

#### Scenario: Unmapped code falls through

- **WHEN** the API returns error code `99999`
- **THEN** the SDK raises `MixinBot::ResponseError`
- **AND** `error.code` equals `99999`

### Requirement: RateLimitError throttle semantics

`MixinBot::RateLimitError` SHALL implement `throttle?` returning `true`.

`MixinBot::RateLimitError` SHALL implement `retryable?` returning `false`.

When the HTTP response includes a `Retry-After` header, `RateLimitError` SHALL expose its value via a `retry_after` reader.

#### Scenario: Throttle flag on rate limit

- **WHEN** the API returns error code `429`
- **THEN** the raised `RateLimitError` has `throttle?` equal to `true`
- **AND** `retryable?` equal to `false`

#### Scenario: Retry-After header captured

- **WHEN** the API returns error code `429`
- **AND** the response includes `Retry-After: 60`
- **THEN** the raised `RateLimitError` has `retry_after` equal to `"60"`

### Requirement: Canonical retry policy

The SDK SHALL provide `MixinBot.retryable?(error)` as the single canonical retry decision function.

`MixinBot.retryable?(error)` SHALL return `true` for `Faraday::TimeoutError` and `Faraday::ConnectionFailed`.

`MixinBot.retryable?(error)` SHALL return `true` for `ServerError` and for `ResponseError` when `error.code >= 500`.

`MixinBot.retryable?(error)` SHALL return `true` for `TransientError` (codes 10104, 10105).

`MixinBot.retryable?(error)` SHALL return `false` for all other typed API errors including `RateLimitError`, `InsufficientBalanceError`, `ForbiddenError`, and `PinError`.

#### Scenario: Insufficient balance not retryable

- **WHEN** the API returns error code `20117`
- **THEN** `MixinBot.retryable?(error)` returns `false`

#### Scenario: Transient lock retryable

- **WHEN** the API returns error code `10105`
- **THEN** `MixinBot.retryable?(error)` returns `true`

#### Scenario: Rate limit not retryable

- **WHEN** the API returns error code `429`
- **THEN** `MixinBot.retryable?(error)` returns `false`

#### Scenario: Server error retryable

- **WHEN** the API returns error code `500`
- **THEN** `MixinBot.retryable?(error)` returns `true`

### Requirement: Monitor delegates to canonical retry policy

`MixinBot::Monitor.check_retryable_error` SHALL delegate to `MixinBot.retryable?(error)`.

#### Scenario: Monitor no longer retries insufficient balance by substring

- **WHEN** `check_retryable_error` is called with an `InsufficientBalanceError`
- **THEN** it returns `false`

### Requirement: HTTP status fallback

When the response body has no `error` object, the SDK SHALL classify errors by HTTP status before returning a success envelope.

| HTTP status | Exception |
|-------------|-----------|
| 429 | `RateLimitError` |
| 401 | `UnauthorizedError` |
| 403 | `ForbiddenError` |
| >= 500 | `ServerError` |

#### Scenario: CDN HTTP 429 without JSON error

- **WHEN** the HTTP response status is `429`
- **AND** the parsed body has no `error` key
- **THEN** the SDK raises `RateLimitError`

#### Scenario: Normal Mixin JSON error on HTTP 202

- **WHEN** the HTTP response status is `202`
- **AND** the body contains `{ "error": { "code": 429, ... } }`
- **THEN** the SDK raises `RateLimitError` via JSON code mapping

### Requirement: ErrorMapper unit tests

The SDK SHALL include unit tests for `MixinBot::Client::ErrorMapper` covering every mapped official code, legacy code, unknown code, and HTTP status fallback paths.

#### Scenario: Full catalog test coverage

- **WHEN** the test suite runs offline
- **THEN** each official error code in the catalog has at least one test asserting the expected exception class

### Requirement: CLI rate_limit error kind

The CLI SHALL map `RateLimitError` to structured error kind `rate_limit` when using JSON or YAML output.

The CLI error schema SHALL include a `rate_limit` kind with `retryable: false`.

Structured CLI error output for API errors SHOULD include `code` and `request_id` when available.

#### Scenario: Structured rate limit error

- **WHEN** a CLI API call fails with `RateLimitError`
- **AND** output format is JSON
- **THEN** stderr contains `"kind": "rate_limit"`
