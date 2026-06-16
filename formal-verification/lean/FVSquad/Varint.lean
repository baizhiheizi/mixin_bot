/-
  🔬 Lean Squad — automated formal verification for `baizhiheizi/mixin_bot`.

  Lean 4 formal specification for `MixinBot::Utils::Encoder.encode_int` and
  `MixinBot::Utils::Decoder.decode_int`.

  Source: `lib/mixin_bot/utils/encoder.rb` (encode_int) and
          `lib/mixin_bot/utils/decoder.rb` (decode_int).
  Informal spec: `formal-verification/specs/varint_informal.md`.
-/

namespace FVSquad.Varint

/-- A byte is a natural number in `[0, 256)`. -/
abbrev Byte := Fin 256

/-- `encodeInt` is the Lean model of `MixinBot::Utils::Encoder.encode_int`.

    It encodes a non-negative integer as a big-endian list of bytes.
    - `encodeInt 0 = [0]`
    - For `n > 0`, the list is the standard minimal big-endian encoding. -/
def encodeInt : Nat → List Byte
  | 0     => [0]
  | n + 1 => encodeIntHelper (n + 1) []
where
  /-- Internal helper: builds the list least-significant-byte first. -/
  encodeIntHelper : Nat → List Byte → List Byte
  | 0,     acc => acc
  | k + 1, acc => encodeIntHelper ((k + 1) / 256) ((Fin.mk ((k + 1) % 256) (by omega)) :: acc)

/-- `decodeInt` is the Lean model of `MixinBot::Utils::Decoder.decode_int`.

    It interprets a list of bytes as a big-endian unsigned integer. -/
def decodeInt : List Byte → Nat
  | []        => 0
  | b :: rest => (b.val : Nat) * 256 ^ rest.length + decodeInt rest

/-- **Headline property**: `decodeInt` is a left inverse of `encodeInt`. -/
theorem encodeInt_decodeInt (n : Nat) : decodeInt (encodeInt n) = n := by
  sorry

/-- `encodeInt 0` is exactly `[0]`. -/
theorem encodeInt_zero : encodeInt 0 = [0] := by
  rfl

/-- `encodeInt 0` has length 1. -/
theorem encodeInt_zero_length : (encodeInt 0).length = 1 := by
  simp [encodeInt]

/-- The empty list decodes to 0. -/
theorem decodeInt_nil : decodeInt [] = 0 := by
  rfl

/-- A list of two bytes `[lo, hi]` decodes to `lo * 256 + hi`. -/
theorem decodeInt_two_bytes (lo hi : Byte) :
    decodeInt [lo, hi] = (lo.val : Nat) * 256 + (hi.val : Nat) := by
  simp [decodeInt, Nat.pow_succ]

/-- Concrete example: round-trip for 0. -/
example : decodeInt (encodeInt 0) = 0 := by
  native_decide

/-- Concrete example: round-trip for 1. -/
example : decodeInt (encodeInt 1) = 1 := by
  native_decide

/-- Concrete example: round-trip for 127. -/
example : decodeInt (encodeInt 127) = 127 := by
  native_decide

/-- Concrete example: round-trip for 128 (uses two bytes). -/
example : decodeInt (encodeInt 128) = 128 := by
  native_decide

/-- Concrete example: round-trip for 255. -/
example : decodeInt (encodeInt 255) = 255 := by
  native_decide

/-- Concrete example: round-trip for 256 (uses two bytes). -/
example : decodeInt (encodeInt 256) = 256 := by
  native_decide

/-- Concrete example: round-trip for 65535 (uses two bytes). -/
example : decodeInt (encodeInt 65535) = 65535 := by
  native_decide

/-- A key building block for the round-trip proof: `decodeInt` of
    a list formed by `encodeIntHelper` satisfies a useful identity. -/
theorem decodeInt_encodeIntHelper (k : Nat) (acc : List Byte) :
    decodeInt (encodeInt.encodeIntHelper k acc) =
      k * 256 ^ acc.length + decodeInt acc := by
  sorry

end FVSquad.Varint
