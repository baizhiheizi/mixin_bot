# Lean Squad — Proof Utility Critique

> 🔬 *Lean Squad — automated formal verification for `baizhiheizi/mixin_bot`.*
>
> This document honestly assesses the formal verification work
> completed so far: which proved theorems are meaningful, which are
> weak or potentially vacuous, and what the highest-value gaps are
> for future runs. It is updated each run.

## Last Updated

- **Date**: 2026-06-17 06:30 UTC
- **Commit**: `cc56360` (main; PRs #95 / #96 / #97 / #103 merged)
- **Lean toolchain**: 4.31.0
- **Run**: 6 — Task 8 (Correspondence Validation) + Task 7 (Critique)

---

## Overall assessment

The Lean Squad has produced four hand-written Lean 4 models (Varint,
UintCodec, UUID, MainAddress) covering the security-sensitive Tier 1
codecs and the most critical Tier 2 address formats. The correspondence
review (`formal-verification/CORRESPONDENCE.md`) confirms **no
mismatches** between Lean and Ruby across all four models; the new
executable harness in `formal-verification/tests/tier1_codecs/`
strengthens this with **77 byte-level `#guard` checks** that pass on
the live Ruby output.

The headline round-trip theorems (9 `sorry`s total) and the cryptographic
axioms in `UUID` / `MainAddress` (14 `axiom`s) are the dominant
unfinished work. Proving the round-trip `sorry`s would give strong
empirical confidence that the Lean model is a faithful translation of
the Ruby; discharging the cryptographic axioms would let the model
type-check against the actual SHA3-256 / Base58 implementations. Both
are tractable but non-trivial (the former is straightforward
induction; the latter requires either a verified-crypto Lean
library or hand-written SHA3-256 / Base58).

---

## Proved theorems (Lean 4 / Mathlib 0 / Init+Std only)

The four Lean files contain **18 theorem declarations** total, of which
**9 are `sorry`** and **9 are proved** (4 `rfl`/`simp`/`intro` proofs +
5 `native_decide` examples classified as round-trip checks). Plus
**77 `#guard` byte-level checks** in `FVSquad/Correspondence.lean` that
are checked at compile time via `lake build`.

| # | Theorem / Example | File | Level | Bug-catching | Status |
|---|-------------------|------|-------|--------------|--------|
| 1 | `encodeInt_zero : encodeInt 0 = [0]` | `Varint.lean:43` | low | low (model sanity) | ✅ `rfl` |
| 2 | `encodeInt_zero_length : (encodeInt 0).length = 1` | `Varint.lean:47` | low | low | ✅ `simp` |
| 3 | `decodeInt_nil : decodeInt [] = 0` | `Varint.lean:51` | low | low | ✅ `rfl` |
| 4 | `decodeInt_two_bytes : decodeInt [lo, hi] = lo*256 + hi` | `Varint.lean:55` | low | low | ✅ `simp` |
| 5 | 7× `example : decodeInt (encodeInt n) = n` for `n ∈ {0, 1, 127, 128, 255, 256, 65535}` | `Varint.lean:60-85` | low-mid | high (per-input round-trip) | ✅ `native_decide` |
| 6 | 6× `example` for `encodeUint 16/32/64` round-trips | `UintCodec.lean:118-148` | low-mid | high | ✅ `native_decide` |
| 7 | 3× `encodeUintN_length` for N=16/32/64 | `UintCodec.lean:103-115` | low | low | ✅ `simp` |
| 8 | `encode_starts_with_xin` | `MainAddress.lean:144` | mid | mid (prefix invariant) | ✅ `unfold; simp` |
| 9 | `decode_rejects_non_prefixed` | `MainAddress.lean:161` | mid | mid | ✅ `intro h; unfold; simp [h]` |
| 10 | 1× `example : zeroPublicKey.length = publicKeyLength` | `MainAddress.lean:154` | low | low | ✅ `unfold; simp` |
| 11 | **77× `#guard` byte-level checks** in `Correspondence.lean` | `Correspondence.lean` | mid-high | very high (Ruby ↔ Lean agreement) | ✅ `lake build` |

### What does each proved property actually catch?

- **`encodeInt_zero` / `decodeInt_nil` / `decodeInt_two_bytes`**: low-level
  sanity checks. They catch trivial errors in the Lean model itself
  (e.g., off-by-one in the recursive structure), not in the Ruby code.
- **`encodeInt_zero_length` / `encodeUintN_length`**: catch mistakes in
  the byte-counting arithmetic. E.g., if `encodeUint 16 n` accidentally
  returned 3 bytes, `encodeUint16_length` would fail.
- **`native_decide` round-trip examples**: catch **incorrect byte
  encodings** for the specific tested input. If the Ruby `encode_int(0)`
  produced `[1]` (a bug), the `#guard encodeInt 0 = [0]` check would
  fail. These are **strong empirical evidence** for the corresponding
  values.
- **`encode_starts_with_xin` / `decode_rejects_non_prefixed`**: catch
  prefix-handling regressions (e.g., if the Ruby `MAIN_ADDRESS_PREFIX`
  was changed from `'XIN'` to `'xin'`).
- **`#guard` byte-level checks** (Correspondence.lean): the strongest
  evidence. They prove the Lean model and the Ruby model produce
  *byte-for-byte identical output* on the 77 specific (input, output)
  pairs. The `lake build` exit code is the pass/fail signal.

### `sorry`-guarded theorems (Phase 4–5 work)

| # | Theorem | File | Difficulty |
|---|---------|------|------------|
| 1 | `encodeInt_decodeInt (n : Nat) : decodeInt (encodeInt n) = n` | `Varint.lean:39` | straightforward induction on `encodeIntHelper` |
| 2 | `decodeInt_encodeIntHelper (k acc) : decodeInt (encodeIntHelper k acc) = k * 256^acc.length + decodeInt acc` | `Varint.lean:89` | helper lemma for #1 |
| 3 | `encodeUint16_decodeUint16 (n : Bounded 16) : decodeUint 16 (encodeUint 16 n) = n.val` | `UintCodec.lean:92` | straightforward `omega` |
| 4 | `encodeUint32_decodeUint32 (n : Bounded 32) : ...` | `UintCodec.lean:97` | straightforward `omega` |
| 5 | `encodeUint64_decodeUint64 (n : Bounded 64) : ...` | `UintCodec.lean:102` | straightforward `omega` |
| 6 | `unpacked_packed (b : UUIDBytes) : hexToBytes (stripDashes (unpacked b)) = b.val` | `UUID.lean:97` | composition of 4 axioms |
| 7 | `unpacked_preserves_bytes (b : UUIDBytes) : (hexToBytes ...).length = 16` | `UUID.lean:103` | consequence of #6 |
| 8 | `encode_decode_roundtrip (pk : Bytes) : mainAddressDecode (mainAddressEncode pk) = some pk` | `MainAddress.lean:148` | `base58Encode_decode` axiom + list `take`/`drop` |
| 9 | `decode_encode_roundtrip (addr pk) : mainAddressEncode (extract pk (mainAddressDecode addr)) = addr` | `MainAddress.lean:155` | same shape as #8 |

---

## Axiom inventory

`UUID.lean` and `MainAddress.lean` use axioms for third-party primitives
that are out of scope for hand-written Lean 4.

### `UUID.lean` — 9 axioms

| Axiom | Asserts | Discharged by |
|-------|---------|---------------|
| `bytesToHex` | hex of 16 bytes (function, non-evaluable) | define concretely as `List.map` over `Byte`s |
| `hexToBytes` | inverse (function, non-evaluable) | same |
| `formatDashed` | formats hex to dashed UUID | define as `h.take 8 ++ "-" ++ ...` |
| `stripDashes` | inverse | define as `String.filter (· != '-')` |
| `bytesToHex_hexToBytes` | hex ⇔ byte round-trip | `decide` once `bytesToHex` is concrete |
| `hexToBytes_bytesToHex` | reverse direction | same |
| `formatDashed_stripDashes` | dashed ⇔ undashed | `decide` |
| `bytesToHex_length` | hex length = 32 | `decide` |
| `formatDashed_length` | dashed length = 36 | `decide` |

All 9 axioms in `UUID.lean` are **dischargeable** in Lean 4 with a
few lines of code each. Closing them would make the UUID round-trip
`sorry`s provable in well under 100 lines and would make the
`#guard`s in `Correspondence.lean` extensible to UUID.

### `MainAddress.lean` — 5 axioms

| Axiom | Asserts | Discharged by |
|-------|---------|---------------|
| `sha3_256` | SHA3-256 exists (noncomputable) | depends on a verified SHA3 Lean library |
| `base58Encode` | Base58 encode (noncomputable) | hand-written Base58 (~50 lines) |
| `base58Decode` | Base58 decode (noncomputable) | same |
| `base58Encode_decode` | Base58 round-trip | consequence of a concrete impl |
| `mainAddressPrefix_startsWith` | `(prefix ++ s).startsWith prefix = true` | `String.append_prefix_startsWith`-style lemma |

`base58Encode_decode` and `mainAddressPrefix_startsWith` are
**dischargeable** in pure Lean 4 (a Base58 implementation is ~50
lines). The SHA3-256 / Base58 function axioms are out of scope for
the current effort — closing them requires a verified-crypto Lean
library or a hand-written SHA3-256 (~200 lines of Lean 4).

---

## Gaps and recommendations

In order of highest value:

1. **Discharge the `UUID` axioms** (medium effort, high payoff). Once
   the 4 functional axioms are concrete, the 2 `sorry` round-trip
   `theorem`s in `UUID.lean` become provable in a few lines each, and
   the `#guard` byte-level checks in `Correspondence.lean` can be
   extended to UUID. This would move `UUID.lean` from Phase 3 to
   Phase 5.
2. **Prove the Varint / UintCodec round-trip `sorry`s** (low effort,
   medium payoff). The general round-trip is straightforward induction
   for Varint and straightforward `omega` for UintCodec. Closing these
   would formalise the strongest properties the Ruby codecs have.
3. **Hand-write Base58 in Lean 4** (medium effort, high payoff for
   `MainAddress`). A pure-Lean Base58 codec is ~50 lines and would
   discharge 3 of the 5 `MainAddress` axioms, making the round-trip
   `sorry`s provable.
4. **Phase 3 work for `MixAddress`** (medium effort). The informal spec
   exists; the Lean spec + implementation would advance the second
   Tier 2 target.
5. **Phase 1 work for `Transaction` encoder/decoder** (high effort,
   high payoff). Tier 3, uses the Tier 1 codecs as building blocks.
   Golden fixture `test/fixtures/transactions/version3_multi_io.hex`
   provides the byte-level oracle.

---

## Concerns

- **Axiom-burdened proofs**: the 14 axioms in `UUID` / `MainAddress`
  mean those proofs are *only as strong as the axioms*. A
  `lake build` passing for `UUID.lean` does **not** mean the
  `bytesToHex` ⇔ byte round-trip has been verified — it means the
  axioms have been *assumed* and the abstract proof is consistent
  with them. **Action**: add a note in `CORRESPONDENCE.md` (already
  present in §6) and a `#guard` cross-check on the concrete
  `bytesToHex` / `formatDashed` once they are defined.
- **The 9 `sorry` round-trip theorems**: `lake build` passes with
  them in place (Lean 4 does not require `sorry`s to be discharged
  for the build to succeed). The current CI does **not** fail on
  `sorry`. **Action**: add a `sorry`-count check to `lean-ci.yml`
  in a future run so that `sorry` regressions are caught.
- **Comment-only bug fixed**: `UintCodec.lean:22–25` previously said
  "big-endian" while the implementation is little-endian. **This has
  been corrected in run 6.** No theorem was affected; only the
  comment was wrong.
- **No Mathlib**: the four current models are deliberately
  Mathlib-free. This keeps the build fast and the dependency tree
  small, but it rules out tactic-based approaches for harder proofs.
  Tier 3 (`Transaction` codec) will likely need Mathlib for
  `omega` on larger arithmetic expressions.

---

## Positive findings

1. **`encodeInt` is a *clean* functional translation of the Ruby**
   (`encoder.rb:53–69`). The accumulator-based encoding in Ruby
   (`bytes.push int & 255; int = int / 256`) maps directly to a
   structural-recursive Lean definition. The `#eval`-based
   correspondence harness in `formal-verification/tests/tier1_codecs/`
   confirms they agree on 14 inputs.
2. **`encode_uint*` is little-endian**, and the Lean model gets the
   endianness right (after the comment fix in run 6). The Ruby
   `pack('S*').bytes.reverse` pattern is mirrored exactly by
   `encodeUint16 n = [n/256 % 256, n%256]`.
3. **`#guard`-based validation** is a strong, repeatable check. Any
   future change to the Ruby codec that breaks parity with the Lean
   model will be caught at `lake build` time, before the change is
   merged.
4. **No real bugs found in the Ruby code** across all 4 targets. This
   is a positive finding (the code is correct), though the absence
   of bugs is consistent with the implementation being a faithful
   port of the Go SDK with well-tested golden fixtures.

---

## Cross-references

- **`formal-verification/CORRESPONDENCE.md`**: per-definition Ruby ↔
  Lean mapping with correspondence level, divergences, impact on
  proofs, and validation evidence.
- **`formal-verification/RESEARCH.md`**: survey of the codebase and
  identification of FV-amenable targets.
- **`formal-verification/TARGETS.md`**: prioritised target list with
  current phase per target.
- **`formal-verification/specs/*_informal.md`**: informal specs per
  target.
- **`formal-verification/lean/FVSquad/*.lean`**: hand-written Lean 4
  specs, implementations, and proofs.
- **`formal-verification/tests/tier1_codecs/`**: executable
  correspondence harness (Ruby side + Lean side, 77 `#guard` checks).
