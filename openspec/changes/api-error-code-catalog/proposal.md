## Why

MixinBot maps many distinct API error codes to a handful of opaque string exceptions. Code `429` (rate limit) is raised as `ForbiddenError` alongside `403`, `10002` (invalid field), and `20116` (group full)—making it impossible for hosts like OhMy.xin to distinguish throttle backoff from circuit-breaking forbidden access. Retry policy is inconsistent across `Monitor.check_retryable_error` (string heuristics), CLI error kinds, and consumer code. There are no unit tests for `ErrorMapper`. The [Mixin error codes documentation](https://developers.mixin.one/docs/api/error-codes) defines a full catalog that the gem should align with.

## What Changes

- Introduce `MixinBot::APIError` base class with structured attributes (`code`, `description`, `status`, `request_id`, `server_time`, `path`, `verb`, `extra`) and behavior helpers (`retryable?`, `throttle?`, `client_error?`).
- Map every documented Mixin API error code to a typed exception per the official catalog; add `MixinBot::RateLimitError` for code `429`.
- **BREAKING**: Split `429` out of `ForbiddenError`; reclassify `10002` → validation error, `20116` → conflict/capacity error (no longer `ForbiddenError`).
- **BREAKING**: `ForbiddenError` reserved for code `403` (and legacy undocumented `20121` if still observed).
- Add `MixinBot.retryable?(error)` as the single canonical retry policy; align `Monitor.check_retryable_error` and CLI error kinds to delegate to it.
- Handle HTTP-status edge cases in `parse_response!` (CDN/WAF `429`, web-server `5xx` with blank JSON error) as secondary to JSON `error.code`.
- Capture `Retry-After` response header on `RateLimitError` when present.
- Add CLI error kind `rate_limit` for structured output.
- Add comprehensive `ErrorMapper` unit tests covering all mapped codes and HTTP fallbacks.
- Bump gem to **2.3.0** (minor; intentional breaking exception taxonomy).

## Capabilities

### New Capabilities

- `api-error-code-catalog`: Structured API errors, full Mixin error-code mapping aligned to official docs, canonical `MixinBot.retryable?`, HTTP fallback handling, CLI `rate_limit` kind, and ErrorMapper test coverage.

### Modified Capabilities

- _(none — no existing OpenSpec capability covers API error mapping)_

## Impact

- **Errors**: `lib/mixin_bot/errors.rb` — new base class, new exception types, `MixinBot.retryable?`
- **Client**: `lib/mixin_bot/client/error_mapper.rb`, `lib/mixin_bot/client.rb` (`parse_response!`)
- **Monitor**: `lib/mixin_bot/monitor.rb` — delegate retry check
- **CLI**: `lib/mixin_bot/cli/errors.rb` — new `rate_limit` kind, updated `kind_for_exception`
- **Tests**: new `test/mixin_bot/client/test_error_mapper.rb`, updates to CLI/monitor tests
- **Docs**: `CHANGELOG.md`, `README.md` (error handling section), `docs/agent/cli.md`
- **Consumers**: any code rescuing `ForbiddenError` for rate limits must also handle `RateLimitError`; validation/capacity errors no longer match `ForbiddenError`
