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

  Note: the hex ⇔ byte conversion and the dashed-formatting are stated
  as abstract operations whose implementations are out of scope for
  this spec. The key properties — that the canonical 16 bytes are
  preserved through format conversions — are stated as theorems with
  `sorry` proofs to be filled in once the underlying conversion
  functions are defined.
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

/-- Abstract: convert a 16-byte list to its 32-character hex form.

    This is the Lean model of Ruby's `[raw].pack('H*')` /
    `raw.unpack1('H*')`. The implementation is out of scope for this
    spec; the spec captures the *behaviour* (round-trip) rather than
    the bit-level conversion. -/
axiom bytesToHex : List Byte → Hex32

/-- Abstract: convert a 32-character hex string to a 16-byte list.

    Inverse of `bytesToHex` on valid inputs. -/
axiom hexToBytes : Hex32 → List Byte

/-- Abstract: format a 32-character hex string as a 36-character
    dashed UUID (groups of 8-4-4-4-12 separated by `-`).

    Models Ruby's `format('%<first>s-%<second>s-...', ...)` call. -/
noncomputable axiom formatDashed : Hex32 → DashedUUID

/-- Abstract: strip dashes from a 36-character dashed UUID.

    Models Ruby's `hex.gsub('-', '')`. -/
noncomputable axiom stripDashes : DashedUUID → Hex32

/-- `packed` (in the byte view): the canonical 16-byte list is itself. -/
def packed (b : UUIDBytes) : UUIDBytes := b

/-- `unpacked`: format a 16-byte list as a 36-character dashed UUID. -/
noncomputable def unpacked (b : UUIDBytes) : DashedUUID :=
  formatDashed (bytesToHex b.val)

/-- **Hex round-trip**: converting bytes → hex → bytes returns the
    same list. -/
axiom bytesToHex_hexToBytes (bs : List Byte) (h : bs.length = 16) :
    hexToBytes (bytesToHex bs) = bs

/-- **Hex round-trip**: converting hex → bytes → hex returns the
    same string (only guaranteed for hex strings that are valid
    byte encodings). -/
axiom hexToBytes_bytesToHex (h : Hex32) :
    bytesToHex (hexToBytes h) = h

/-- **Format consistency**: the dashed form is the hex form with
    dashes inserted at the standard positions. Stripping the dashes
    recovers the original hex. -/
axiom formatDashed_stripDashes (h : Hex32) :
    stripDashes (formatDashed h) = h

/-- **Length property**: the hex form of a 16-byte list is 32 chars. -/
axiom bytesToHex_length (b : UUIDBytes) :
    (bytesToHex b.val).length = 32

/-- **Length property**: the dashed form of a UUID is 36 chars. -/
axiom formatDashed_length (h : Hex32) (hlen : h.length = 32) :
    (formatDashed h).length = 36

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
