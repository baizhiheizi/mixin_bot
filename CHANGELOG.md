# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [2.5.0] - 2026-09-03

### Added

- **Upstream SDK parity (2026 Go/Node releases)** — closes gaps with `bot-api-go-client` v3.25.3 and `bot-api-nodejs-client` v7.5.6.
- **`API#safe_fees`** (`read_safe_fees` alias) — `GET /safe/fees` global Safe fee schedule.
- **`API#post_encrypted_messages`** — encrypt-and-send pipeline (`POST /encrypted_messages`) with one-shot retry on expired recipient sessions, per-message `SUCCESS`/`FAILED` state, and a pluggable session cache.
- **`MixinBot::SessionStore`** — in-memory `MapSessionStore` equivalent; pass any object answering `fetch(user_id)` / `store(user_id, sessions)` as `session_store:` (storing `nil` evicts).
- **`MixinBot::CacheStoreAdapter`** — wraps any `ActiveSupport::Cache`-style store (`Rails.cache` with Redis/Memcached/solid_cache, or a hand-rolled read/write/delete object) so encrypted-message sessions can be cached across processes with `expires_in:` TTLs.
- **`MixinBot::Configuration#http_timeout`** — opt-in Faraday request timeout in seconds (nil keeps the default).
- **`silent:` flag** on REST `send_message` and encrypted REST sends, matching Go `MessageRequest.Silent`.
- **Chain registry** — HyperEVM, X Layer, Robinhood, and Pearl chain ids, plus a corrected Sui id. `CHAIN_STABLECOIN_ASSET_IDS` map and `API#stablecoin_asset_ids(chain_id)`; per-chain `USDT_*` / `USDC_*` constants.
- **`MixinBot.utils.format_units` / `#parse_units`** — decimal-safe unit conversion (Node `utils/amount` parity, no `Kernel#Integer` octal/hex surprises).
- **`MixinBot.utils.oauth_code_challenge`** — PKCE S256 code challenge (RFC 7636).
- **OAuth PKCE support** — `oauth_token(code, code_verifier:)` and `authorize_code(scope:, code_verifier:)` exchange and emit PKCE authorizations.
- **`blaze_send_app_card(cover_url:, actions:)`** — APP_CARD parity with the Node SDK.

### Changed

- **`API#post_encrypted_messages`** — encrypted-message checksum now reuses `MixinBot.utils.generate_user_checksum` (the dead MD5 line in `encrypt_message` is gone).
- **Encrypted-message session store** — default store lives on the API instance so caching persists across calls per process; expired sessions are evicted via `store(id, nil)` (Go `store.Delete` parity).
- **`MixinBot::Utils` CLI introspection** — `mixinbot utils list` / `utils call` now surface methods extended from submodules (`Address`, `Amount`, `Crypto`, …).
- **`API::Auth`** — `authorize_code` accepts `String` scopes; `REFRESH_OAUTH_CODE` payload is built from an `oauth_code_params` helper; the dead `@_app_id` ivar is gone.

### Fixed

- **`API#post_encrypted_messages`** — non-String `data` is JSON-encoded (was Ruby `inspect` output); the `silent` flag is honored on all encrypted REST sends; sessions stores that raise or return non-arrays are tolerated (Go `err == nil` semantics); symbol-keyed sessions are normalized; per-message responses are merged across the retry so every message's final state is returned; duplicate `message_id`s are rejected; malformed `/encrypted_messages` payloads raise meaningful errors; kwargs are strictly `access_token` / `exp_in` / `scp`.
- **`MixinBot::Client`** — `Configuration#api_host` and `#debug` are now applied correctly even when the client is initialized with a different `config` (no more stale Faraday URL when reassigning config).
- **Encrypted-message test harness** — shared guarded WebMock setup in `test_helper.rb` so `LIVE=1` runs and per-file `setup` methods reset state consistently; encrypted-message stub helpers extracted for reuse.

## [2.4.1] - 2026-08-08

### Fixed

- **CLI keystore path** — `File.expand_path` is now applied to the `--keystore` / `-k` value so `~` (and other relative paths) resolve correctly before `File.file?`. Previously `mixinbot` would treat the literal `~/...` string as JSON content and report "failed to parse keystore JSON".

## [2.4.0] - 2026-07-20

### Added

- **Blaze WebSocket User-Agent** — the client now sends a `User-Agent` header on Blaze WebSocket connections.

### Changed

- **`sha3` dependency** — upgraded from `~> 1.0` to `~> 2.2` (sha3 2.x renames `SHA3::Digest::SHA256` to `SHA3::Digest::SHA3_256`; hash output is unchanged).

### Fixed

- **Payment URL formatting** — `safe_pay_url` now formats amounts without scientific notation for very small or large values.

### Performance

- **Encoder allocations** — replaced `Array` splat patterns with `Array#concat` in `Transaction::Encoder`, `Nfo`, `InvoiceEntry`, `EncryptedMessage`, and `MVM::Registry` to avoid O(n²) reallocation.
- **Bytes pack caching** — cached `bytes.pack` results in transaction encoders to reduce duplicate allocations.

## [2.3.0] - 2026-05-27

### Added

- **`MixinBot::APIError`** — structured base for API failures with `code`, `description`, `request_id`, `extra`, and helpers `retryable?`, `throttle?`, `client_error?`.
- **Typed API errors** — `RateLimitError`, `ValidationError`, `ConflictError`, `TransferError`, `TransientError`, `AppUpdateRequiredError`, `InvalidAddressFormatError`, `ServerError`.
- **`MixinBot.retryable?(error)`** — canonical retry policy for network timeouts, server errors (500+), and transient codes (10104, 10105).
- **CLI** — structured error kind `rate_limit`; API errors in JSON output include `code`, `request_id`, and `throttle` when available.
- **`test/mixin_bot/client/test_error_mapper.rb`** — unit tests for full official error-code catalog, legacy codes, HTTP fallbacks, and retry/throttle semantics.

### Changed

- **BREAKING: Error code mapping** — aligned to [Mixin API error codes](https://developers.mixin.one/docs/api/error-codes). Code `429` raises `RateLimitError` (not `ForbiddenError`). Codes `10002` and `20116` raise `ValidationError` and `ConflictError` respectively. `ForbiddenError` is reserved for code `403`.
- **`Monitor.check_retryable_error`** — delegates to `MixinBot.retryable?` (no longer retries on `"insufficient"` message substrings).
- **`Client#parse_response!`** — HTTP status fallback for 401/403/429/5xx when JSON `error` is absent (CDN/proxy edge cases).

### Migration

- Rescue rate limits explicitly: `rescue MixinBot::RateLimitError` (or check `error.throttle?`).
- Replace string-based retry heuristics with `MixinBot.retryable?(error)`.
- If you rescued `ForbiddenError` expecting throttling, update to handle `RateLimitError` separately.

## [2.2.2] - 2026-05-24

### Fixed

- **Safe transfer raw encoding** — version 5 transactions now always encode and decode the references count (including `0000` when empty), matching the Mixin kernel and official Go/TS SDKs. Fixes `/safe/transaction/requests` rejection after the v2 transaction encoder refactor.

## [2.2.1] - 2026-05-24

### Changed

- **Billing preflight `increment`** — `ensure_app_billing_credit!` accepts an `increment` parameter (default `0`) instead of reading `app_properties.price`. `create_user` / `create_safe_user` default to `0.5` per billed user; pass `increment: 0` for free-tier headroom.

## [2.2.0] - 2026-05-24

### Added

- **`MixinBot::API#create_user` billing preflight** — verifies app billing headroom (`credit > cost + next user fee`) via `app_billing` and `app_properties` before `POST /users`. Raises `InsufficientAppBillingError` by default; pass `force: true` to skip. `create_safe_user` forwards `force:` to `create_user`.
- **`MixinBot::InsufficientAppBillingError`** — structured fields: `app_id`, `credit`, `cost`, `increment`.
- **CLI** — `mixinbot call create_user ... --force` skips billing preflight; billing failures map to structured error kind `billing`.

## [2.1.0] - 2026-05-24

### Added

- **Node SDK REST parity** with [bot-api-nodejs-client](https://github.com/MixinNetwork/bot-api-nodejs-client): Circle API (`API::Circle`), `external_proxy`, extended App CRUD/Safe registration, OAuth `authorizations` / `revoke_authorization`, user `blocking_users` / `rotate_user_code` / `user_logs`, conversation mute/disappear, HTTP message acknowledgements and additional send helpers, `create_scheme`, `safe_withdraw_addresses`, and query params on `pending_safe_deposits`.
- **API_COVERAGE.md** Node SDK section mapping TS symbols to Ruby methods.

## [2.0.1] - 2026-05-24

### Fixed

- **`StringIO.new`** — use keyword `contents:` for Ruby 4 compatibility (`lib/mixin_bot/api/message.rb`).

### Changed

- Release workflow creates a GitHub Release with notes from `CHANGELOG.md` when publishing version tags.

## [2.0.0] - 2026-05-16

### Added

- `MixinBot.utils.hash_members` (Go `HashMembers`) for sorted member hashing; used by `safe_outputs` and legacy output/collectible helpers.
- `MixinBot::API#tip_or_legacy_pin_payload` and adoption across legacy PIN/TIP call sites.
- Offline WebMock harness (`test/support/mixin_api_stubs.rb`), deterministic `OfflineConfig`, and `rake test_live` (runs `test` with `LIVE=1`).
- Golden-vector fixtures under `test/fixtures/golden/` and transaction hex under `test/fixtures/transactions/`.

### Changed

- **HTTP responses** — `MixinBot::Client` returns `MixinBot::Models::ApiEnvelope` (no `merge!` of `data` into the top level). One-liners such as `#me` still return the inner `data` hash where that was the historical contract.
- **`MixinBot::API#build_safe_transaction`** — derives the mixin asset hash from each UTXO’s `asset_id` when `asset` is absent (matches API output shapes).
- **`MixinBot::Transaction#decode`** — reads the `references` section only when `references` is non-empty, matching encode behavior (fixes Safe tx round-trips).

### Deprecated

- All `Legacy*` API modules emit `MixinBot.deprecator` warnings (silenced in the default test suite). Migrate to Safe APIs (`create_safe_transfer`, `build_safe_transaction`, `safe_outputs`, inscriptions, etc.).

### Fixed

- **Ruby 4.0** — declare the `benchmark` gem (stdlib is no longer auto-loaded), bump **`eth` ≥ 0.5.17** (compatible `openssl` stack), add **`rdoc`** for `rake`/YARD, replace **`CGI.parse`** in offline stubs with **`URI.decode_www_form`**, and run CI on **4.0**.

## [1.5.0] - 2026-05-15

### Changed (breaking)

- **`MixinBot::API#safe_register`** — renamed the misleading first positional
  parameter `pin` to `spend_key` and removed the previously unusable
  `spend_key:` keyword argument. The method now takes a single argument:
  the user's spend Ed25519 private key, accepted as raw bytes, hex, or a
  Base64-encoded string. All in-tree call sites already used it positionally,
  so most consumers will not need changes.

  Migration:

  ```ruby
  # before
  api.safe_register(spend_key_hex)                       # already worked
  api.safe_register(pin, spend_key: spend_key_bytes)     # never worked correctly

  # after
  api.safe_register(spend_key_hex)
  api.safe_register(spend_key_bytes)
  ```

### Fixed

- **`MixinBot::API#create_safe_user`** — the per-instance `@__retry__`
  counter leaked across calls and was not thread-safe. Replaced with a
  local variable inside a private `with_safe_register_retries` helper.
- **`MixinBot::API#migrate_to_safe`** — fixed a long-standing bug where
  `safe_register pin, spend_key` raised `ArgumentError` (positional vs.
  keyword mismatch) and additionally passed the TIP public key hex as the
  signing key. Now correctly calls `safe_register(spend_key_hex)`.
- **`MixinBot::API#safe_register`** — would crash inside
  `JOSE::JWA::Ed25519.sign` when callers passed a 32-byte seed. Now
  derives a normalized 64-byte signing key from the keypair before
  encrypting the TIP PIN.

### Improved

- The Safe-network registration retry now rescues only transient
  `MixinBot::PinError` / `MixinBot::ResponseError` (e.g. server-side TIP
  PIN propagation lag), instead of swallowing every `MixinBot::Error`
  including `UnauthorizedError`, `NotFoundError`, etc.
- Added module-level constants for retry limits and propagation delay:
  `SAFE_REGISTER_MAX_RETRIES`, `SAFE_REGISTER_RETRY_BASE_DELAY`,
  `TIP_PIN_PROPAGATION_DELAY`.
- Added input validation: `safe_register` now raises `ArgumentError` when
  the spend key cannot be decoded into at least 32 bytes.
- Added YARD documentation for `create_user`, `create_safe_user`,
  `safe_register`, and `migrate_to_safe`, matching the style used in
  `MixinBot::API::Me`.
- Added a `# NOTE:` comment in `safe_register` clarifying that the Go
  SDK's `crypto.Sha256Hash` is misleadingly named — it actually computes
  SHA3-256, so `SHA3::Digest::SHA256` is the correct Ruby match.

## [1.4.0] - prior

See `CHANGES_SUMMARY.md` for the documentation overhaul that preceded this
changelog.
