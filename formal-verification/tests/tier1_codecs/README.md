# Lean Squad — Tier 1 Codecs Correspondence Harness

> 🔬 *Lean Squad — automated formal verification for `baizhiheizi/mixin_bot`.*
>
> This directory contains the **executable** correspondence harness
> (Task 8, Route B) for the Tier 1 codecs. It runs the Ruby and Lean
> implementations side-by-side on the same inputs and asserts that
> they produce identical output.

## What this proves

For each of the four Tier 1 codecs, the harness verifies that the
Lean model in `formal-verification/lean/FVSquad/` produces the **same
byte sequence** as the live Ruby implementation in
`lib/mixin_bot/utils/encoder.rb` and `lib/mixin_bot/utils/decoder.rb`,
on a curated set of inputs.

The codecs covered:

| Codec | Ruby source | Lean source | Checked inputs |
|-------|-------------|-------------|---------------|
| Varint | `encode_int` (lines 53–69) | `FVSquad.Varint.encodeInt` | 14 |
| Varint round-trip | `decode_int` (lines 42–46) | `FVSquad.Varint.decodeInt` | 14 |
| Uint16 | `encode_uint16` (lines 22–27) | `FVSquad.UintCodec.encodeUint 16` | 10 |
| Uint16 round-trip | `decode_uint16` (lines 24–29) | `FVSquad.UintCodec.decodeUint 16` | 7 |
| Uint32 | `encode_uint32` (lines 28–32) | `FVSquad.UintCodec.encodeUint 32` | 7 |
| Uint32 round-trip | `decode_uint32` (lines 30–34) | `FVSquad.UintCodec.decodeUint 32` | 7 |
| Uint64 | `encode_uint64` (lines 35–39) | `FVSquad.UintCodec.encodeUint 64` | 8 |
| Uint64 round-trip | `decode_uint64` (lines 35–40) | `FVSquad.UintCodec.decodeUint 64` | 8 |
| Lengths | (all four) | (all four) | 6 |

**77 byte-level `#guard` checks across 84 input/output pairs.** All
checks pass on the current `main` (Lean 4.31.0, `lake build` clean).

## How to run

```bash
bash formal-verification/tests/tier1_codecs/run.sh
```

The script:
1. Runs `ruby_harness.rb` to regenerate `fixtures.json` from the
   *live* Ruby implementation.
2. Runs `lake build` in `formal-verification/lean/`, which executes
   all `#guard` statements in `FVSquad/Correspondence.lean` against
   the Lean model.
3. Reports pass/fail and the number of checks.

**Exit code 0** = both sides agree on every input.
**Exit code 1** = at least one mismatch (or a toolchain failure).

## What this does *not* prove

- **`UUID` codec** (`FVSquad.UUID`) — the Lean model uses
  `noncomputable` axioms for `bytesToHex` / `formatDashed` /
  `stripDashes`, so the round-trip cannot be `#eval`-ed in Lean 4.
  Correspondence is established via the existing test oracle in
  `test/mixin_bot/test_uuid.rb` and the round-trip `sorry`s in
  `FVSquad/UUID.lean`. The Ruby `UUID#packed` / `UUID#unpacked`
  outputs are captured in `fixtures.json` for future direct
  comparison once a concrete implementation is supplied.
- **`MainAddress`** — depends on SHA3-256 and Base58, both axiomatised
  in `FVSquad.MainAddress`. Requires a verified-crypto Lean library
  or hand-written Base58/SHA3-256 implementations to `#eval`.
- **General round-trip theorems** — the harness checks the *byte
  values* on a finite set of inputs. The general `encodeInt_decodeInt`,
  `encodeUintN_decodeUintN`, etc. are `sorry` in the Lean files
  (Phase 5 work).

## Adding more cases

To add a new test case:

1. **Add the input** to the relevant `*_INPUTS` array in
   `ruby_harness.rb` (e.g. `VARINT_INPUTS`).
2. **Regenerate the fixture** by re-running the harness.
3. **Copy the expected bytes** from `fixtures.json` into a new
   `#guard` line in `formal-verification/lean/FVSquad/Correspondence.lean`.
4. **Re-run** `bash formal-verification/tests/tier1_codecs/run.sh`.

If a `#guard` fails, the harness reports the mismatch via the Lean
build error.

## Files

| File | Purpose |
|------|---------|
| `ruby_harness.rb` | Exercises the Ruby implementation, emits JSON |
| `fixtures.json` | Generated JSON of expected byte values (regenerable) |
| `run.sh` | End-to-end harness: Ruby side + Lean side |
| `README.md` | This file |
| `formal-verification/lean/FVSquad/Correspondence.lean` | Lean `#guard` checks (77 statements) |

## Last updated

- **Date**: 2026-06-17
- **Branch**: `lean-squad/correspondence-tests-critique-d5fe5f7e686ad20e`
- **Toolchain**: Lean 4.31.0 (stable), Ruby 4.0.5
- **Status**: ✓ 77/77 correspondence checks pass
