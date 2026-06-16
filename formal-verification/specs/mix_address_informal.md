# `MixAddress` — Informal Specification

> 🔬 *Lean Squad — automated formal verification for `baizhiheizi/mixin_bot`.*
>
> Source: `lib/mixin_bot/address.rb` lines 10–157.
> Status: **Phase 2 (Informal Spec)** — drives the Lean 4 formal spec
> in `formal-verification/lean/FVSquad/MixAddress.lean` (to be written).
> This spec is the contract that the Lean model must satisfy.

## 1. Purpose

`MixinBot::MixAddress` is the multi-member ("mix") variant of the Mixin
Network mainnet address. Unlike `MainAddress` (which encodes a single
Ed25519 public key), `MixAddress` encodes an *N-of-M* multisig
configuration: a threshold `T` together with a sorted list of `M`
member addresses (each of which may be either a `UUID` user identifier
or a `XIN`-prefixed `MainAddress`).

`MixAddress` is used in:

- Multi-signature outputs (the on-chain format of an `M-of-N` group
  wallet, where the ghost-key derivation requires the `MixAddress` to
  be pinned in the output).
- `request_or_generate_ghost_keys` (`address.rb:65–83`) — used when
  building a multisig transaction. **This is out of scope for FV** (it
  calls `JOSE::JWA::Ed25519.keypair` and `MixinBot.api.create_safe_keys`,
  which are external).
- `to_safe_recipient` (`address.rb:56–63`) — the JSON shape consumed
  by the Mixin Network Safe API.

A bug in `MixAddress` is *catastrophic*: the on-chain multisig output
that references a `MixAddress` is what users sign against, and a
corrupted address could send funds to a different multisig group
entirely.

## 2. Construction modes

`MixAddress.new` accepts one of three keyword-argument shapes
(`address.rb:21–50`):

| Argument | Meaning | Internal state populated |
|----------|---------|--------------------------|
| `address:` | an already-encoded `MIX`-prefixed string | `decode` is called |
| `payload:` | the raw 3-byte-prefix + member-bytes form (no checksum, no Base58) | `decode` is called |
| `members:` + `threshold:` (optionally `version:`) | a fresh multisig group | `encode` is called |

After construction, `valid?` is called; if it returns `false`, the
constructor raises `ArgumentError, 'invalid address'`. The Ruby `valid?`
check is `address.present? && (uuid_members.present? || xin_members.present?) && threshold.present?`
(`address.rb:52–54`).

## 3. Preconditions

### 3.1 For `encode` (the `members:` + `threshold:` form)

- `members` (when provided) is an `Array` of strings, each either a
  `UUID` (canonical 36-char dashed form) or a `XIN`-prefixed
  `MainAddress`. The constructor partitions them by `start_with?('XIN')`
  into `uuid_members` and `xin_members` (`address.rb:33–40`).
- `uuid_members` and `xin_members` (when provided directly) are both
  `Array`s. Both are sorted alphabetically (`address.rb:42–43`).
- `members.length + xin_members.length` is in `[1, 255]` (the
  256-bound is enforced in `encode` with `raise ArgumentError, 'members length should less than 256'` at `address.rb:88`).
- Threshold validity depends on the membership shape:
  - **UUID-only mix** (`xin_members.empty? && uuid_members.present?`):
    `0 < threshold ≤ member_count`. Otherwise raises
    `ArgumentError, "invalid threshold: …"` (`address.rb:94`).
    Mirrors the Go SDK's `NewUUIDMixAddress`.
  - **XIN-only mix** (`uuid_members.empty? && xin_members.present?`):
    `threshold > 0`; and `member_count ≤ 64`. Otherwise raises
    `ArgumentError, "too many XIN members"` or `"invalid threshold: …"`
    (`address.rb:96–97`). Mirrors the Go SDK's `NewMainnetMixAddress`
    (sparse threshold is allowed; e.g. 1-of-64 storage style).
  - **Mixed UUID+XIN**: `threshold ≤ member_count` (`address.rb:98–100`).
- `version`, if not provided, defaults to `MIX_ADDRESS_VERSION = 2`
  (`address.rb:6, 31`).

### 3.2 For `decode` (the `address:` form)

- `address` is a `String` starting with the literal prefix `MIX`. The
  constructor raises `ArgumentError, 'invalid address'` otherwise
  (`address.rb:122`).
- After stripping the `MIX` prefix and Base58-decoding, the data is at
  least `3 + 16 + 4 = 23` bytes (1-byte version, 1-byte threshold,
  1-byte member count, ≥ 1 UUID-sized member of 16 bytes, 4-byte
  checksum). Shorter data raises
  `ArgumentError, 'invalid address, length invalid'` (`address.rb:126`).
- The 4-byte trailing checksum must equal
  `SHA3_256("MIX" ++ payload)[0..3]`. Otherwise raises
  `ArgumentError, 'invalid address, checksum invalid'` (`address.rb:130`).
- The first byte of the payload must be a valid `Integer` (it always
  is, but the code checks anyway, `address.rb:139`).
- The member count (third byte) must be a valid `Integer` (same
  defensive check, `address.rb:145`).

### 3.3 For `decode` (the `payload:` form)

- `payload` is the raw `prefix + members` form (no checksum, no
  Base58). The constructor computes the checksum, Base58-encodes the
  result, and stores the resulting `address` (`address.rb:131–136`).
  The other `decode` invariants (version, threshold, member count,
  member list) are then applied.

## 4. Postconditions

### 4.1 After `encode` (the `members:` + `threshold:` form)

The object has:

- `version : Integer ∈ {1, 2, …}` (1 is the legacy version, 2 is the
  current one).
- `threshold : Integer ∈ {1, …, member_count}` (subject to the shape
  rules in §3.1).
- `uuid_members : List String` of canonical-dashed UUIDs, sorted.
- `xin_members : List String` of `XIN`-prefixed `MainAddress` strings,
  sorted.
- `payload : String` of length `3 + M * L` where `L` is `16` (UUID) or
  `64` (XIN) depending on the membership shape, and `M = uuid_members.length + xin_members.length`.
- `address : String` of the form `"MIX" ++ Base58(payload ++ checksum[0..3])`
  where `checksum = SHA3_256("MIX" ++ payload)[0..3]`. The length of
  `address` is `3 + ⌈log_58(payload.length + 4) / log_58(256))⌉`
  (approximately, since Base58 does not preserve length).

### 4.2 After `decode` (the `address:` form)

The object has the same fields as in §4.1, recovered from the address:

- `version = payload[0].ord`
- `threshold = payload[1].ord`
- `members_count = payload[2].ord`
- `uuid_members` and `xin_members` are recovered by slicing
  `payload[3...]` into chunks of size `UUID_ADDRESS_LENGTH = 16` (UUID
  form) or `MAIN_ADDRESS_LENGTH = 64` (XIN form). The shape is
  detected by `payload[3...].length == members_count * UUID_ADDRESS_LENGTH`
  (`address.rb:147`).
- The `address` field is the *input* (idempotent: decoding the
  resulting address gives the same address back).

### 4.3 After `decode` (the `payload:` form)

The object has the same fields as in §4.1, *plus* a `payload` field
that is the input. The `address` is computed by checksum + Base58
encoding.

## 5. Round-trip properties

| Property | Statement |
|----------|-----------|
| **encode ∘ decode = id (address)** | For any well-formed `MIX`-prefixed address `a`, `MixAddress.new(members: MixAddress.new(address: a).to_safe_recipient[:members], threshold: MixAddress.new(address: a).threshold).address = a`. (Equivalent: the `members` and `threshold` are recovered correctly, and re-encoding produces the same address.) |
| **decode ∘ encode = id (members)** | For any valid `members:`, `threshold:`, `version:`, `MixAddress.new(address: MixAddress.new(members:, threshold:).address).uuid_members == MixAddress.new(members:, threshold:).uuid_members` (and same for `xin_members`, `threshold`, `version`). |
| **encode ∘ decode = id (payload)** | For any valid `payload:`, `MixAddress.new(address: MixAddress.new(payload: p).address).payload = p` (the payload is recovered). |
| **idempotence of `decode`** | `MixAddress.new(address: a).address = a` for any well-formed `a`. |

All four are the *headline* properties of the codec.

## 6. Invariants

For any state of the object after construction:

- `address.start_with? "MIX"`.
- `version ∈ {1, 2, …}` (a positive integer; the Go SDK uses 1 and 2).
- `threshold > 0`.
- `members_count = uuid_members.length + xin_members.length` *and*
  `members_count > 0` *and* `members_count ≤ 255`.
- `uuid_members` and `xin_members` are *both* sorted (ascending,
  lexicographic).
- `uuid_members` and `xin_members` are *disjoint* in shape (no element
  of `uuid_members` starts with `XIN`; no element of `xin_members`
  doesn't). This is enforced by the partition in `address.rb:33–40`.
- The 4-byte SHA3-256 checksum embedded in `address` equals
  `SHA3_256("MIX" ++ payload)[0..3]`.
- The `payload` length is `3 + members_count * L` where `L` is `16`
  (UUID shape) or `64` (XIN shape) or *both* shapes do not coexist
  (`members` is either all UUID or all XIN, but the *encoding* allows
  mixed: see §10 for an open question).

## 7. Edge cases

- **Empty members** (`uuid_members = []` and `xin_members = []`):
  rejected by `encode` (`address.rb:87`) and by `valid?` (`address.rb:53`).
- **More than 255 members** (or 64 XIN members): rejected by `encode`
  (`address.rb:88, 97`).
- **Threshold of zero** (UUID-only): rejected by `encode` (`address.rb:94`).
- **Threshold of zero** (XIN-only): rejected by `encode` (`address.rb:96`).
- **Threshold greater than members_count** (UUID-only or mixed):
  rejected by `encode` (`address.rb:94, 99`).
- **Non-`MIX` prefix**: rejected by `decode` (`address.rb:122`).
- **Address too short** (< `3 + 16 + 4 = 23` bytes after Base58
  decode): rejected by `decode` (`address.rb:126`).
- **Checksum mismatch**: rejected by `decode` (`address.rb:130`).
- **Address with corrupted payload** (e.g. `version` byte is
  non-`Integer`): the Ruby code's defensive checks (`address.rb:139,
  142, 145`) always pass in practice because `payload[i].ord` is
  always an `Integer`; the defensive code is a no-op.
- **Single-member address** (members_count = 1, threshold = 1): legal.
  This is exactly the form pinned in
  `test_encode_mix_address` (`test/mixin_bot/test_address.rb:14–21`):
  `MIX3QEezkMEfKTnofT28SBMW6MftV3WSRF` (one UUID member).
- **Two-member address with shuffled order** (members_count = 2,
  threshold = 1): legal, and the order should not affect the result
  (the constructor sorts). Pinned in
  `test_members_order_do_not_affect_mix_address`
  (`test/mixin_bot/test_address.rb:30–41`).

## 8. Examples (golden)

The test suite (`test/mixin_bot/test_address.rb`) pins three golden
pairs:

| Members (in input order) | Threshold | Address |
|--------------------------|-----------|---------|
| `[TEST_UID]` | `1` | `MIX3QEezkMEfKTnofT28SBMW6MftV3WSRF` |
| `[TEST_UID, TEST_UID_2]` | `1` | (the address of the sorted two-member group; same as the reverse-order input) |
| `[TEST_UID_2, TEST_UID]` | `1` | (same as above — order-invariant) |

The exact `TEST_UID` and `TEST_UID_2` constants are defined in
`test/test_helper.rb` (a canonical Mixin Network test UUID, and a
second one for the two-member test). The golden fixtures also include
`test/fixtures/golden/mix_address.json` and
`test/fixtures/golden/hash_members.json` for higher-level
correspondence tests.

## 9. Inferred intent (not explicit in code)

- **The `MIX_ADDRESS_PREFIX = 'MIX'` is intentionally a 3-byte ASCII
  prefix** — parallel to `XIN`. The `MIX` letters are not arbitrary;
  they signify "multisig mix" in the Mixin Network's branding.
- **The `version = 2` is the current version**; version 1 is the
  legacy UUID-only format. The Ruby code's default of 2 (`address.rb:31`)
  is what users should get; the constructor accepts version 1 for
  backwards compatibility but always encodes 2 by default.
- **The `payload`-only decode form** (`address.rb:131–136`) is
  internal: it lets a caller who has the raw payload (e.g. read it
  out of a transaction output) construct an `address` without
  re-running Base58 encoding. It is not the user-facing entry point.
- **The shape detection** (`address.rb:147–155`) is a magic
  size-check: `payload[3...].length == members_count * 16` means all
  members are UUIDs (each 16 bytes); otherwise they must all be XIN
  (each 64 bytes). There is no explicit shape tag in the payload.
  This is a documented corner of the on-chain format and is shared
  with the Go SDK.
- **The threshold validity rules are shape-dependent** because the
  on-chain semantics differ: UUID mixes use a strict `T ≤ M` (a real
  multisig), while XIN mixes allow a sparse threshold (a "1-of-64"
  storage-style group, where most members will never be required to
  sign).

## 10. What is explicitly **not** modelled

These are out of scope for the Lean 4 spec and will be documented as
approximations in the Lean file:

- The `request_or_generate_ghost_keys` method
  (`address.rb:65–83`). It calls `JOSE::JWA::Ed25519.keypair` and
  `MixinBot.api.create_safe_keys`, both of which are external. The
  method is *not* part of the codec round-trip.
- The `to_safe_recipient` method (`address.rb:56–63`). It is a JSON
  shape transformation, not a codec.
- The `valid?` method's dependence on `ActiveSupport`'s `present?`
  helper (`address.rb:52–54`). The Lean model will use a pure
  predicate.
- The `ArgumentError` raises inside `encode` and `decode`. The Lean
  model will be total — invalid inputs map to a sentinel / `Option`
  value, not a raise.
- The `Base58.binary_to_base58` / `Base58.base58_to_binary` and
  `SHA3::Digest::SHA3_256.digest` implementations. Both will be
  `axiom`-ed, exactly as in the `MainAddress` spec.
- I/O, file reads, randomness (the `SecureRandom.uuid` call in
  `request_or_generate_ghost_keys`).
- The `ActiveSupport` `args.with_indifferent_access` helper
  (`address.rb:22`).

## 11. Open questions for maintainers

1. **Mixed UUID + XIN members** — the constructor accepts both
   (`address.rb:33–40`), and `encode` does not reject the mixed
   shape, but the *decode* shape detection (`address.rb:147–155`)
   implicitly requires all members to be the same shape (since
   `members_count * UUID_ADDRESS_LENGTH` must match exactly). Is the
   mixed shape a supported on-chain configuration, or is the
   decode-time assumption "all members are the same shape" a hidden
   invariant? **Default plan**: model the encode/decode assuming
   uniform shape (UUID-only or XIN-only), and treat the mixed shape
   as undefined behaviour.
2. **Version 1 vs. 2** — the constructor accepts a `version:`
   keyword (`address.rb:31`) and the Go SDK has version 1. Are
   version-1 addresses still in circulation? Should the Lean model
   enforce `version = 2`? **Default plan**: model the current
   version (2) only; the version is part of the payload, so the
   round-trip is preserved regardless of which version is used.
3. **Sort order** — the constructor sorts `uuid_members` and
   `xin_members` lexicographically (`address.rb:42–43`). Is this
   strictly required for the on-chain format, or is it a
   representation-invariant (the same address, just with the same
   sort applied on both sides)? **Default plan**: model the sort
   as part of `encode` and verify that `decode` produces the same
   sort. The order-invariance property
   (`test_members_order_do_not_affect_mix_address`) is a direct
   consequence.
4. **The `payload`-only `decode` form** — is this used by the SDK
   itself, or only by tests? **Default plan**: include the
   `payload` form in the spec, mirroring the Ruby `decode` code.
5. **The `to_safe_recipient` JSON shape** — should the Lean model
   include a `to_safe_recipient : { members, threshold, mix_address }`
   function as part of the spec? **Default plan**: skip, since it
   is not a codec property.

## 12. Properties to verify in Lean

A non-exhaustive list of properties that the Lean spec should
include. These will be expanded when the Lean file is written.

| Property | Type | Effort | Tractability |
|----------|------|--------|--------------|
| `encode (decode a) = a` for any well-formed `MIX`-prefixed `a` | round-trip | high | needs SHA3/Base58 round-trip + UUID/XIN partition reasoning |
| `decode (encode m) = m` for any valid `(members, threshold)` | round-trip | high | similar |
| `encode m` starts with `"MIX"` | prefix invariant | trivial | `rfl` |
| `encode m` has `version` byte equal to the constructor's `version` | structural | trivial | `rfl` |
| `encode m` has `threshold` byte equal to the constructor's `threshold` | structural | trivial | `rfl` |
| `encode m` has `members_count` byte equal to `uuid_members.length + xin_members.length` | structural | trivial | `rfl` |
| `decode a` rejects non-`MIX` prefix | rejection | trivial | `rfl` |
| `decode a` rejects checksum mismatch | rejection | trivial | depends on SHA3 axiom |
| Sort order preserved: `encode m`'s `uuid_members` and `xin_members` are sorted | sort invariant | low | `List.Pairwise` over `String` |
| Order invariance: `encode (members=[a,b]) = encode (members=[b,a])` | equivalence | medium | sort lemma + length |
| `MixAddress.new(members: [TEST_UID], threshold: 1).address = MIX3QEezkMEfKTnofT28SBMW6MftV3WSRF` | golden test | low | `native_decide` after instantiating SHA3/Base58 |

---

## Last Updated
- **Date**: 2026-06-16 06:30 UTC
- **Commit**: `8026c6d` (main; `MainAddress` Lean spec in PR #97 merged)
