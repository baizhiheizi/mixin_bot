# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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
