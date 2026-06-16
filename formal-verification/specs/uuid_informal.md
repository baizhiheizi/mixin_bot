# Informal Specification — `MixinBot::UUID` Format Round-Trip

> 🔬 *Lean Squad — automated formal verification for `baizhiheizi/mixin_bot`.*

**Source file**: `lib/mixin_bot/uuid.rb`
**Test oracles**: `test/mixin_bot/test_address.rb` (uses `TEST_UID`), the
constant `965e5c6e-434c-3fa9-b780-c50f43cd955c` documented in the source
docstring, and the Mixin Network UUID format (RFC 4122 hex layout).

## 1. Purpose

`MixinBot::UUID` converts between three equivalent representations of a
Mixin Network UUID:

| Format | Length | Example |
|--------|--------|---------|
| Dashed UUID | 36 chars (`8-4-4-4-12`) | `965e5c6e-434c-3fa9-b780-c50f43cd955c` |
| Hex (no dashes) | 32 chars | `965e5c6e434c3fa9b780c50f43cd955c` |
| Packed binary | 16 bytes | 16 arbitrary bytes |

The class exposes two methods:

- `UUID#packed` — returns the 16-byte packed binary form.
- `UUID#unpacked` — returns the dashed UUID string.

A `UUID` is constructed from either `:hex` (a hex string, with or without
dashes) or `:raw` (a 16-byte binary string). The constructor raises
`MixinBot::InvalidUuidFormatError` if the input is the wrong length.

## 2. Preconditions

- **Constructor with `:hex`**: the input, after stripping `-`, must be exactly
  32 hex characters; otherwise `InvalidUuidFormatError` is raised.
- **Constructor with `:raw`**: the input must be exactly 16 bytes; otherwise
  `InvalidUuidFormatError` is raised.

## 3. Postconditions

- `UUID#packed` always returns a 16-byte `String`.
- `UUID#unpacked` always returns a 36-character `String` in the form
  `XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX` where the groups are
  8-4-4-4-12 hex characters.

## 4. Round-Trip Properties

Let `H` = 32-char hex string (no dashes), `D` = 36-char dashed UUID, `B` =
16-byte binary string. For valid inputs:

- `packed ∘ unpacked = id` on `D` (parsing then serialising returns the same
  dashed string).
- `unpacked ∘ packed = id` on `B` (serialising then parsing returns the same
  bytes).
- `packed ∘ hex_to_uuid = packed_of_hex` — feeding the dashed form into
  `packed` produces the same bytes as feeding the equivalent hex form.
- `unpacked ∘ hex_to_uuid = id` on `H` — feeding hex via the unpacked path
  produces a dashed string with the same underlying 16 bytes.
- Hex ⇔ bytes is a bijection: `bytes_to_hex ∘ hex_to_bytes = id` and vice
  versa, on valid inputs.

## 5. Invariants

- The dashed string always groups the underlying 16 bytes as
  `8-4-4-4-12`.
- The packed bytes are exactly the 16 bytes encoded by the hex string.
- The hex characters (after stripping dashes) are always lower-case in
  `packed → unpacked` (Ruby's `unpack1('H*')` produces lowercase hex).

## 6. Edge Cases

- The input `965e5c6e-434c-3fa9-b780-c50f43cd955c` (documented in source)
  must round-trip exactly.
- The input `b9f49cf777dc4d03bc54cd1367eebca319f8603ea1ce18910d09e2c540c630d8`
  (asset UUID used in transaction tests) must round-trip exactly.
- A UUID whose first hex character is `<= '7'` (e.g. `0...` through `7...`)
  is not allowed to have a high bit set anywhere; this is implicit in the
  format.
- Hex with mixed case (e.g. `A1B2...`) — Ruby's `pack('H*')` is case
  insensitive on input, so the spec accepts either case on input and
  produces lowercase on output.

## 7. Examples (from source and tests)

| Input | Method | Output |
|-------|--------|--------|
| `hex: '965e5c6e-434c-3fa9-b780-c50f43cd955c'` | `packed` | 16-byte binary |
| `hex: '965e5c6e-434c-3fa9-b780-c50f43cd955c'` | `unpacked` | `'965e5c6e-434c-3fa9-b780-c50f43cd955c'` |
| `hex: '965e5c6e434c3fa9b780c50f43cd955c'` | `unpacked` | `'965e5c6e-434c-3fa9-b780-c50f43cd955c'` |
| `raw: <16 bytes>` | `unpacked` | dashed UUID |

## 8. Inferred Intent

The class is a *thin formatting layer* — the only real computation is the
canonical grouping into `8-4-4-4-12` and the hex/binary conversion. The
constructor exists solely to validate input lengths. The intent is that:

- the three formats are perfectly equivalent on valid inputs, and
- the dashed form is a presentation choice only.

## 9. Open Questions for Maintainers

1. Should the dashed form preserve the case of the input hex, or always
   produce lowercase? The current implementation always produces lowercase
   (via `unpack1('H*')`).
2. Is it intended that `hex` may be either dashed or undashed on input? The
   constructor accepts both. The Lean model will mirror this.
3. Does the constructor guarantee rejection of *non-hex* characters? The
   current `pack('H*')` would silently truncate / mis-parse such input;
   we will model the constructor as accepting *any* 32-char string of
   `gsub('-','')` output, treating non-hex chars as undefined behaviour
   (out of scope).

---

## Last Updated
- **Date**: 2026-06-15
- **Commit**: `<pending>`
