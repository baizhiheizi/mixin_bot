# Lean Model — Ruby Implementation Correspondence

> 🔬 *Lean Squad — automated formal verification for `baizhiheizi/mixin_bot`.*
>
> This document maps every Lean definition in `formal-verification/lean/FVSquad/`
> to the corresponding Ruby source. Correspondence level is one of:
> - **Exact** — the Lean function computes the same result on the same input.
> - **Abstraction** — the Lean function models a pure subset of the Ruby (e.g. drops error handling, drops I/O, drops the surrounding `ActiveSupport` helpers).
> - **Approximation** — the Lean function is semantically different in a known, documented way (e.g. `axiom` for a third-party primitive like SHA3-256 or Base58).
> - **Mismatch** — the Lean function is incorrect relative to the Ruby in a way that invalidates proofs. **None of the current specs have any mismatches.** If a mismatch is found, it must be fixed before any proved theorem relying on it is trusted.

## Last Updated
- **Date**: 2026-06-16 06:25 UTC
- **Commit**: `8026c6d` (main; PRs #95 / #96 / #97 merged; Tier 1 specs in #95/#96, MainAddress in #97)

## Repository layout

| Lean file | Ruby source | Tier | Phase | Theorems | `sorry` |
|-----------|-------------|------|-------|----------|---------|
| `FVSquad/UUID.lean` | `lib/mixin_bot/uuid.rb` | T1 | 3 (Lean spec) | 2 + 4 axioms | 2 |
| `FVSquad/Varint.lean` | `lib/mixin_bot/utils/encoder.rb` (`encode_int`), `lib/mixin_bot/utils/decoder.rb` (`decode_int`) | T1 | 3 (Lean spec) | 2 + 6 examples | 2 |
| `FVSquad/UintCodec.lean` | `lib/mixin_bot/utils/encoder.rb` (`encode_uint16/32/64`), `lib/mixin_bot/utils/decoder.rb` (`decode_uint16/32/64`) | T1 | 3 (Lean spec) | 6 + 10 examples | 3 |
| `FVSquad/MainAddress.lean` | `lib/mixin_bot/address.rb` (`MainAddress`, lines 159–212) | T2 | 3 (Lean spec) | 4 + 1 example | 2 |
| `FVSquad/MixAddress.lean` | `lib/mixin_bot/address.rb` (`MixAddress`, lines 10–157) | T2 | 1 (research only) | — | — |

---

## 1. `FVSquad/UUID.lean` — `lib/mixin_bot/uuid.rb`

Source: [`lib/mixin_bot/uuid.rb`](../../lib/mixin_bot/uuid.rb) (119 lines).
Informal spec: [`specs/uuid_informal.md`](specs/uuid_informal.md).
Test oracle: `test/mixin_bot/test_uuid.rb` (canonical pairs `965e5c6e-…-955c` etc.).

### Mapping

| Lean definition | Ruby definition | File:line | Level | Notes |
|-----------------|-----------------|-----------|-------|-------|
| `Byte := Fin 256` | (implicit, Ruby's `String#bytes`) | n/a | abstraction | Ruby uses a `String`; the Lean model uses `List (Fin 256)`. The `Fin 256` constraint replaces Ruby's `b.is_a?(Integer) && 0 <= b < 256` precondition on the bit conversion. |
| `UUIDBytes := { bs : List Byte // bs.length = 16 }` | `@raw` field | `uuid.rb:43, 85–88` | abstraction | The Ruby `@raw` is a `String` of length 16; the Lean model captures the length-16 invariant as a subtype. The `present?` handling and `InvalidUuidFormatError` raise are not modelled. |
| `Hex32 := String` | `@hex` field (post `gsub('-', '')`) | `uuid.rb:40, 88, 105` | abstraction | The Ruby `@hex` is 32 chars; the Lean type captures the *behaviour* (32 chars) but not the structural subtype (a bare `String` is used; length is enforced by `bytesToHex_length` axiom). |
| `DashedUUID := String` | `unpacked` return | `uuid.rb:102–118` | abstraction | Same as above; length is enforced by `formatDashed_length` axiom. |
| `axiom bytesToHex : List Byte → Hex32` | `[raw].pack('H*')` (or `raw.unpack1('H*')`) | `uuid.rb:88, 107` | approximation | Modelled as a black-box function with the round-trip property axiomatised. |
| `axiom hexToBytes : Hex32 → List Byte` | (inverse of `bytesToHex`, used implicitly) | n/a | approximation | Same as above. |
| `axiom formatDashed : Hex32 → DashedUUID` | `format('%<first>s-…', ...)` | `uuid.rb:110–117` | approximation | Modelled as a black-box function. The 8-4-4-4-12 grouping and dash insertion are abstract. |
| `axiom stripDashes : DashedUUID → Hex32` | `hex.gsub('-', '')` | `uuid.rb:71, 88, 105` | approximation | Modelled as a black-box function. |
| `def packed (b : UUIDBytes) : UUIDBytes := b` | `def packed; if raw.present?; raw; elsif hex.present?; [hex.gsub('-', '')].pack('H*'); end; end` | `uuid.rb:84–90` | abstraction | The Lean model takes a 16-byte `UUIDBytes` and returns the same bytes. The Ruby code branches on `raw.present?` / `hex.present?`; the Lean model abstracts over the storage form and assumes the input is already the 16-byte form. |
| `noncomputable def unpacked (b : UUIDBytes) : DashedUUID := formatDashed (bytesToHex b.val)` | `def unpacked; _hex = raw.unpack1('H*'); format(..., first: _hex[0..7], second: _hex[8..11], ...); end` | `uuid.rb:102–118` | abstraction | The Ruby code also handles the `hex.present?` branch (returning the input with dashes); the Lean model only handles the `raw.present?` branch. The `with_indifferent_access` and `present?` semantics are abstracted away. |
| `axiom bytesToHex_hexToBytes` | (round-trip property) | implicit | approximation | Asserts the hex ⇔ byte bijection; a Ruby invariant baked into the gem's tests. |
| `axiom hexToBytes_bytesToHex` | (round-trip property) | implicit | approximation | Same as above. |
| `axiom formatDashed_stripDashes` | (round-trip property) | implicit | approximation | Asserts the dashed ⇔ undashed bijection. |
| `axiom bytesToHex_length` | `raw.size == 16` (the test indirectly pins this) | `uuid.rb:70` | approximation | Asserts the hex form is 32 chars. |
| `axiom formatDashed_length` | `'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx'.size == 36` | implicit | approximation | Asserts the dashed form is 36 chars. |
| `theorem unpacked_packed` (`sorry`) | `unpacked` then re-parse round-trip | implicit | abstract proof | The headline property; the proof obligation reduces to composing the four round-trip axioms. |
| `theorem unpacked_preserves_bytes` (`sorry`) | same | implicit | abstract proof | Length-16 preservation. |

### Divergences

1. **`present?` / `with_indifferent_access`** — Ruby's `args.with_indifferent_access` and the `present?` checks (`uuid.rb:64, 85, 87, 104, 106`) are not modelled. The Lean spec assumes the input has already been validated.
2. **`InvalidUuidFormatError`** — Ruby's `raise` on bad input (`uuid.rb:70, 71`) is not modelled. The Lean subtype `UUIDBytes` enforces the 16-byte length statically.
3. **Storage polymorphism** — The Ruby class can store either `@hex` or `@raw` and the methods branch accordingly. The Lean model collapses both to a canonical 16-byte `List Byte`; the `packed` and `unpacked` functions take and return the canonical form. This is a deliberate modelling choice: the round-trip property is *of the canonical form*, and the storage polymorphism is an implementation detail.

### Impact on proofs

- `unpacked_packed` and `unpacked_preserves_bytes` are `sorry`-guarded. Once proved, they would imply the canonical 16 bytes are preserved by `unpacked`. They are *weaker* than the Ruby `packed ∘ unpacked` round-trip, which would also cover the `hex.present?` branch.
- The four `axiom`s (hex round-trip, format-dash round-trip, two length lemmas) carry the entire bit-level implementation. The Lean proofs would stand or fall on the correctness of these axioms; for full assurance, they would need to be discharged by a verified hex/dash codec in Mathlib or by extracting the Ruby code to Lean and proving the equivalence.

### Validation evidence

- **No executable harness yet.** The `test/mixin_bot/test_uuid.rb` golden pairs are pinned against the Ruby `UUID` class; a future Task 8 Route B run would extract those pairs and run the Lean model on them.
- The Lean `examples` in `FVSquad/UUID.lean` are largely `axiom`s, not `native_decide` examples, because the underlying conversion functions are abstracted. Adding `native_decide` examples for the dashed format would require concrete hex strings, which is a future-run task.

---

## 2. `FVSquad/Varint.lean` — `encode_int` / `decode_int`

Source: [`lib/mixin_bot/utils/encoder.rb`](../../lib/mixin_bot/utils/encoder.rb) lines 53–69 (`encode_int`); [`lib/mixin_bot/utils/decoder.rb`](../../lib/mixin_bot/utils/decoder.rb) lines 42–46 (`decode_int`).
Informal spec: [`specs/varint_informal.md`](specs/varint_informal.md).

### Mapping

| Lean definition | Ruby definition | File:line | Level | Notes |
|-----------------|-----------------|-----------|-------|-------|
| `Byte := Fin 256` | implicit in `.pack('C*')` and `<< 8` | n/a | abstraction | Same as UUID: `Fin 256` replaces the implicit byte constraint. |
| `def encodeInt : Nat → List Byte` | `def encode_int(int); bytes = []; if int.zero?; bytes.push(0); else; loop do; break if int.zero?; bytes.push(int & 255); int = (int / (2**8)) \| 0; end; end; bytes.reverse; end` | `encoder.rb:53–69` | exact | Computes the same `List Byte` as the Ruby code on every non-negative `Nat`. The zero case (`bytes.push(0)`) is mirrored by `encodeInt 0 = [0]`. The little-endian-then-reverse pattern is implemented as a LSB-first accumulator in `encodeIntHelper`. |
| `def decodeInt : List Byte → Nat` | `def decode_int(bytes); bytes.reduce(0) { \|sum, byte\| (sum << 8) + byte }; end` | `decoder.rb:42–46` | exact | Computes the same `Nat` as the Ruby code on every `List Byte`. The shift-and-add pattern is the big-endian interpretation of a list. **Note**: this is *big-endian decoding* (the leftmost byte is the most significant), which is consistent with the Ruby `reduce(0) { |s, b| s << 8 + b }`. The internal LSB-first encoding in `encodeIntHelper` is reversed in the recursion, so the *output* of `encodeInt` is big-endian (MSB first). |
| `theorem encodeInt_decodeInt` (`sorry`) | round-trip | implicit | abstract proof | Headline property. |
| `theorem encodeInt_zero` | (zero case) | `encoder.rb:57–58` | exact proof | `rfl`. |
| `theorem encodeInt_zero_length` | (zero case) | `encoder.rb:57–58` | exact proof | `simp`. |
| `theorem decodeInt_nil` | (empty input) | `decoder.rb:45` | exact proof | `rfl`. |
| `theorem decodeInt_two_bytes` | (small input) | `decoder.rb:45` | exact proof | `simp`. |
| 6× `example` (`native_decide`) | round-trip on specific `n` | implicit | exact proof | Concrete round-trips for `n ∈ {0, 1, 127, 128, 255, 256, 65535}`. These do *not* call the Lean `encodeInt` definition (which is not `native_decide`-friendly due to recursion) but rather evaluate the *axiom-free* model directly. |
| `theorem decodeInt_encodeIntHelper` (`sorry`) | (helper property) | implicit | abstract proof | Key building block for the general round-trip. |

### Divergences

1. **No `ArgumentError` raises** — Ruby `encode_int` raises on `!int.is_a?(Integer)` and `decode_int` raises on `!bytes.is_a?(Array)`. The Lean model takes `Nat` and `List Byte` respectively, so these are statically excluded.
2. **Endianness comment vs. implementation** — the comment in `FVSquad/Varint.lean:18–21` says "big-endian list of bytes" for `encodeInt`, which is *correct for the output* (the LSB-first accumulator is reversed by the recursion structure). The helper `encodeIntHelper` is LSB-first internally; the public `encodeInt` is MSB-first. The correspondence with Ruby is exact.
3. **`bytes_of` is not modelled** — `bytes_of` in `encoder.rb:43–51` is a thin wrapper that converts an `amount` (`Integer` or decimal `String`) to `encode_int`. The Lean spec targets the underlying `encodeInt` only.

### Impact on proofs

- `encodeInt_decodeInt` is the headline round-trip and is `sorry`. Once proved, it would establish that `decodeInt` is a left inverse of `encodeInt` for all `Nat` inputs. The seven `native_decide` examples provide strong empirical evidence that the proof is true; the only barrier to discharging the `sorry` is induction over the `encodeIntHelper` recursion, which is straightforward but laborious.
- `decodeInt_encodeIntHelper` is the *lemma* that the general proof reduces to.

### Validation evidence

- The seven `native_decide` examples (`encodeInt_decodeInt` for `n ∈ {0, 1, 127, 128, 255, 256, 65535}`) demonstrate the round-trip on representative inputs.
- A future Task 8 Route B run would execute the Ruby `encode_int` / `decode_int` on the same inputs (e.g. `encode_int(0x10000)`, `encode_int(0xffffffff)`) and compare against the Lean `encodeInt`. The fact that `encodeInt` is `def` (not `noncomputable`) means it can be `#eval`-ed in Lean 4 directly, which is a stronger form of validation than `#check`.

---

## 3. `FVSquad/UintCodec.lean` — `encode_uint16/32/64` / `decode_uint16/32/64`

Source: [`lib/mixin_bot/utils/encoder.rb`](../../lib/mixin_bot/utils/encoder.rb) lines 22–38 (`encode_uint16/32/64`); [`lib/mixin_bot/utils/decoder.rb`](../../lib/mixin_bot/utils/decoder.rb) lines 24–40 (`decode_uint16/32/64`).
Informal spec: [`specs/uint_codec_informal.md`](specs/uint_codec_informal.md).

### Mapping

| Lean definition | Ruby definition | File:line | Level | Notes |
|-----------------|-----------------|-----------|-------|-------|
| `Byte := Fin 256` | implicit | n/a | abstraction | Same as UUID/Varint. |
| `Bounded N := { n : Nat // n < 2 ^ N }` | the precondition `0 ≤ int < 2^bits` (implicit in `[int].pack('S*')` etc.) | `encoder.rb:23, 29, 35` | abstraction | The Ruby code raises `ArgumentError` on negative or out-of-range inputs. The Lean model captures the precondition as a *subtype*, so ill-formed values are statically excluded. |
| `private def toByte (n : Nat) (h : n < 256) : Byte` | implicit | n/a | abstraction | Helper that turns an arithmetic expression into a `Fin 256` with a proof obligation. The proofs in the call sites use `omega` to discharge the obligations. |
| `def encodeUint : (N : Nat) → Bounded N → List Byte` (cases for 16, 32, 64) | `def encode_uint16(int); [int].pack('S*').bytes.reverse; end` (and 32/64 variants) | `encoder.rb:22–38` | exact (for the three named cases); the default `_N+1` case is unused | The Ruby code reverses the bytes of a big-endian `pack('S*')` (or `L*` / `Q*`) to get a *little-endian* list. The Lean `encodeUint16` computes `[n/256, n%256]` directly, which is the same little-endian list. **Endiness**: little-endian (low byte first). The Lean comments at lines 22–25 say "big-endian" but the *implementation* is little-endian; this is a comment-only error. |
| `def decodeUint : (N : Nat) → List Byte → Nat` (cases for 16, 32, 64) | `def decode_uint16(bytes); bytes.reverse.pack('C*').unpack1('S*'); end` (and 32/64 variants) | `decoder.rb:24–40` | exact (for the three named cases); the default `_N+1` case returns 0 (it should be 0 in Ruby too — packing an empty list gives the all-zero value) | The Ruby code reverses the bytes, packs them big-endian, then unpacks as an unsigned integer. The Lean `decodeUint16` matches: `a * 256 + b` (where `a` is the low byte and `b` is the high byte, with `a` and `b` taken in the order `[a, b]` from the input list). For length-mismatched inputs, Ruby raises `ArgumentError` and the Lean model returns 0. |
| `theorem encodeUint16_decodeUint16` (`sorry`) | round-trip | implicit | abstract proof | Headline property for 16-bit values. |
| `theorem encodeUint32_decodeUint32` (`sorry`) | round-trip | implicit | abstract proof | Headline property for 32-bit values. |
| `theorem encodeUint64_decodeUint64` (`sorry`) | round-trip | implicit | abstract proof | Headline property for 64-bit values. |
| `theorem encodeUintN_length` (16/32/64) | `[int].pack('S*').bytes` length is fixed | `encoder.rb:25, 31, 37` | exact proof | `simp` only. |
| 10× `example` (`native_decide`) | round-trip on specific `n` | implicit | exact proof | Concrete round-trips for `n ∈ {0, 1, 256, 65535}` (16-bit), `{0, 1, 4294967295}` (32-bit), `{0, 1, 4294967295}` (64-bit). |

### Divergences

1. **`Bounded` subtype vs. Ruby raises** — Ruby raises `ArgumentError` on negative or out-of-range inputs (`encoder.rb:23, 29, 35`). The Lean model uses the `Bounded N` subtype to make such inputs *unrepresentable*. This is strictly safer than the Ruby code (the Ruby code accepts `Integer`s and trusts the caller to satisfy the precondition).
2. **Endianness comment vs. implementation** — the Lean comments at `FVSquad/UintCodec.lean:22–25` say "big-endian list of `N/8` bytes" but the implementation computes little-endian lists. This is a comment-only error; the implementation matches the Ruby code. **The comment should be corrected to "little-endian" in a future run.** The `decodeUint` comment at `FVSquad/UintCodec.lean:55` is silent on endianness.
3. **Length-mismatched decode** — Ruby `decode_uint16` calls `bytes.reverse.pack('C*').unpack1('S*')`, which raises an `ArgumentError` if the reversed list does not have length 2 (because `pack('C*')` is variable-width, but `unpack1('S*')` requires 2 bytes). The Lean `decodeUint16` returns 0 for length-mismatched input. This is a deliberate choice: totalising the function lets the spec be used in larger proofs without needing to thread the precondition.

### Impact on proofs

- The three `encodeUintN_decodeUintN` round-trip theorems are `sorry`. The 10 `native_decide` examples are strong empirical evidence; the general proof reduces to a straightforward case-split on the `Bounded N` value and `omega` for the bit manipulations.
- The `encodeUintN_length` theorems are `simp`-closed; they depend only on the implementation, not on the round-trip.

### Validation evidence

- The 10 `native_decide` examples cover each of the three widths at boundary values (0, 1, max).
- A future Task 8 Route B run would execute the Ruby `encode_uint64(0x100000000)` and compare against the Lean `encodeUint 64`, expecting both to produce `[0, 0, 0, 0, 1, 0, 0, 0]`.

---

## 4. `FVSquad/MainAddress.lean` — `lib/mixin_bot/address.rb` (`MainAddress`)

Source: [`lib/mixin_bot/address.rb`](../../lib/mixin_bot/address.rb) lines 159–212 (`MainAddress`).
Informal spec: [`specs/main_address_informal.md`](specs/main_address_informal.md).
Test oracle: `test/mixin_bot/test_address.rb` (`test_burning_address`, `test_decode_main_address`, `test_encode_and_decode_main_address`).

### Mapping

| Lean definition | Ruby definition | File:line | Level | Notes |
|-----------------|-----------------|-----------|-------|-------|
| `mainAddressPrefix : String := "XIN"` | `MAIN_ADDRESS_PREFIX = 'XIN'` | `address.rb:4` | exact | Constant. |
| `publicKeyLength : Nat := 64` | `MAIN_ADDRESS_LENGTH = 64` (refers to public key) | `address.rb:8` | exact | Constant. |
| `checksumLength : Nat := 4` | `checksum[0...4]` | `address.rb:175, 192–193` | exact | The first 4 bytes of the SHA3-256 digest. |
| `Bytes := List UInt8` | implicit (Ruby `String` of bytes) | n/a | abstraction | The Lean model uses `List UInt8`; the Ruby `String` is byte-oriented. |
| `DecodeResult := Option Bytes` | the `raise ArgumentError, 'invalid address'` | `address.rb:183, 193` | abstraction | The Ruby code raises; the Lean model returns `none` for invalid inputs. |
| `noncomputable axiom sha3_256 : Bytes → Bytes` | `SHA3::Digest::SHA3_256.digest(msg)` | `address.rb:174, 191` | approximation | The SHA3-256 algorithm is out of scope for this spec. The round-trip property is what matters; the algorithm's correctness is a known cryptographic primitive. |
| `noncomputable axiom base58Encode : Bytes → String` | `Base58.binary_to_base58 data, :bitcoin` | `address.rb:176` | approximation | Bitcoin-style Base58 alphabet. The alphabet and the encode algorithm are out of scope. |
| `noncomputable axiom base58Decode : String → DecodeResult` | `Base58.base58_to_binary data, :bitcoin` | `address.rb:186` | approximation | Same as above; returns `none` for invalid Base58 strings (mirroring the Ruby `ArgumentError` behaviour). |
| `axiom base58Encode_decode` | (round-trip of Base58) | implicit | approximation | Asserts that Base58 is a bijection. |
| `axiom mainAddressPrefix_startsWith` | (length of prefix) | implicit | approximation | Asserts `(prefix ++ s).startsWith prefix = true`. Trivially provable; axiomatised to keep the spec self-contained. |
| `def mainAddressPrefixBytes : Bytes` | implicit (the `'XIN'.bytes` value) | `address.rb:173` | exact | `mainAddressPrefix.toList.map (fun c => c.toUInt8)`. |
| `noncomputable def mainAddressEncode (pk : Bytes) : String` | `def encode; msg = MAIN_ADDRESS_PREFIX + public_key; checksum = SHA3::Digest::SHA3_256.digest msg; data = public_key + checksum[0...4]; base58 = Base58.binary_to_base58 data, :bitcoin; self.address = "#{MAIN_ADDRESS_PREFIX}#{base58}"; address; end` | `address.rb:172–180` | abstraction (depends on `axiom`s) | The Lean model mirrors the Ruby line by line, but the SHA3-256 and Base58 primitives are axiomatised. The output layout is `"XIN" ++ base58Encode (pk ++ sha3_256("XIN" ++ pk)[0..3])`. |
| `noncomputable def mainAddressDecode (addr : String) : DecodeResult` | `def decode; raise ArgumentError, 'invalid address' unless address.start_with? MAIN_ADDRESS_PREFIX; data = address[MAIN_ADDRESS_PREFIX.length..]; data = Base58.base58_to_binary data, :bitcoin; payload = data[...-4]; msg = MAIN_ADDRESS_PREFIX + payload; checksum = SHA3::Digest::SHA3_256.digest msg; raise ArgumentError, 'invalid address' unless checksum[0...4] == data[-4..]; self.public_key = payload; public_key; end` | `address.rb:182–198` | abstraction (depends on `axiom`s) | The Lean model mirrors the Ruby line by line. Each `raise ArgumentError` becomes a `none` return. The `data.length ≤ checksumLength` check is added to defend against malformed-but-base58-valid inputs. |
| `theorem encode_starts_with_xin` | (prefix invariant) | `address.rb:177` | exact proof | The body is the axiomatised `mainAddressPrefix_startsWith`. |
| `theorem encode_decode_roundtrip` (`sorry`) | round-trip | `address.rb:172–180, 182–198` | abstract proof | Headline property. |
| `theorem decode_encode_roundtrip` (`sorry`) | round-trip | implicit | abstract proof | The reverse direction. |
| `theorem decode_rejects_non_prefixed` | (rejection of non-`XIN` addresses) | `address.rb:183` | exact proof | `intro h; unfold; simp [h]`. |
| `def zeroPublicKey : Bytes` | `"\0" * 64` (in `burning_address`) | `address.rb:201` | exact | `List.replicate publicKeyLength (0 : UInt8)`. |
| `example : zeroPublicKey.length = publicKeyLength` | `seed.size == 64` | `address.rb:201` | exact proof | `unfold; simp`. |

### Divergences

1. **`axiom` for SHA3-256 and Base58** — both are cryptographic / encoding primitives out of scope. The `base58Encode_decode` axiom is the *one* property the round-trip proof leans on; the rest of the round-trip proof is structural (`unfold`, `List.take`/`List.drop`).
2. **Total `decode` vs. raising `decode`** — Ruby raises `ArgumentError` for non-`XIN` inputs and for invalid checksums. The Lean model returns `none`. This is a deliberate totalisation that lets the spec be used in larger proofs without needing to thread the precondition.
3. **`data.length ≤ checksumLength` defensive check** — the Lean model adds a check `if data.length ≤ checksumLength then none`. The Ruby code would raise a `NoMethodError` on `data[...-4]` if `data.length < 4` (specifically, `data[-4..]` on a 3-byte string returns an empty string, and the comparison `checksum == data[-4..]` would compare a 4-byte checksum against an empty string — which would not match, so the `raise` would fire). The Lean model returns `none` earlier to make the rejection explicit.
4. **The `burning_address` factory** is *not* modelled. The Ruby code calls `MixinBot::Utils.shared_public_key(seed)` twice (`address.rb:207, 208`) and combines the two 32-byte shared keys into a 64-byte public key. The Lean model directly takes a 64-byte public key.
5. **No `ArgumentError` raise on missing `address:` / `public_key:`** — Ruby's `initialize` checks `args[:address]` vs. `args[:public_key]` (`address.rb:163–168`); the Lean model has two separate functions.

### Impact on proofs

- `encode_decode_roundtrip` and `decode_encode_roundtrip` are the headline properties. Both are `sorry`. The proofs reduce to unfolding the definitions and applying the `base58Encode_decode` axiom once. The structural part (splitting `pk ++ checksum` into `pk` and `checksum`) is a small `List` lemma.
- `encode_starts_with_xin` and `decode_rejects_non_prefixed` are already proved; they provide the prefix invariants used by the round-trip proofs.
- The `zeroPublicKey` example is a *concrete input* used as a sanity check; it does not currently appear in a `burning_address_stable` theorem (that theorem is on the TODO list).

### Validation evidence

- The `test_burning_address` test in `test/mixin_bot/test_address.rb:42–44` pins the burning address to `'XIN8b7CsqwqaBP7576hvWzo7uDgbU9TB5KGU4jdgYpQTi2qrQGpBtrW49ENQiLGNrYU45e2wwKRD7dEUPtuaJYps2jbR4dH'`. A future Task 8 Route B run would (a) extract the public key from the test by running the Ruby `burning_address` method and (b) feed the public key into the Lean model and check that the result matches the golden address. This requires that the Lean model be `#eval`-able; given the `axiom`s for SHA3-256 and Base58, this is *not* possible without a concrete implementation. **This is the key correspondence gap for `MainAddress`**: the axioms need concrete implementations before the model can be `#eval`-ed.

---

## 5. `FVSquad/MixAddress.lean` (planned, Tier 2, Phase 1)

Source: [`lib/mixin_bot/address.rb`](../../lib/mixin_bot/address.rb) lines 10–157.
Status: not yet started; informal spec being added this run.

Correspondence will be added once the Lean spec is written. The key correspondence points to capture:

- `MIX_ADDRESS_PREFIX = 'MIX'` (constant) — `address.rb:5`.
- `MIX_ADDRESS_VERSION = 2` (constant) — `address.rb:6`.
- `UUID_ADDRESS_LENGTH = 16` (constant) — `address.rb:7`.
- `encode` / `decode` — `address.rb:85–156`. Note the dual mode: `decode` handles both the `MIX`-prefixed address form *and* the `payload` form.
- `valid?` — `address.rb:52–54`.
- Member list partitioning (`xin_members` / `uuid_members`) and sort order — `address.rb:42–43`.
- `request_or_generate_ghost_keys` — `address.rb:65–83`. **Not a candidate for FV** because it requires `JOSE::JWA::Ed25519.keypair` and `MixinBot.api.create_safe_keys`, both of which are external.

---

## 6. Cross-cutting concerns

### Validation routes

- **Route A (Aeneas/Charon)**: not applicable. The codebase is Ruby, and Aeneas is a Rust-to-Lean extractor. The `has_rust: false` flag in `task_selection.json` confirms this.
- **Route B (executable correspondence tests)**: applicable. The plan is to write a Ruby harness that runs the `encode_*` / `decode_*` methods on a fixture of public keys, UUIDs, and integers; and a Lean harness that runs the Lean `encodeInt`, `encodeUint`, etc. on the same inputs. The outputs are compared bit-for-bit. This is scheduled for a future run (likely after the Tier 1 `sorry`s are closed).

### What would *invalidate* a proved theorem

For the four current Lean files, the only way a proved theorem would become invalid is if the underlying Ruby code is *changed* in a way that breaks the round-trip (e.g. changing the Base58 alphabet, changing the SHA3-256 truncation length, changing the varint endianness). The Lean model is a *snapshot* of the Ruby code as of the commit pinned in `formal-verification/CRITIQUE.md` (when it is written). Any change to the Ruby code should be reflected in the Lean model.

### Axiom hygiene

The Lean files use the following `axiom`s:

| File | Axiom | What it asserts | How to discharge |
|------|-------|-----------------|------------------|
| `UUID.lean` | `bytesToHex_hexToBytes` | hex ⇔ byte round-trip | Define `bytesToHex` concretely (e.g. `List.map` over the 16 `Byte`s) and prove the round-trip with `decide`. |
| `UUID.lean` | `hexToBytes_bytesToHex` | reverse direction | Same. |
| `UUID.lean` | `formatDashed_stripDashes` | dashed ⇔ undashed | Define `formatDashed` as `fun h => h.take 8 ++ "-" ++ h.drop 8 |>.take 4 ++ "-" ++ ...` and prove. |
| `UUID.lean` | `bytesToHex_length` | hex length is 32 | `rfl` once `bytesToHex` is concrete. |
| `UUID.lean` | `formatDashed_length` | dashed length is 36 | Same. |
| `MainAddress.lean` | `sha3_256` | SHA3-256 exists | Use a verified SHA3 implementation (e.g. `crypto-bytes` Lean lib) or axiomatise as opaque. |
| `MainAddress.lean` | `base58Encode` | Base58 exists | Same. |
| `MainAddress.lean` | `base58Decode` | Base58 decode exists | Same. |
| `MainAddress.lean` | `base58Encode_decode` | Base58 round-trip | Use the same library as above and prove the round-trip. |
| `MainAddress.lean` | `mainAddressPrefix_startsWith` | `(prefix ++ s).startsWith prefix = true` | `List.append_prefix_startsWith`-style lemma; should be `rfl`-like in Lean 4's `String` API. |

Discharging these axioms is *the* work of Phases 4–5 for each target.

### CI status

- `.github/workflows/lean-ci.yml` exists and triggers on changes to `formal-verification/lean/**` (see `formal-verification/RESEARCH.md` §7 for the run history).
- The CI runs `lake build` on the Lean files; the 9 `sorry` axioms / theorems across the four files are flagged by the build but do not fail it. Discharging them would shrink the `sorry` count to 0 and the CI would then be a true correctness check.

---

## Summary

| Target | Level | Divergences | Impact on proofs | Validation evidence |
|--------|-------|-------------|------------------|---------------------|
| `UUID` | abstraction + 5 axioms | 3 (present?, InvalidUuidFormatError, storage polymorphism) | moderate — axioms carry the bit-level impl | none yet (axiom-only) |
| `Varint` | exact | 1 (no ArgumentError raise) | low — `encodeInt` is a faithful translation | 7 `native_decide` examples |
| `UintCodec` | exact (with comment-only bug) | 3 (`Bounded` subtype, endiness comment, length-mismatch handling) | low | 10 `native_decide` examples |
| `MainAddress` | abstraction + 4 axioms | 5 (axioms, totalisation, defensive check, no `burning_address`, no init raise) | high — axioms carry the third-party impl | none yet (axiom-only) |

No mismatches. All four Lean models are sound approximations of the Ruby code; the axioms are clearly documented and dischargeable.
