# Design: cover-upstream-sdk-gaps

## Context

The gem is an additive mirror of the official Go/Node SDKs; the 2026-05-24 sync left it at parity, but upstream has since added a fee endpoint, an encrypted-message orchestration layer, new chains, timeout configuration, and small message/utility features (see proposal.md — Why). Constraints that shape the approach:

- `MixinBot::API` is a flat composition of domain modules (`lib/mixin_bot/api/*.rb`); new REST methods slot into the module that already owns the closest endpoint.
- `MixinBot::Client#post` compacts kwargs (`client.rb:64`), so adding optional fields to payload builders is wire-compatible by construction.
- `fetch_user_sessions` (`api/session.rb:6`, `POST /sessions/fetch`) and `encrypt_message` (`api/encrypted_message.rb:113`) already exist — the pipeline is orchestration over existing primitives.
- `chain_id?` derives from `CHAIN_NAMES.key?` (`api/chain.rb:83`), so registry additions are a single-hash edit.
- No new runtime dependencies are desired; tests are offline WebMock.

## Goals / Non-Goals

**Goals:**

- Mirror the listed upstream features with idiomatic Ruby naming and zero breaking changes.
- Keep the encrypted-message pipeline decoupled from session persistence (pluggable store).
- Keep `API_COVERAGE.md` and the coverage gate authoritative for the new surface.

**Non-Goals:**

- Changing defaults of existing behavior (no global timeout unless configured, wire format unchanged when new options are omitted).
- Redis/database-backed session stores (only the in-memory default ships; the interface is the extension point).
- Removing `lib/mvm/` (upstream-dead but out of scope here).
- Blaze-side `silent` support (Go's flag is set on REST `MessageRequest`; REST only per spec).

## Decisions

### 1. `safe_fees` lives in `api/asset.rb`, named after the Go symbol

`GET /safe/fees` → `API#safe_fees`, placed next to `asset_fee` (`asset.rb:113`), which owns the sibling per-asset fees endpoint. Follows the existing `safe_*` prefix convention (`safe_snapshots`, `safe_outputs`). Alternative: a new `fee.rb` module — rejected; one method doesn't justify a module, and `mixinbot call`/`list` pick it up automatically either way.

### 2. Pipeline is additive: `post_encrypted_messages`, alongside the existing raw sender

- `API#post_encrypted_messages(messages, session_store: nil, **kwargs)` (mirrors Go `PostEncryptedMessages`) accepts the same option hashes as `base_encrypted_message_params` (category, data, `recipient_id`, `conversation_id`, …) but unencrypted.
- Existing `send_encrypted_message(s)` keep their raw pre-encrypted semantics unchanged — no rename, no behavior change.
- New `MixinBot::SessionStore` (`lib/mixin_bot/session_store.rb`): `fetch(user_id)` → cached sessions or `nil`; `store(user_id, sessions)`. Hash-backed, per-process. A custom store is any object answering those two calls. Mirrors Go's `SessionStore`/`MapSessionStore` split (interface + in-memory impl) without defining a Ruby interface.
- Pipeline: collect unique `recipient_id`s → per recipient use `store.fetch` or `fetch_user_sessions([id])` then `store.store` → encrypt each message via `encrypt_message(data, sessions)` with the recipient's sessions and MD5 session-id checksum (same shape as `base_encrypted_message_params`) → single `POST /encrypted_messages` with the batch → inspect `responses`; for each `FAILED` response, re-fetch that recipient's sessions (bypassing the cache, so the store is overwritten with fresh sessions), re-encrypt, and re-post **once** (Go's one-shot retry). Returns the standard `ApiEnvelope`; per-recipient outcomes are read from `response['data']` (`state` `SUCCESS`/`FAILED`) — refine: the gem's convention is that every API method returns an envelope, so the pipeline returns the envelope of the final post rather than a bare array.
- No new error class: Ruby convention in this gem is to return envelopes and let callers branch; raising only on exhausted retries would lose the per-recipient detail the spec requires callers to see. Alternative (Go-style `EncryptedMessageError` carrying responses) rejected as un-idiomatic here — callers who want raise-on-failure can wrap the call.

### 3. Chain registry: single-hash edit + stablecoin constant hash

Add `HyperEVM`, `Pearl`, `X Layer`, `Robinhood` to `CHAIN_NAMES` (`api/chain.rb`); `chain_id?`/`chain_name` follow automatically. Stablecoin IDs go in one hash next to it — `CHAIN_STABLECOIN_ASSET_IDS = { 'HyperEVM' => { usdt: '…', usdc: '…' }, … }` — plus flat constants (`USDT_HYPEREVM`, `USDC_SUI`, …) for Go-style direct references. **Exact UUIDs are transcribed from upstream `chain.go`/`asset.go` during implementation and pinned by tests** (they were not captured during planning; the source of truth is upstream source, not memory).

### 4. Timeout is opt-in via `http_timeout`

Add `:http_timeout` to `CONFIGURABLE_ATTRS` (`configuration.rb:59`); `MixinBot::Client` applies `f.request :timeout, value` inside the existing `Faraday.new` block only when set. Default `nil` = byte-identical behavior to today. Note the existing retry middleware already treats `Faraday::TimeoutError` as retryable, so configured timeouts compose with retries for free. Alternative (a sane default like 30 s) rejected — some Safe/computer operations are slow and this must not change behavior in a minor release.

### 5. `silent` rides the existing option hash

`base_message_params` gains `silent: options[:silent]`; the trailing `.compact` and `Client#post`'s kwargs compaction strip it when absent, so the wire format only changes when the caller opts in. All `send_*_message` helpers inherit it via the options hash. Blaze untouched (Non-Goal).

### 6. Amount utilities: string/integer math, no floats

New `lib/mixin_bot/utils/amount.rb` mixed into `MixinBot.utils`: `format_units(value, decimals)` → String, `parse_units(amount, decimals)` → Integer, mirroring Node `utils/amount.ts` semantics (integer minor units ⇄ decimal string) — `parse_units('0.1', 18)` must equal `10^17` exactly. Refine after reading upstream: the Node implementation uses BigNumber with `ROUND_FLOOR`, so `parse_units` floors over-precise values rather than rejecting them, and `format_units` trims trailing fractional zeros; invalid strings raise `ArgumentError` (upstream yields NaN — Ruby raises instead, which is safer and matches the design's error intent). Implemented with integer/string math + `BigDecimal` floor, no floats.

### 7. PKCE: utility + optional parameter threading

`MixinBot.utils.oauth_code_challenge(verifier)` = base64url(SHA-256(verifier)), unpadded — validated against the RFC 7636 test vector in tests. `authorization_data` gains an optional `code_verifier` (default `nil` → current `code_challenge: ''`), threaded through `authorize_code(**kwargs)` as `kwargs[:code_verifier]`. Existing callers are untouched.

### 8. Blaze app card: optional keywords on the existing helper

`blaze_send_app_card` gains `cover_url: nil, actions: nil`; the payload builder omits absent keys (compaction), satisfying both spec scenarios with one code path.

### 9. Coverage bookkeeping

Every new symbol gets an `API_COVERAGE.md` row (`done`) under the Go/Node sections — `ReadSafeFees`, `PostEncryptedMessages` + `SessionStore`/`EncryptedMessageResponse`, `SetHttpTimeout` (config, `n/a` row style), `MessageRequest.silent`, amount/PKCE utils, card fields, chain registry rows. The rake gate must stay green before merge.

## Risks / Trade-offs

- [Transcription errors in chain/stablecoin UUIDs] → copy directly from upstream source at implementation time; pin each id in an offline test with its name.
- [Mis-detecting session expiry could retry a permanently failing recipient] → retry at most once, only on `FAILED` responses, mirroring Go's one-shot retry; final state is always reported.
- [In-memory session store grows unbounded in long-lived processes] → per-`user_id` overwrite bounds it to one entry per recipient; custom stores remain the escape hatch for persistence/TTL.
- [Timeout misconfiguration kills long-running calls] → opt-in only, `nil` default, documented in README; retry middleware still backs off transient timeouts.
- [`silent` sent to older servers that reject unknown fields] → key omitted entirely when not requested, so non-users of the flag see the identical wire format as today.
- [Pipeline batches recipients with different session counts] → encryption is per message per recipient's own sessions (same as `base_encrypted_message_params` today); batch post only merges transport, not keys.

## Migration Plan

Purely additive, minor-version release: new methods/config key/keyword args, no renames. Rollback = revert the release; no data or wire-format migration. `API_COVERAGE.md` rows land in the same PR to keep the gate green.

## Open Questions

None blocking. Chain/stablecoin UUID values are resolved during implementation from upstream source (Decision 3) and do not affect the spec or task breakdown.
