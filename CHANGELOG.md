# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
