# Informal Specification — `encode_uint16/32/64` / `decode_uint16/32/64`

> 🔬 *Lean Squad — automated formal verification for `baizhiheizi/mixin_bot`.*

**Source files**:
- `lib/mixin_bot/utils/encoder.rb` (`encode_uint16`, `encode_uint32`,
  `encode_uint64`)
- `lib/mixin_bot/utils/decoder.rb` (`decode_uint16`, `decode_uint32`,
  `decode_uint64`)

## 1. Purpose

The fixed-width unsigned integer codec encodes a non-negative integer `n`
with `bits ∈ {16, 32, 64}` as a `bits/8`-byte list and decodes it back.
The encoding is *little-endian* in the input list (the lowest byte is
first), but Ruby's `pack('S*' | 'L*' | 'Q*')` produces a *native-endian*
binary string that the implementation then `bytes.reverse`s — so the
output list is **big-endian** (highest byte first). The decode reverses
this: it reverses the list to get native-endian, then `pack`s and
`unpack1`s it back to an integer.

In effect, for any `n` in range, the function pair is the standard
big-endian serialisation of the unsigned integer.

## 2. Preconditions

- `encode_uintN` requires `n : Integer` with `0 ≤ n < 2^N`. The Ruby
  implementation raises `ArgumentError` if `n` is negative or out of
  range; in the Lean model, the function is total on the subtype
  `{ n : ℕ // n < 2^N }`.
- `decode_uintN` requires a list of exactly `N/8` bytes. In the Lean
  model, the function is total on `Vector (Fin 256) (N/8)`.

## 3. Postconditions

- `encode_uintN n` always returns a list of exactly `N/8` bytes.
- `decode_uintN bs` always returns a value in `0 ≤ x < 2^N`.

## 4. Round-Trip Property

For all `n : { n : ℕ // n < 2^N }`:

> `decode_uintN (encode_uintN n) = n`

For all `bs : Vector (Fin 256) (N/8)` whose bytes collectively encode a
value in range:

> `encode_uintN (decode_uintN bs) = bs`

(the second requires `bs` to be a valid big-endian encoding, which is
always true for any `bs : Vector (Fin 256) (N/8)`).

## 5. Length Property

`encode_uintN n` always returns a list of length `N/8`:

- `encode_uint16` → 2 bytes
- `encode_uint32` → 4 bytes
- `encode_uint64` → 8 bytes

## 6. Big-Endian Semantics

For a list `bs = [b₀, b₁, ..., b_{k-1}]` of length `k = N/8`:

> `decode_uintN bs = Σ_{i=0}^{k-1} b_i · 256^{k-1-i}`

That is, the most significant byte of the encoded value is at the head
of the list.

## 7. Endianness Note (the implementation's little quirk)

The Ruby code uses `[int].pack('S*').bytes.reverse` — the `.reverse` is
because Ruby's `pack` is *native-endian* (little-endian on the
implementation platform the tests run on). The `.bytes.reverse` converts
the native-endian representation to a big-endian list of bytes.

The Lean model **does not model this two-step**; it directly states the
big-endian output. This is a faithful model because the *output bytes
list* is what the rest of the codebase sees, regardless of how the
implementation produced it. The correspondence is "exact" on the
external behaviour.

## 8. Edge Cases

| Width | `n` | `encode_uintN n` | `decode_uintN` of that |
|-------|-----|-------------------|------------------------|
| 16 | `0` | `[0, 0]` | `0` |
| 16 | `1` | `[1, 0]` | `1` |
| 16 | `256` | `[0, 1]` | `256` |
| 16 | `65535` | `[255, 255]` | `65535` |
| 32 | `0` | `[0, 0, 0, 0]` | `0` |
| 32 | `1` | `[1, 0, 0, 0]` | `1` |
| 32 | `4294967295` | `[255, 255, 255, 255]` | `4294967295` |
| 64 | `0` | `[0, 0, 0, 0, 0, 0, 0, 0]` | `0` |
| 64 | `1` | `[1, 0, 0, 0, 0, 0, 0, 0]` | `1` |

The boundary values (max value for each width) are the most important
to test, since they catch off-by-one bugs in the bit slicing.

## 9. Inferred Intent

The codec is a direct big-endian fixed-width serialisation. The only
contract is the round-trip on valid inputs and the length property.

The use of `bytes.reverse` in the Ruby source is a quirk of how Ruby
packs integers natively, not a behavioural choice. Any spec describing
the *external* behaviour of these functions should treat them as plain
big-endian.

## 10. Open Questions for Maintainers

1. Are `encode_uint16/32/64` ever expected to handle values `≥ 2^N`? The
   current Ruby code uses `pack('S*' | 'L*' | 'Q*')`, which silently
   truncates to the low N bits on overflow. The Lean model treats
   the domain as exactly `{ n : ℕ // n < 2^N }` and does not model the
   overflow path. Acceptable?

2. Should the three widths be modelled as three separate functions
   (mirroring the Ruby) or as a single parametric function over
   `bits : Nat`? Plan: three separate functions for now, since they
   have different precondition shapes and the parametric version adds
   unnecessary proof complexity for the same external behaviour.

3. The Ruby `bytes` are `Array<Integer>`, but the Ruby `pack` and
   `unpack1` only ever return values in `[0, 255]`. The Lean model
   uses `Fin 256` to make the type-level guarantee explicit. The
   contract with callers is the same.

---

## Last Updated
- **Date**: 2026-06-15
- **Commit**: `<pending>`
