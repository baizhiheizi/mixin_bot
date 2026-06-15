# Formal Verification Research — MixinBot

> 🔬 *Lean Squad — automated formal verification for `baizhiheizi/mixin_bot`.*

**Status**: Research phase complete; targets identified; ready for informal spec extraction.

## 1. Codebase Survey

MixinBot is a Ruby gem (v2.2.1) that provides a REST SDK + CLI for the
[Mixin Network](https://developers.mixin.one/docs). It mirrors the official
[bot-api-go-client](https://github.com/MixinNetwork/bot-api-go-client) and
[bot-api-nodejs-client](https://github.com/MixinNetwork/bot-api-nodejs-client)
SDKs. The repository contains:

| Layer | Path | Notes |
|-------|------|-------|
| HTTP client | `lib/mixin_bot/client.rb` | Faraday-based, returns `ApiEnvelope` |
| API domains | `lib/mixin_bot/api/*.rb` (~30 modules) | Safe + legacy variants |
| Crypto & encoding utilities | `lib/mixin_bot/utils/` | Foundation for higher layers |
| Transaction encoder/decoder | `lib/mixin_bot/transaction/` | Hex-format raw transactions |
| Data structures | `lib/mixin_bot/{uuid,address,nfo,invoice,bot_auth}.rb` | Mixin-specific types |
| CLI | `lib/mixin_bot/cli/` | Thor-based; not in scope for FV |
| Tests | `test/` (Minitest + WebMock) | Includes golden fixtures from Go SDK |

The codebase has excellent test infrastructure that doubles as **specification
hints**: `golden_*.rb` tests pin byte-for-byte compatibility with the Go SDK
output, and `transaction_fixture_test.rb` does the same for the on-chain
transaction format against a real hex blob.

## 2. Language/Tool Choice

**Tool**: Lean 4 (with Mathlib) — chosen for its strong induction, `decide`,
and the established Lean Squad methodology. The codebase is Ruby (not Rust),
so the standard Aeneas/Charon pipeline (Task 8 Route A) does not apply; we
will use **Route B** (executable correspondence tests via shared fixtures) for
cross-validation. See [`TARGETS.md`](TARGETS.md) for per-target plans.

## 3. FV-Amenability Heuristics Applied

When triaging the ~25 candidates, we scored each on:

- **Purity**: is the function pure / deterministic / free of I/O?
- **Spec size**: how many Lean lines to state the key properties?
- **Proof tractability**: `decide` / `simp` / `omega` / induction?
- **Bug-catching potential**: security-sensitive? critical-path?
- **Existing tests**: do existing tests give us an oracle to lean against?
- **Reuse**: are similar invariants proved for the Go SDK (parity hint)?

## 4. Identified Targets (Summary)

Five targets selected. Full prioritisation in [`TARGETS.md`](TARGETS.md).

| # | Target | Tier | Tractability | Key property |
|---|--------|------|--------------|--------------|
| 1 | `UUID.unpacked` / `packed` round-trip | T1 | high | format-preserving bijection hex ↔ binary ↔ dashed |
| 2 | `Utils::Encoder.encode_int` ↔ `Decoder.decode_int` | T1 | high | non-negative integer varint round-trip |
| 3 | `encode_uint16/32/64` ↔ `decode_uint16/32/64` | T1 | very high | fixed-width big-endian round-trip |
| 4 | `MainAddress` encode/decode round-trip + invariants | T2 | high | `XIN`-prefixed, valid base58, valid SHA3-256 checksum |
| 5 | `MixAddress` encode/decode round-trip + invariants | T2 | medium | `MIX`-prefixed, valid base58, member list + threshold preserved |
| 6 | `Transaction` encoder/decoder round-trip | T3 | medium | golden hex fixture passes; `decode ∘ encode = id` |
| 7 | `Nfo` (NFT memo) round-trip | T3 | medium | mask-dependent payload invariant |

Targets 6 and 7 are intentionally deferred until we have proved the foundation
(targets 1–3, used as building blocks by everything else) plus a critical-mass
of round-trip infrastructure from target 5.

## 5. Approach Notes

- **Modeling style**: functional Lean 4 mirroring the imperative Ruby, using
  `ByteArray`, `List Byte`, and bit-manipulation lemmas from Mathlib
  (`Mathlib.Data.List.Basic`, `Mathlib.Data.ByteArray`, etc.).
- **Abstractions**: hex strings are modeled as `String` of length 32 (no dashes)
  or 36 (with dashes); binary blobs as `ByteArray`. The hex ↔ byte conversion
  is modeled explicitly via `String.toByteArray`/`ByteArray.toHex`.
- **What we explicitly abstract**: I/O, file reads, randomness, the
  surrounding `ActiveSupport`-style helpers (`present?`, `blank?`). Models
  are written as total functions over already-validated inputs.
- **Validation strategy**: every proved round-trip is validated against the
  existing golden fixtures (`test/fixtures/golden/*.json`,
  `test/fixtures/transactions/version3_multi_io.hex`). The Lean model is run
  through `lake build` and a Ruby harness executes the Lean model on the same
  inputs to confirm behavioural agreement (Task 8 Route B).
- **Proof tactics inventory (planned)**:
  - `decide` / `native_decide` for finite enumeration of small formats.
  - `simp` + `simp_arith` for structural lemmas.
  - `omega`, `linarith`, `norm_num` for arithmetic.
  - `List` / `Array` induction for round-trips.
  - `aesop` as a fallback for small but nontrivial goals.

## 6. Open Questions for Maintainers

These are flagged for human input but do not block work:

1. **Endianness of `encode_int`** — the implementation is little-endian
   (low byte first); should the Lean spec mirror this or use a normalised
   big-endian representation internally? Default plan: mirror little-endian
   for direct correspondence.
2. **`encode_uint16` overflow** — the implementation raises on negative or
   out-of-range inputs. Lean model will treat the function as a partial
   function with precondition `0 ≤ n < 2^bits`. Acceptable?
3. **Transaction fixture scope** — `version3_multi_io.hex` covers
   `REFERENCES_TX_VERSION` exactly. Round-trip is tested only for that
   version; we will mirror this scope unless maintainers want broader
   coverage.

## 7. Reference Material

- [Mixin Network developers docs](https://developers.mixin.one/docs)
- [bot-api-go-client](https://github.com/MixinNetwork/bot-api-go-client) —
  parity target, source of golden fixtures
- [bot-api-nodejs-client](https://github.com/MixinNetwork/bot-api-nodejs-client)
- Mathlib modules we plan to lean on: `Mathlib.Data.List.Basic`,
  `Mathlib.Data.ByteArray`, `Mathlib.Tactic.Omega`,
  `Mathlib.Tactic.Linarith`, `Mathlib.Tactic.Ring`

---

## Last Updated
- **Date**: 2026-06-15 06:38 UTC
- **Commit**: `<pending — to be filled when PR is opened>`
