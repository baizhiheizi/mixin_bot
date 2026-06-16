# Informal Specification — `encode_int` / `decode_int` (Varint Codec)

> 🔬 *Lean Squad — automated formal verification for `baizhiheizi/mixin_bot`.*

**Source files**:
- `lib/mixin_bot/utils/encoder.rb` (`encode_int`)
- `lib/mixin_bot/utils/decoder.rb` (`decode_int`)

## 1. Purpose

The varint codec encodes a non-negative integer as a sequence of bytes and
decodes it back. The encoding is *big-endian* in the sense that the most
significant byte comes first in the output (i.e. the high byte of the
integer appears earlier in the byte list), and each byte is the
corresponding 8-bit limb of the integer. This is the format used in
Mixin transaction deposit amounts (see `bytes_of` in the same file).

The implementation is intentionally simple and may be inverted exactly:
given any non-negative integer, `decode_int (encode_int n) = n`.

## 2. Preconditions

- `encode_int` requires an `Integer`. The Ruby implementation raises
  `ArgumentError` for non-integer input; the Lean model treats the
  function as a **total function on `ℕ`**.
- `decode_int` requires an `Array` of bytes. The Ruby implementation raises
  `ArgumentError` for non-array input; the Lean model treats the function
  as a **total function on `List (Fin 256)`** (i.e. bytes).

## 3. Postconditions

- `encode_int 0 = [0]` — the zero integer is encoded as a single zero byte.
- `encode_int n` for `n > 0` produces a list of bytes whose length equals
  the number of base-256 digits of `n` (i.e. `⌊log₂₅₆ n⌋ + 1`).
- `decode_int [] = 0` — the empty list decodes to zero.
- `decode_int` interprets bytes in big-endian order: the head byte is the
  most significant 8-bit limb of the result.

## 4. Round-Trip Property

For all `n : ℕ`:

> `decode_int (encode_int n) = n`

This is the headline property to prove.

## 5. Length Property

- `encode_int 0` has length 1.
- For `n > 0`, `(encode_int n).length = ⌊log₂₅₆ n⌋ + 1`.

This is implied by the round-trip plus the invertibility of `decode_int`
on its image, but stated explicitly to give a tractable secondary
property.

## 6. Big-Endian Semantics

`decode_int` is a left fold that shifts the accumulator left by 8 bits
and adds the next byte. Concretely, for a non-empty list
`[b₀, b₁, ..., b_{k-1}]`:

> `decode_int [b₀, b₁, ..., b_{k-1}] = Σ_{i=0}^{k-1} b_i · 256^{k-1-i}`

This is the standard big-endian interpretation. The `encode_int`
implementation produces exactly this list for any non-negative `n`.

## 7. Edge Cases

| Input | `encode_int` | `decode_int` of that |
|-------|--------------|-----------------------|
| `0` | `[0]` | `0` |
| `1` | `[1]` | `1` |
| `127` | `[127]` | `127` |
| `128` | `[0, 1]` | `128` |
| `255` | `[255]` | `255` |
| `256` | `[0, 1]` | `256` |
| `65535` | `[255, 255]` | `65535` |
| `65536` | `[0, 0, 1]` | `65536` |

Note: the encoder is "minimal" — it produces the smallest list that
encodes the value, i.e. no leading zero bytes. The only exception is
`encode_int 0 = [0]` (one zero byte), which makes the round-trip total.

## 8. Inferred Intent

The function is meant to be the inverse of `decode_int` on all valid
inputs. The trivial case `encode_int 0 = [0]` is required to make
`decode_int` total on the image of `encode_int`: without the special case
`encode_int 0 = []`, the round-trip property would fail for zero.

The implementation has no other observable behaviour — the only contract
is the round-trip.

## 9. Open Questions for Maintainers

1. The implementation's `bytes.reverse` at the end of `encode_int` shows
   that the function builds the list least-significant-byte first and then
   reverses. Should the Lean model express this reversal explicitly (i.e.
   as a `List.reverse` of an `acc`-style list) or just state the resulting
   list? Plan: state the result as a closed-form definition; the proof
   uses the list reversal lemma from Mathlib.

2. Negative integers are explicitly excluded by `ArgumentError` in the
   Ruby implementation. The Lean model will restrict to `ℕ` and not model
   the error path. Acceptable?

3. The Ruby `bytes` are returned as `Array<Integer>` in `[0, 255]`. The
   Lean model will use `List (Fin 256)` (i.e. `List UInt8`) as the canonical
   representation. The two are equivalent up to the `Fin 256 ↔ ℕ`
   coercion.

---

## Last Updated
- **Date**: 2026-06-15
- **Commit**: `<pending>`
