# Proposal: cover-upstream-sdk-gaps

## Why

The gem declared full parity with the official Go (`bot-api-go-client` v3.25.3) and Node (`@mixin.dev/mixin-node-sdk` v7.5.6) SDKs at the 2026-05-24 sync, but both upstream SDKs have since moved — and an upstream audit (2026-08-31) found a handful of capabilities the gem never picked up. Covering them keeps `mixin_bot` a faithful mirror of the official SDKs and unblocks users who need the newest Safe/messaging features.

## What Changes

- Add `API#safe_fees` — global Safe fee schedule via `GET /safe/fees` (Go `ReadSafeFees`, 2026-06-30).
- Add an encrypted-message send pipeline (Go `PostEncryptedMessages`, 2026-08-25/26): automatically fetch recipient sessions (`POST /sessions/fetch`), encrypt payloads per recipient, retry once when a recipient's sessions have expired, and report per-recipient outcomes (`SUCCESS`/`FAILED`), backed by a pluggable in-memory session store (Go `SessionStore`/`MapSessionStore`).
- Extend the chain registry (`CHAIN_NAMES`) with chains added upstream since the sync: HyperEVM, Pearl, X Layer, Robinhood; plus stablecoin asset-ID constants (per-chain USDT/USDC, e.g. `USDT_XLAYER`, `USDC_HYPEREVM`).
- Add configurable HTTP timeout (`http_timeout`) to `MixinBot.configure` / `MixinBot::Client` (Go `SetHttpTimeout`, 2026-06-16).
- Support the `silent` flag on REST message sends (Go `MessageRequest.Silent`, 2025-12-23).
- Minor parity polish:
  - `MixinBot.utils` gains `format_units` / `parse_units` (Node `utils/amount.ts`).
  - OAuth PKCE helper `MixinBot.utils.oauth_code_challenge(verifier)` (Node `getChallenge`), and `authorization_data` accepts an optional `code_verifier` (currently hardcoded empty `code_challenge`).
  - `blaze_send_app_card` accepts `cover_url` and `actions` card fields (Node APP_CARD extension, 2025-12-26).

Assumption: "cover the gaps" includes the minor-parity items above, not just the five numbered gaps from the audit; they are grouped as one work package so they can be dropped without affecting the rest.

No breaking changes: all additions are opt-in (new methods, new optional keyword args, new config key with current behavior as default).

> **Exception (review follow-up):** the chain registry replaces the obsolete pre-fix Sui chain id `2bd97283-…` with the upstream-corrected `3acb25e4-…` (upstream commit `8b686d5`, 2026-06-09). Callers still holding the old id will see `chain_id?` return `false` — this mirrors upstream, which dropped the old id entirely.

## Capabilities

### New Capabilities

- `upstream-parity`: The gem's API surface mirrors the official Go/Node SDK features added since the 2026-05-24 sync — Safe fee schedule reads, the automated encrypted-message send pipeline with session caching/retry, the extended chain & stablecoin registry, HTTP timeout configuration, silent messaging, and the amount/PKCE/app-card utility gaps.

### Modified Capabilities

- *(none — the `api-coverage-gate` capability's requirements are unchanged; this change adds `done` rows to `API_COVERAGE.md`, which the gate already governs)*

## Impact

- **Code**: `lib/mixin_bot/api/` (new fees capability in `network_asset.rb` or new `fee.rb`; pipeline + store in `encrypted_message.rb`; `silent` in `message.rb`; card fields in `blaze.rb`; `code_verifier` in `auth.rb`), `lib/mixin_bot/api/chain.rb` (registry), `lib/mixin_bot/client.rb` + `configuration.rb` (timeout), `lib/mixin_bot/utils.rb` / `lib/mixin_bot/utils/` (`amount.rb`), `lib/mixin_bot/errors.rb` (encrypted-message failure error if needed).
- **Docs**: `API_COVERAGE.md` gains rows for every new symbol (kept `done` before merge); `README.md` config section documents `http_timeout`.
- **Tests**: offline WebMock specs for each new method/pipeline branch (happy path, session-expiry retry, failure states), following existing `test/mixin_bot/*_test.rb` conventions.
- **Compatibility**: Ruby >= 3.2, no new runtime dependencies (session store is in-memory by default; encryption reuses existing `encrypt_message`).
- **CLI**: new API methods become callable via `mixinbot call` automatically; `mixinbot schema` output updates.
