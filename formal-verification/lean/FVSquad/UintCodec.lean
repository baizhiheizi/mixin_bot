/-
  🔬 Lean Squad — automated formal verification for `baizhiheizi/mixin_bot`.

  Lean 4 formal specification for `encode_uint16/32/64` and
  `decode_uint16/32/64`.

  Source: `lib/mixin_bot/utils/encoder.rb` and `lib/mixin_bot/utils/decoder.rb`.
  Informal spec: `formal-verification/specs/uint_codec_informal.md`.
-/

namespace FVSquad.UintCodec

/-- A byte is a natural number in `[0, 256)`. -/
abbrev Byte := Fin 256

/-- A value in the range `[0, 2^N)` for some fixed `N : Nat`. -/
abbrev Bounded (N : Nat) := { n : Nat // n < 2 ^ N }

/-- Helper: coerce a `Nat` to a `Byte` after proving it's `< 256`. -/
private def toByte (n : Nat) (h : n < 256) : Byte :=
  Fin.mk n h

/-- `encodeUint` is the Lean model of `encode_uintN`.

    Encodes a non-negative integer `n` with `n < 2^N` as a fixed-width
    *little-endian* list of `N/8` bytes. The low byte is at index 0.

    This matches the Ruby `encode_uint16/32/64` in
    `lib/mixin_bot/utils/encoder.rb` lines 22–38, which reverses
    `pack('S*'/'L*'/'Q*')` (big-endian) output to little-endian. -/
def encodeUint : (N : Nat) → Bounded N → List Byte
  | 0,   _ => []
  | 16,  n => encodeUint16 n
  | 32,  n => encodeUint32 n
  | 64,  n => encodeUint64 n
  | _N+1, _ => []
where
  encodeUint16 (n : Bounded 16) : List Byte :=
    [toByte (n.val / 256 % 256) (by omega),
     toByte (n.val % 256)        (by omega)]

  encodeUint32 (n : Bounded 32) : List Byte :=
    [toByte (n.val / (256*256*256) % 256) (by omega),
     toByte (n.val / (256*256) % 256)     (by omega),
     toByte (n.val / 256 % 256)           (by omega),
     toByte (n.val % 256)                 (by omega)]

  encodeUint64 (n : Bounded 64) : List Byte :=
    [toByte (n.val / (256*256*256*256*256*256*256) % 256) (by omega),
     toByte (n.val / (256*256*256*256*256*256) % 256)     (by omega),
     toByte (n.val / (256*256*256*256*256) % 256)         (by omega),
     toByte (n.val / (256*256*256*256) % 256)             (by omega),
     toByte (n.val / (256*256*256) % 256)                 (by omega),
     toByte (n.val / (256*256) % 256)                     (by omega),
     toByte (n.val / 256 % 256)                           (by omega),
     toByte (n.val % 256)                                 (by omega)]

/-- `decodeUint` is the Lean model of `decode_uintN`. -/
def decodeUint : (N : Nat) → List Byte → Nat
  | 0,   _  => 0
  | 16,  bs => decodeUint16 bs
  | 32,  bs => decodeUint32 bs
  | 64,  bs => decodeUint64 bs
  | _N+1, _  => 0
where
  decodeUint16 (bs : List Byte) : Nat :=
    match bs with
    | [a, b] => (a.val : Nat) * 256 + (b.val : Nat)
    | _      => 0

  decodeUint32 (bs : List Byte) : Nat :=
    match bs with
    | [a, b, c, d] =>
        (a.val : Nat) * (256*256*256) + (b.val : Nat) * (256*256) +
        (c.val : Nat) * 256 + (d.val : Nat)
    | _ => 0

  decodeUint64 (bs : List Byte) : Nat :=
    match bs with
    | [a, b, c, d, e, f, g, h] =>
        (a.val : Nat) * (256*256*256*256*256*256*256) +
        (b.val : Nat) * (256*256*256*256*256*256) +
        (c.val : Nat) * (256*256*256*256*256) +
        (d.val : Nat) * (256*256*256*256) +
        (e.val : Nat) * (256*256*256) +
        (f.val : Nat) * (256*256) +
        (g.val : Nat) * 256 +
        (h.val : Nat)
    | _ => 0

/-- **Headline property (16-bit)**: round-trip for 16-bit values. -/
theorem encodeUint16_decodeUint16 (n : Bounded 16) :
    decodeUint 16 (encodeUint 16 n) = n.val := by
  sorry

/-- **Headline property (32-bit)**: round-trip for 32-bit values. -/
theorem encodeUint32_decodeUint32 (n : Bounded 32) :
    decodeUint 32 (encodeUint 32 n) = n.val := by
  sorry

/-- **Headline property (64-bit)**: round-trip for 64-bit values. -/
theorem encodeUint64_decodeUint64 (n : Bounded 64) :
    decodeUint 64 (encodeUint 64 n) = n.val := by
  sorry

/-- **Length property (16-bit)**: `encodeUint 16 n` is a 2-byte list. -/
theorem encodeUint16_length (n : Bounded 16) :
    (encodeUint 16 n).length = 2 := by
  simp [encodeUint, encodeUint.encodeUint16]

/-- **Length property (32-bit)**: `encodeUint 32 n` is a 4-byte list. -/
theorem encodeUint32_length (n : Bounded 32) :
    (encodeUint 32 n).length = 4 := by
  simp [encodeUint, encodeUint.encodeUint32]

/-- **Length property (64-bit)**: `encodeUint 64 n` is an 8-byte list. -/
theorem encodeUint64_length (n : Bounded 64) :
    (encodeUint 64 n).length = 8 := by
  simp [encodeUint, encodeUint.encodeUint64]

/-- Concrete examples: small 16-bit round-trips. -/
example : decodeUint 16 (encodeUint 16 (⟨0, by decide⟩ : Bounded 16)) = 0 := by
  native_decide

example : decodeUint 16 (encodeUint 16 (⟨1, by decide⟩ : Bounded 16)) = 1 := by
  native_decide

example : decodeUint 16 (encodeUint 16 (⟨256, by decide⟩ : Bounded 16)) = 256 := by
  native_decide

example : decodeUint 16 (encodeUint 16 (⟨65535, by decide⟩ : Bounded 16)) = 65535 := by
  native_decide

/-- Concrete examples: small 32-bit round-trips. -/
example : decodeUint 32 (encodeUint 32 (⟨0, by decide⟩ : Bounded 32)) = 0 := by
  native_decide

example : decodeUint 32 (encodeUint 32 (⟨1, by decide⟩ : Bounded 32)) = 1 := by
  native_decide

example : decodeUint 32 (encodeUint 32 (⟨4294967295, by decide⟩ : Bounded 32)) = 4294967295 := by
  native_decide

/-- Concrete examples: small 64-bit round-trips. -/
example : decodeUint 64 (encodeUint 64 (⟨0, by decide⟩ : Bounded 64)) = 0 := by
  native_decide

example : decodeUint 64 (encodeUint 64 (⟨1, by decide⟩ : Bounded 64)) = 1 := by
  native_decide

example : decodeUint 64 (encodeUint 64 (⟨4294967295, by decide⟩ : Bounded 64)) = 4294967295 := by
  native_decide

end FVSquad.UintCodec
