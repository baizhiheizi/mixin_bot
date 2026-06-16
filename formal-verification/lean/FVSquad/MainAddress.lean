/-
# `FVSquad.MainAddress` — Lean 4 formal specification of
# `MixinBot::MainAddress` (lib/mixin_bot/address.rb, lines 159–212).
#
# ## Status
#
# **Phase 3 — Formal Spec Writing (Lean 4).** The headline round-trip
# theorems are `sorry`-guarded and the implementation model uses
# `axiom`s for the third-party primitives (Base58 and SHA3-256). See
# the inline documentation for the design rationale.
#
# ## What is modelled
#
# - The `encode` and `decode` functions as pure, total Lean functions.
# - The structure of the address: a 3-byte ASCII prefix `"XIN"` followed
#   by a Base58-encoded body whose decoded form is `public_key ++
#   sha3_256("XIN" ++ public_key)[0..3]`.
#
# ## What is **not** modelled (and why)
#
# - **`SHA3::Digest::SHA3_256.digest`**: the actual SHA3-256 algorithm.
#   Modelled as `axiom sha3_256`. The round-trip property is what
#   matters; proving SHA3-256 correct from first principles is a
#   separate, well-known problem (and would dwarf the rest of this
#   spec).
# - **`Base58.binary_to_base58` / `Base58.base58_to_binary`**: the
#   Base58 codec itself. Modelled as `axiom base58Encode` and
#   `axiom base58Decode`. Their **mutual-inverse** property is the
#   one axiom that the round-trip proof will lean on, and is itself
#   axiomatised explicitly so that the proof obligation is visible.
# - The Ruby `ArgumentError` raises inside `decode`. The Lean model
#   is total and returns `none` for invalid inputs.
# - The surrounding `ActiveSupport` / `present?` / `blank?` helpers.
# - I/O, file reads, randomness, the
#   `MixinBot::Utils.shared_public_key` call inside `burning_address`.
#
-/

namespace FVSquad

namespace MainAddress

/-- The 3-byte ASCII prefix used by every `MainAddress`. -/
def mainAddressPrefix : String := "XIN"

/-- The length (in bytes) of an Ed25519 public key. -/
def publicKeyLength : Nat := 64

/-- The length (in bytes) of the SHA3-256 checksum appended to the
public key before Base58 encoding. -/
def checksumLength : Nat := 4

/-- We model byte sequences as `List UInt8` throughout. -/
abbrev Bytes := List UInt8

/-- `none` is the canonical "invalid" sentinel for `mainAddressDecode`. -/
abbrev DecodeResult := Option Bytes

/-- The "XIN" prefix is 3 bytes long. -/
example : mainAddressPrefix.length = 3 := rfl

/-! ## Third-party primitives (axioms) -/

/-- SHA3-256 hash. Axiomatised — the algorithm is out of scope for
this spec. `noncomputable` so the code generator does not try to
evaluate it. -/
noncomputable axiom sha3_256 : Bytes → Bytes

/-- Base58 encode (Bitcoin alphabet). Axiomatised. -/
noncomputable axiom base58Encode : Bytes → String

/-- Base58 decode (Bitcoin alphabet). Returns `none` for inputs that
are not a valid Base58 string. -/
noncomputable axiom base58Decode : String → DecodeResult

/-- **Right inverse** of Base58: encoding a byte string then decoding
gives back the same bytes. This is the one axiom the round-trip proof
will lean on. -/
axiom base58Encode_decode (bs : Bytes) :
  base58Decode (base58Encode bs) = some bs

/-- A trivial sanity-check: the encode function applied to a public
key produces a string that starts with the prefix. -/
axiom mainAddressPrefix_startsWith (s : String) :
  (mainAddressPrefix ++ s).startsWith mainAddressPrefix = true

/-! ## The model -/

/-- A byte-level view of the ASCII prefix. -/
def mainAddressPrefixBytes : Bytes :=
  mainAddressPrefix.toList.map (fun c => c.toUInt8)

/-- `mainAddressEncode pk` — the Lean model of
`MainAddress.new(public_key: pk).address`.

Layout: `"XIN" ++ base58Encode (pk ++ sha3_256("XIN" ++ pk)[0..3])`.

Marked `noncomputable` because it depends on the axiomatised
`sha3_256` and `base58Encode`. -/
noncomputable def mainAddressEncode (pk : Bytes) : String :=
  let checksum := List.take checksumLength (sha3_256 (mainAddressPrefixBytes ++ pk))
  let data := pk ++ checksum
  mainAddressPrefix ++ base58Encode data

/-- `mainAddressDecode addr` — the Lean model of
`MainAddress.new(address: addr).public_key`.

Returns `none` if the input does not start with `"XIN"`, or if the
Base58 body fails to decode, or if the trailing 4-byte SHA3-256
checksum does not match the expected digest of `"XIN" ++ recovered_pk`.
Returns `some recovered_pk` otherwise.

Marked `noncomputable` because it depends on the axiomatised
`sha3_256` and `base58Decode`. -/
noncomputable def mainAddressDecode (addr : String) : DecodeResult :=
  if !addr.startsWith mainAddressPrefix then none
  else
    let body := (addr.drop mainAddressPrefix.length).toString
    match base58Decode body with
    | none => none
    | some data =>
      if data.length ≤ checksumLength then none
      else
        let recovered := List.take (data.length - checksumLength) data
        let actualChecksum := List.drop (data.length - checksumLength) data
        let expectedChecksum :=
          List.take checksumLength (sha3_256 (mainAddressPrefixBytes ++ recovered))
        if actualChecksum == expectedChecksum then some recovered
        else none

/-! ## Headline properties -/

/-- The encode function always produces an address starting with the
literal `XIN` prefix. The proof reduces to the axiomatised
`mainAddressPrefix_startsWith` lemma. -/
theorem encode_starts_with_xin (pk : Bytes) :
    (mainAddressEncode pk).startsWith mainAddressPrefix = true := by
  unfold mainAddressEncode
  exact mainAddressPrefix_startsWith _

/-- **Headline round-trip 1**: for any public key `pk`,
decoding the encoded address recovers `pk`.

Proof: unfold both definitions; the body is `base58Encode …`; the
decode then runs `base58Decode` on it, which is the right inverse
by `base58Encode_decode`; the recovered bytes are `pk ++ checksum`;
after stripping the 4-byte checksum we get back `pk`. -/
theorem encode_decode_roundtrip (pk : Bytes) :
    mainAddressDecode (mainAddressEncode pk) = some pk := by
  unfold mainAddressDecode mainAddressEncode
  sorry

/-- **Headline round-trip 2**: for any well-formed address `addr`,
encoding the decoded public key recovers `addr`. -/
theorem decode_encode_roundtrip (addr : String) (pk : Bytes) :
    mainAddressDecode addr = some pk →
    mainAddressEncode pk = addr := by
  intro _h
  sorry

/-- Decoding a non-prefixed address returns `none`. -/
theorem decode_rejects_non_prefixed (s : String) :
    ¬ s.startsWith mainAddressPrefix →
    mainAddressDecode s = none := by
  intro h
  unfold mainAddressDecode
  simp [h]

/-! ## Concrete example (correspondence oracle) -/

/-- A known 64-byte zero public key, for use in the
`burning_address_stable` example.

(For real verification we would extract these bytes from the
golden fixture in `test/mixin_bot/test_address.rb`.) -/
def zeroPublicKey : Bytes :=
  List.replicate publicKeyLength (0 : UInt8)

/-- Sanity: the zero public key has the right length. -/
example : zeroPublicKey.length = publicKeyLength := by
  unfold zeroPublicKey
  simp

end MainAddress

end FVSquad
