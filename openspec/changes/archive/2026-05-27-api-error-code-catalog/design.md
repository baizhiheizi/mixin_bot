## Context

Mixin API errors arrive as JSON `{ "error": { "status", "code", "description", ... } }` with HTTP **202** for most client errors and **500** for server errors ([error codes docs](https://developers.mixin.one/docs/api/error-codes)). `MixinBot::Client::ErrorMapper` today maps a small subset via a `case code` branch, bundling unrelated codes into `ForbiddenError` and raising plain strings with metadata embedded in `#message`.

Downstream hosts (OhMy.xin SafeTransaction pipeline, Redis job workers) need typed errors and a single retry policy. `Monitor.check_retryable_error` uses substring heuristics that contradict both the official code semantics and consumer expectations (e.g. retries on `InsufficientBalanceError`). There are no unit tests for `ErrorMapper`.

Existing precedent: `InsufficientAppBillingError` and `UtxoInsufficientError` already expose structured fields; this change generalizes that pattern.

## Goals / Non-Goals

**Goals:**

- Map every code in the [official error codes table](https://developers.mixin.one/docs/api/error-codes) to a typed `APIError` subclass.
- Preserve backward-compatible `#message` format for logging (same string shape as today).
- Provide `MixinBot.retryable?(error)` as canonical retry policy.
- Provide `throttle?` / `retry_after` on `RateLimitError` for platform backoff.
- HTTP-status fallback for non-standard responses (CDN 429, web-server 5xx).
- Full `ErrorMapper` unit test matrix.
- CLI kind `rate_limit`; align `Monitor.check_retryable_error` to delegate.

**Non-Goals:**

- Automatic client-side retry inside the Faraday stack (unchanged: network failures only).
- Mapping every possible undocumented code Mixin may add in future (unknown codes → `ResponseError` with structured fields).
- Refactoring `Computer` client or MVM error types (separate clients).
- Changing `InsufficientAppBillingError` (local preflight, not API envelope).

## Decisions

### 1. `APIError` base class

**Decision:** Introduce `MixinBot::APIError < Error` with readers:

| Attribute | Source |
|-----------|--------|
| `code` | `error.code` (Integer) |
| `description` | `error.description` |
| `status` | `error.status` (JSON body field) |
| `http_status` | Faraday `response.status` |
| `request_id` | `X-Request-Id` header |
| `server_time` | `X-Server-Time` header |
| `retry_after` | `Retry-After` header (RateLimitError only, optional) |
| `extra` | `error.extra` when present (ValidationError) |
| `path`, `verb`, `body` | request context |

`#message` remains the formatted string: `"GET | /me | {}, errcode: 429, errmsg: …"`.

**Behavior defaults on `APIError`:**

```ruby
def client_error? = code.to_i.between?(400, 499) || (http_status == 202 && code < 500)
def retryable?     = false
def throttle?      = false
```

Subclasses override where needed. `ServerError` (500 family) sets `retryable? → true`.

**Alternative considered:** Flat errors with only `#code` reader — rejected; insufficient for `extra`, headers, retry policy.

### 2. Exception taxonomy and code catalog

**Decision:** Central registry `ErrorMapper::CODE_MAP` (Hash) mapping Integer code → exception class. Raise via factory `APIError.build(...)`.

| Code | Official description | Exception class | retryable? | throttle? |
|------|---------------------|-----------------|------------|-----------|
| 400 | Request body not valid JSON/data | `ValidationError` | false | false |
| 401 | Unauthorized | `UnauthorizedError` | false | false |
| 403 | Forbidden | `ForbiddenError` | false | false |
| 404 | Endpoint not found | `NotFoundError` | false | false |
| 429 | Too Many Requests | `RateLimitError` | false | **true** |
| 10002 | Invalid field (see `extra`) | `ValidationError` | false | false |
| 10006 | App update required | `AppUpdateRequiredError` | false | false |
| 10104 | Address generating | `TransientError` | **true** | false |
| 10105 | Locked by another transaction | `TransientError` | **true** | false |
| 20116 | Group chat is full | `ConflictError` | false | false |
| 20117 | Insufficient balance | `InsufficientBalanceError` | false | false |
| 20120 | Transfer amount too small | `TransferError` | false | false |
| 20123 | Too many apps | `ConflictError` | false | false |
| 20124 | Insufficient fee | `InsufficientBalanceError` | false | false |
| 20125 | Transfer paid by someone else | `ConflictError` | false | false |
| 20127 | Withdraw amount too small | `TransferError` | false | false |
| 20131 | Withdrawal memo format incorrect | `ValidationError` | false | false |
| 20133 | Too many circles | `ConflictError` | false | false |
| 20134 | Withdraw amount too large | `TransferError` | false | false |
| 20135 | Withdraw fee too small | `TransferError` | false | false |
| 20150 | Invalid receivers | `ValidationError` | false | false |
| 30102 | Invalid address format | `InvalidAddressFormatError` | false | false |
| 500 | Internal Server Error | `ServerError` | **true** | false |
| 7000 | Blaze server error | `ServerError` | **true** | false |
| 7001 | Blaze operation timeout | `ServerError` | **true** | false |

**Undocumented codes (keep existing gem behavior, now structured):**

| Code | Exception class | Notes |
|------|-----------------|-------|
| 20121 | `UnauthorizedError` | Legacy; retain until confirmed removed |
| 20118, 20119 | `PinError` | PIN verification |
| 30103 | `InsufficientPoolError` | Pool liquidity |
| 10404 | `UserNotFoundError` | User lookup |

**Unknown codes:** `ResponseError` with populated `APIError` fields; `retryable?` true when `code >= 500` or `http_status >= 500`.

**Alternative considered:** One exception per code (25+ classes) — rejected; group by remediation semantics (validation, conflict, transient, server).

### 3. Split ForbiddenError bundle (**BREAKING**)

**Decision:** Remove `429`, `10002`, `20116` from the `ForbiddenError` branch. `ForbiddenError` maps **403 only** (+ legacy 20121 stays on `UnauthorizedError` per table above).

**Rationale:** Aligns with official semantics; unblocks OhMy.xin throttle vs circuit-break.

### 4. `parse_response!` layering

**Decision:** Process in order:

```
1. Parse response.body as Hash
2. If response.status == 429 AND body.error blank → RateLimitError (HTTP fallback)
3. If response.status == 401/403 AND body.error blank → UnauthorizedError/ForbiddenError
4. If response.status >= 500 AND body.error blank → ServerError
5. If body.error present → ErrorMapper.raise_for! (primary Mixin path, HTTP usually 202)
6. Else → ApiEnvelope success
```

**Rationale:** Mixin primary path is JSON on HTTP 202; HTTP checks cover CDN/proxy edge cases only.

### 5. Canonical `MixinBot.retryable?(error)`

**Decision:** Module function delegating to `error.retryable?` when available; fallback:

| Condition | retryable? |
|-----------|------------|
| `Faraday::TimeoutError`, `Faraday::ConnectionFailed` | true |
| `MixinBot::APIError` subclass | class default |
| `InsufficientAppBillingError`, `PinError`, typed 4xx | false |
| Plain `StandardError` | false |

`Monitor.check_retryable_error(error)` → delegates to `MixinBot.retryable?(error)` (**BREAKING**: no longer retries on `'insufficient'` substring).

**Alternative considered:** Keep Monitor heuristics as override — rejected; perpetuates conflicting policies.

### 6. CLI error kinds

**Decision:**

| Exception | CLI kind | retryable in schema |
|-----------|----------|---------------------|
| `RateLimitError` | `rate_limit` | false (+ document `throttle: true` in structured output) |
| `UnauthorizedError`, `ForbiddenError`, `PinError` | `auth` | false |
| `ValidationError`, `InvalidAddressFormatError` | `invalid_args` | false |
| `InsufficientBalanceError`, `UtxoInsufficientError`, … | `api_error` | false |
| `ServerError`, retryable `ResponseError` | `api_error` | true |
| `ConflictError`, `TransferError`, … | `api_error` | false |

Extend structured JSON error payload with optional `code`, `request_id`, `throttle` fields when `--output json`.

### 7. Tests first in implementation

**Decision:** Land `test/mixin_bot/client/test_error_mapper.rb` before changing production mapping; expand until green after refactor.

### 8. Version bump

**Decision:** Release as **2.3.0** (minor). Document breaking rescues in `CHANGELOG.md`.

## Risks / Trade-offs

| Risk | Mitigation |
|------|------------|
| **BREAKING** callers rescue `ForbiddenError` for 429 | CHANGELOG + migration note; rescue `RateLimitError` or `APIError` |
| **BREAKING** Monitor no longer retries insufficient balance | Correct behavior; document; codes 10104/10105 still retry via `TransientError` |
| Undocumented codes change class | Only documented codes reclassified; legacy codes keep prior class names |
| Official docs lag production | Registry is a single Hash; easy to extend |
| `extra` field shape varies | Expose raw `extra`; don't parse |
| HTTP 202 success with error object missed | Primary path unchanged; tests assert JSON error path |

## Migration Plan

1. Ship 2.3.0 with CHANGELOG breaking section.
2. Consumers update rescues:
   - `rescue MixinBot::ForbiddenError` for throttle → add `RateLimitError`
   - Platform backoff → `error.throttle?` on `RateLimitError`
   - Job retry → `MixinBot.retryable?(error)` instead of string checks
3. OhMy.xin can adopt incrementally: `RateLimitError` first, then structured fields.

**Rollback:** Revert to 2.2.x mapping; consumers on new rescues would need revert too.

## Open Questions

- Should structured CLI JSON add top-level `throttle: true` or nest under `error.meta`? **Lean:** nest under `error` alongside `kind`, `code`, `request_id`.
- Live confirmation that `20121` still appears in production. **Mitigation:** keep mapped; add test stub.
