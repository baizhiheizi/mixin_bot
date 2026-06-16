# `MainAddress` — Informal Specification

> 🔬 *Lean Squad — automated formal verification for `baizhiheizi/mixin_bot`.*
>
> Source: `lib/mixin_bot/address.rb` lines 159–212.
> Status: **Phase 2 (Informal Spec)** — drives the Lean 4 formal spec
> in `formal-verification/lean/FVSquad/MainAddress.lean`.

## 1. Purpose

`MixinBot::MainAddress` is a tiny two-method codec for an Ed25519 public
key:

- `MainAddress.new(public_key: <64-byte string>).address` — produces a
  human-readable, copy-pasteable "mainnet address" string.
- `MainAddress.new(address: <XIN-prefixed string>).public_key` — recovers
  the original 64-byte public key from the address.

The address is the user-facing identifier used in all Mixin Network mainnet
operations (transfers, withdrawals, multisig ghosts). The 64 bytes that
come out of `public_key` are what get committed to on-chain transaction
outputs. A bug in this codec is *catastrophic*: a user could send funds to
a corrupted address that is not theirs, and those funds are unrecoverable.

## 2. Preconditions

- `public_key` (when constructing for encoding) MUST be exactly 64 bytes
  (the Ed25519 public-key size). The Ruby code does not check this; the
  Lean model will treat it as a precondition of the partial function
  `mainAddressEncode`.
- `address` (when constructing for decoding) MUST be a non-empty `String`
  starting with the literal prefix `"XIN"`. The Ruby code raises
  `ArgumentError, 'invalid address'` otherwise; the Lean model captures
  the rejection (well-formedness) as a property rather than as control
  flow.

## 3. Postconditions (decode)

Given a well-formed address `a` (`a.start_with? "XIN"` and the
Base58-decoded data parses to `public_key ++ checksum` with the
correct SHA3-256 checksum over `"XIN" ++ public_key`):

- `MainAddress.new(address: a).public_key` returns the original 64-byte
  public key.
- `MainAddress.new(address: a).address` returns `a` (idempotent).

## 4. Postconditions (encode)

Given a 64-byte public key `pk`:

- `MainAddress.new(public_key: pk).address` returns a string `a` such
  that:
  1. `a.start_with? "XIN"`.
  2. The Base58-decoded body of `a` (after the prefix) is
     `pk ++ checksum` where `checksum = SHA3_256 ("XIN" ++ pk)[0..3]`
     (first 4 bytes of the SHA3-256 digest).
  3. The total length of `a` is `3 + ⌈log_58 (2^(64*8 + 32))⌉ ≈ 68` —
     i.e. `3 + 47 = 50` characters for a typical 64-byte key
     (Bitcoin-style Base58 alphabet). This length is constant for
     valid 64-byte inputs because the data length is fixed.

## 5. Round-trip properties

| Property | Statement |
|----------|-----------|
| **decode ∘ encode = id** | For any 64-byte public key `pk`, `MainAddress.new(address: MainAddress.new(public_key: pk).address).public_key = pk`. |
| **encode ∘ decode = id** | For any well-formed address `a`, `MainAddress.new(public_key: MainAddress.new(address: a).public_key).address = a`. |

Both are the *headline* properties of the codec.

## 6. Invariants

For any state of the object after construction:

- `address` is non-empty and starts with `"XIN"`.
- `public_key` is exactly 64 bytes.
- The relationship between `address` and `public_key` is consistent:
  the SHA3-256 checksum in `address` matches `SHA3_256("XIN" ++ public_key)`.

## 7. Edge cases

- **Empty `public_key`**: undefined behaviour in Ruby (Base58 of empty
  data is a single `"1"`, but the checksum will not match). The Lean
  model excludes this case via its precondition.
- **`public_key` shorter than 64 bytes**: undefined behaviour. Excluded.
- **`public_key` longer than 64 bytes**: undefined behaviour. Excluded.
- **`address` lacking `"XIN"` prefix**: `decode` raises `ArgumentError`.
  The Lean model captures this as a *rejection property* (the function
  is total but maps a non-prefixed string to a sentinel / partial
  value).
- **`address` with corrupted checksum**: `decode` raises `ArgumentError`.
  Captured as a property over the SHA3-256 of the recovered `public_key`.
- **All-zero `public_key`**: legal input, must produce a deterministic
  address (this is exactly what `MainAddress.burning_address` is built
  from). The Lean spec includes a `burning_address_stable` theorem
  pinning the address of a known zero public key to a concrete string.

## 8. Examples (golden)

The test suite (`test/mixin_bot/test_address.rb`) pins two golden pairs:

| Public key (base64-urlsafe) | Address |
|----------------------------|---------|
| `EKRPniKZqVHyj-fq2HrdcQe1rsBVV9xKQKphpW18lds` | `XIN8L6RQuLGR92XLJpN9YeXermg5jAqLQbZnD8DAdovAg1hmB2FP` |

This pair is the oracle against which the Lean model is checked.

## 9. Inferred intent (not explicit in code)

- The `MAIN_ADDRESS_PREFIX = 'XIN'` constant is intentionally a 3-byte
  ASCII prefix — it is what the human eye scans for. Any address without
  this prefix should be rejected outright.
- The `MAIN_ADDRESS_LENGTH = 64` constant refers to the *raw public-key*
  length in bytes, not the address length. It is used by `MixAddress`
  to slice member lists.
- The choice of **first 4 bytes** of the SHA3-256 digest as the
  checksum is a deliberate space-vs-detection tradeoff: 4 bytes give
  a ~32-bit checksum, which is a 1-in-4-billion random-detection rate,
  considered acceptable for a clipboard-pasted address (a typo almost
  always changes more than 4 bits).
- The Bitcoin-style Base58 alphabet (which excludes `0`, `O`, `I`, `l`)
  is chosen to be copy-paste safe. This is the *only* Base58 mode the
  Ruby code supports.

## 10. What is explicitly **not** modelled

These are out of scope for the Lean 4 spec and are documented as
approximations in the Lean file:

- The `ArgumentError` *raising* behaviour of the Ruby `decode`. The Lean
  model is total — invalid inputs map to a `none` / sentinel value.
- The `MixinBot::Utils.shared_public_key` call inside
  `MainAddress.burning_address`. The Lean model directly takes a
  64-byte public key.
- The Ruby `Base58.binary_to_base58` / `Base58.base58_to_binary`
  implementations. The Lean model uses `axiom` for these.
- The Ruby `SHA3::Digest::SHA3_256.digest` implementation. The Lean
  model uses `axiom` for this.
- I/O, file reads, network calls, randomness.
- The `ActiveSupport` `present?` / `blank?` helpers (used in
  `MixAddress`, not in `MainAddress`).

## 11. Open questions for maintainers

1. **The Ruby `encode` does not validate `public_key.length == 64`**.
   Should the Lean model include a runtime check (a `decide`-closed
   example) that confirms the Ruby behaviour for 32-byte, 128-byte, and
   64-byte inputs? Default: include 64-byte example only.
2. **Should the Lean spec also model `MainAddress.burning_address`'s
   dependency on `MixinBot::Utils.shared_public_key`?** The latter is
   outside the FV scope. Default: skip.
3. **The `checksum` length is 4 bytes** — this is the only place in
   the codebase where SHA3-256 is truncated. Maintainers: confirm this
   is intentional and not a copy-paste error from a 2-byte version of
   this code. (The Go SDK also uses 4 bytes, so the intent is clear,
   but the spec calls it out explicitly.)

---

## Last Updated
- **Date**: 2026-06-16 00:38 UTC
- **Commit**: `84bac72` (origin/main; PRs #95 / #96 carry the Tier 1 specs)
