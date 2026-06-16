# Formal Verification Research — MixinBot

> 🔬 *Lean Squad — automated formal verification for `baizhiheizi/mixin_bot`.*

**Status**: Research complete; Tier 1 Lean specs (UUID, Varint, UintCodec) merged
in PRs #95 / #96 with 7 `sorry` remaining for the round-trip proofs; this run
adds Tier 2 (`MainAddress`).

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

## 7. Lessons Learned from Tier 1 Spec Writing (PRs #95 / #96)

Three observations from the Tier 1 round that shape the Tier 2 approach:

1. **`axiom` is a perfectly acceptable scope boundary for "well-known
   correctness" subroutines.** The UUID spec uses an `axiom` for the
   bit-level hex ⇔ byte conversion, and the round-trip property
   (`unpacked_packed`) is still valuable because it captures the
   *behavioural* contract the Ruby implementation provides. The same
   approach will be used for the SHA3-256 checksum inside `MainAddress`:
   the checksum function is `axiom`-ed, and the round-trip / prefix /
   length invariants are stated in terms of the abstract checksum.

2. **Concrete (`native_decide`) examples substitute for the general
   proof while the general proof is still in progress.** Varint and
   UintCodec each include 7 / 10 concrete round-trip examples verified
   by `native_decide`. This gives a useful "scaffolding" confidence
   while the general round-trip theorems remain `sorry`. The same
   pattern will be used for `MainAddress.encode ∘ decode` /
   `decode ∘ encode` — the general theorems are `sorry`, but a small
   number of concrete golden inputs are checked.

3. **The little-endian varint question (RESEARCH §6 Q1) was resolved
   in the implementation, not in the spec.** The Lean model mirrors
   the Ruby little-endian encoding directly. The `BigEndian` / `LittleEndian`
   choice is therefore a property of the model, not a meta-lemma to
   prove. This was a useful simplification: we model what the code
   does, and the spec's job is to make the property of "what it does"
   precise.

## 8. Tier 2 Target: `MainAddress` (introduced in this run)

`MainAddress` (in `lib/mixin_bot/address.rb`) encodes an Ed25519 public
key as a "XIN"-prefixed, Base58-encoded, SHA3-256-checksummed string.
The full informal specification lives in
[`formal-verification/specs/main_address_informal.md`](specs/main_address_informal.md).

### Why this is the right Tier 2 target

- **Security-critical**: a public-key address is what users paste in to
  send funds. A single off-by-one in the Base58 alphabet or a checksum
  miscalculation would silently accept corrupted addresses.
- **Builds on Tier 1 + nothing else**: it does not depend on the
  varint / uint / UUID codecs. The only external primitives are SHA3-256
  and Base58, both of which are abstracted as `axiom` in the spec.
- **Golden-testable**: `test/mixin_bot/test_address.rb` includes
  `test_encode_and_decode_main_address`, which gives us a concrete
  byte-for-byte oracle.
- **Self-contained**: the implementation is 40 lines of pure Ruby
  with no I/O, no time, no randomness, and no platform dependencies.

### Properties to verify

| Property | Type | Effort | Tractability |
|----------|------|--------|--------------|
| `decode(encode pk) = pk` for any 64-byte public key `pk` | round-trip | high | `decide` on small alph. tables, or hand proof |
| `encode(decode addr) = addr` for any well-formed `addr` | round-trip | high | similar |
| `encode pk` starts with `"XIN"` | prefix invariant | trivial | `rfl` |
| `decode addr` raises / rejects if `addr` lacks `"XIN"` prefix | error property | trivial | `rfl` |
| `decode addr` rejects if checksum is wrong | error property | trivial | `decide` after modelling |
| Burning address stability: `MainAddress.burning_address.address = ⟨golden⟩` | determinism | trivial | `decide` after one fixed computation |

### Approach

- Mirror the Ruby `encode` / `decode` as two pure Lean functions
  `mainAddressEncode` and `mainAddressDecode`.
- Model the SHA3-256 hash and the Base58 alphabet as `axiom`ed
  constants; state the key property (`checksum(s + pk)[0..3] = data[-4..]`)
  as a separate, separately-proved `axiom` if it falls outside the spec.
- Headline round-trip theorems use `sorry` for the body; the
  implementation model + 3–5 `native_decide` examples demonstrate the
  contract holds for golden inputs.
- Document in Lean what is *not* modelled: the `ArgumentError` raises
  in `decode`, the surrounding `ActiveSupport` helpers (`present?`),
  and the I/O behaviour of `MixinBot::Utils.shared_public_key` used in
  `burning_address`.

### Correspondence

Correspondence with the Ruby implementation will be established via
Task 8 Route B: a Ruby harness that calls `MixinBot::MainAddress.new`
on a fixture of public keys and addresses, and a Lean harness that
runs the Lean model on the same inputs. Agreement is a check on both
the Lean model and the Ruby implementation.

## 9. Reference Material

- [Mixin Network developers docs](https://developers.mixin.one/docs)
- [bot-api-go-client](https://github.com/MixinNetwork/bot-api-go-client) —
  parity target, source of golden fixtures
- [bot-api-nodejs-client](https://github.com/MixinNetwork/bot-api-nodejs-client)
- Mathlib modules we plan to lean on: `Mathlib.Data.List.Basic`,
  `Mathlib.Data.ByteArray`, `Mathlib.Tactic.Omega`,
  `Mathlib.Tactic.Linarith`, `Mathlib.Tactic.Ring`

---

## Last Updated
- **Date**: 2026-06-16 00:35 UTC
- **Commit**: `84bac72` (origin/main; PRs #95 / #96 carry the Tier 1 specs)
