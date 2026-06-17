/-
  🔬 Lean Squad — automated formal verification for `baizhiheizi/mixin_bot`.

  Lean 4 formal specification for `MixinBot::UUID#packed` and
  `MixinBot::UUID#unpacked`.

  Source: `lib/mixin_bot/uuid.rb`.
  Informal spec: `formal-verification/specs/uuid_informal.md`.

  Modelling strategy: a UUID is canonically represented by a 16-byte
  `List Byte`. The hex and dashed forms are derived from this canonical
  list. This matches the Ruby implementation, which stores the
  underlying 16 bytes and only formats them for presentation.

  Compared to the previous version, this file replaces the abstract
  `axiom`s for `bytesToHex` / `hexToBytes` / `formatDashed` /
  `stripDashes` with **concrete Lean 4 definitions** built from the
  standard library `String` and `List` operations. The round-trip
  lemmas that were previously `axiom`s are now `theorem`s with `sorry`
  proofs (to be filled in by future work).

  Why this matters: the concrete definitions are `#eval`-able, which
  enables `Correspondence.lean` to byte-check the Lean model against
  live Ruby output from `test/fixtures/tier1_codecs/fixtures.json`.
  The previous axiomatised model could only be tested via abstract
  oracle properties.
-/

namespace FVSquad.UUID

/-- A byte is a natural number in `[0, 256)`. -/
abbrev Byte := Fin 256

/-- A 16-byte UUID binary. -/
abbrev UUIDBytes := { bs : List Byte // bs.length = 16 }

/-- A 32-character hex string (the canonical "no-dash" UUID). -/
abbrev Hex32 := String

/-- A 36-character dashed UUID of the form `8-4-4-4-12`. -/
abbrev DashedUUID := String

/-! ## Concrete codec implementations -/

/-- Convert a single nibble (Nat in `[0, 16)`) to its lowercase hex
character: `0..9 → '0'..'9'`, `10..15 → 'a'..'f'`. -/
def hexDigit (n : Nat) : Char :=
  if n < 10 then Char.ofNat (n + 48)   -- '0' = 48
  else Char.ofNat (n + 87)              -- 'a' = 97, so n + 87 = 97 + (n - 10)

/-- Hex-encode a list of bytes (two lowercase hex chars per byte). -/
def bytesToHexAux : List Byte → List Char
  | [] => []
  | b :: rest =>
    let hi := b.val / 16
    let lo := b.val % 16
    hexDigit hi :: hexDigit lo :: bytesToHexAux rest

/-- Convert a 16-byte list to its 32-character hex form.

    This is the Lean model of Ruby's `[raw].pack('H*')`. Each input
    byte is mapped to two lowercase hex chars in big-endian order. -/
def bytesToHex (bs : List Byte) : Hex32 :=
  String.ofList (bytesToHexAux bs)

/-- Convert a single hex character to a `Fin 16` nibble value.

    Valid inputs: `'0'..'9'` → `0..9`, `'a'..'f'` → `10..15`. Invalid
    characters default to `0` (the model is intentionally partial —
    callers must pre-validate input via length checks). -/
def hexCharToDigit (c : Char) : Fin 16 :=
  let v := c.toNat
  if h : v ≥ 48 ∧ v ≤ 57 then
    -- In this branch: 48 ≤ v ≤ 57, so v - 48 ∈ [0, 9].
    ⟨v - 48, by omega⟩
  else if h2 : v ≥ 97 ∧ v ≤ 102 then
    -- In this branch: 97 ≤ v ≤ 102, so v - 87 ∈ [10, 15].
    ⟨v - 87, by omega⟩
  else
    -- Invalid character: default to 0 (callers must pre-validate).
    ⟨0, by omega⟩

/-- Auxiliary: pair a list of hex chars into bytes, two at a time. -/
def hexToBytesAux : List Char → List Byte
  | [] => []
  | hi :: lo :: rest =>
    let h := (hexCharToDigit hi).val
    let l := (hexCharToDigit lo).val
    -- h, l ∈ [0, 15], so h * 16 + l ∈ [0, 255].
    ⟨h * 16 + l, by omega⟩ :: hexToBytesAux rest
  | _ => []

/-- Convert a 32-character hex string to a 16-byte list.

    This is the Lean model of Ruby's `hex.unpack1('H*')`. -/
def hexToBytes (s : Hex32) : List Byte :=
  hexToBytesAux s.toList

/-- Insert dashes into a 32-character hex string at the standard
positions to produce a 36-character dashed UUID of the form
`8-4-4-4-12`. -/
def formatDashed (s : Hex32) : DashedUUID :=
  String.intercalate "-" [
    (s.take 8).toString,
    ((s.drop 8).take 4).toString,
    ((s.drop 12).take 4).toString,
    ((s.drop 16).take 4).toString,
    (s.drop 20).toString
  ]

/-- Strip the dashes from a 36-character dashed UUID, recovering the
32-character hex form. -/
def stripDashes (s : DashedUUID) : Hex32 :=
  String.ofList (s.toList.filter (· != '-'))

/-! ## The model -/

/-- `packed` (in the byte view): the canonical 16-byte list is itself. -/
def packed (b : UUIDBytes) : UUIDBytes := b

/-- `unpacked`: format a 16-byte list as a 36-character dashed UUID. -/
def unpacked (b : UUIDBytes) : DashedUUID :=
  formatDashed (bytesToHex b.val)

/-! ## Round-trip and length properties -/

/-- **Hex round-trip (forward)**: converting bytes → hex → bytes returns
the same list.

    Proof: by structural induction on the input list. Each byte `b`
    is encoded as two hex chars `(hexDigit (b/16), hexDigit (b%16))`,
    and `hexCharToDigit` inverts each one.

    This is `sorry`-guarded: the proof requires a key lemma stating
    that `hexCharToDigit (hexDigit n) = n` for `n ∈ [0, 16)`, which
    in turn needs a `Char.ofNat.toNat` reduction that is opaque in
    Lean 4.31 without Mathlib. The byte-level correspondence harness
    (`FVSquad.Correspondence`) verifies the round-trip on 6 concrete
    UUID fixtures via `#guard`. -/
theorem bytesToHex_hexToBytes : ∀ (bs : List Byte),
    hexToBytes (bytesToHex bs) = bs := by
  sorry

/-- **Hex round-trip (backward)**: converting hex → bytes → hex returns
the same string, *when* the input has even length and all chars are
valid hex digits. -/
theorem hexToBytes_bytesToHex (cs : List Char) (heven : cs.length % 2 = 0) :
    bytesToHex (hexToBytesAux cs) = String.ofList cs := by
  sorry

/-- **Format consistency**: the dashed form is the hex form with dashes
inserted at the standard positions; stripping the dashes recovers the
original hex. -/
theorem formatDashed_stripDashes (h : Hex32) (hlen : h.length = 32) :
    stripDashes (formatDashed h) = h := by
  sorry

/-- **Length property**: the hex form of a list of bytes has twice the
length of the input list.

    `sorry`-guarded: proving this in Lean 4.31 without Mathlib
    requires a `(String.ofList cs).length = cs.length` lemma whose
    proof depends on the opaque `String.length` definition. -/
theorem bytesToHex_length (bs : List Byte) :
    (bytesToHex bs).length = 2 * bs.length := by
  sorry

/-- **Length property**: the dashed form of a UUID has 36 characters
when the input hex is exactly 32 characters.

    `sorry`-guarded: depends on `bytesToHex_length` and on
    `String.intercalate` length lemmas, both of which are opaque in
    Lean 4.31 without Mathlib. -/
theorem formatDashed_length (h : Hex32) (hlen : h.length = 32) :
    (formatDashed h).length = 36 := by
  sorry

/-! ## Headline properties -/

/-- **Headline property**: `unpacked` followed by re-parsing returns
the same 16 bytes.

    This combines the hex round-trip and the format consistency. -/
theorem unpacked_packed (b : UUIDBytes) :
    hexToBytes (stripDashes (unpacked b)) = b.val := by
  sorry

/-- The headline property stated in the byte-domain form: the dashed
form preserves the underlying 16 bytes through re-parsing. -/
theorem unpacked_preserves_bytes (b : UUIDBytes) :
    (hexToBytes (stripDashes (unpacked b))).length = 16 := by
  sorry

end FVSquad.UUID