---
name: mixin_bot_targets
description: Prioritised list of formal verification targets for baizhiheizi/mixin_bot (Ruby gem) — files, properties, phases
metadata:
  type: project
---

# MixinBot FV Targets

**Repository**: baizhiheizi/mixin_bot (Ruby gem v2.2.1)
**Tool**: Lean 4 (Ruby codebase → no Aeneas, use Route B for correspondence)

## Tier 1 (Foundation, do first)

1. `lib/mixin_bot/uuid.rb` — `UUID.unpacked` / `UUID.packed` round-trip. Phase 1.
2. `lib/mixin_bot/utils/encoder.rb` — `encode_int` / `decode_int` varint round-trip. Phase 1.
3. `lib/mixin_bot/utils/encoder.rb` — `encode_uint16/32/64` / `decode_uint16/32/64` round-trip. Phase 1.

## Tier 2 (Address formats — golden-tested)

4. `lib/mixin_bot/address.rb` `MainAddress` round-trip + invariants (`XIN` prefix, valid SHA3-256 checksum). Phase 1.
5. `lib/mixin_bot/address.rb` `MixAddress` round-trip + invariants (`MIX` prefix, member list + threshold). Phase 1.

## Tier 3 (Larger formats — depends on T1+T2)

6. `lib/mixin_bot/transaction/{encoder,decoder}.rb` round-trip (golden fixture `test/fixtures/transactions/version3_multi_io.hex`). Phase 1.
7. `lib/mixin_bot/nfo.rb` (NFT memo) round-trip. Phase 1.

## Tier 4 (Stretch)

8. `lib/mixin_bot/invoice.rb` round-trip. Phase 1.
9. `lib/mixin_bot/utils/crypto.rb` `access_token` JWT structure. Phase 1.

## Golden fixtures available

- `test/fixtures/golden/invoice.json`
- `test/fixtures/golden/mix_address.json`
- `test/fixtures/golden/hash_members.json`
- `test/fixtures/golden/safe_register_hashes.json`
- `test/fixtures/transactions/version3_multi_io.hex`

These provide byte-for-byte oracle for parity with the Go SDK.

## Open modelling decisions

- Mirror little-endian for `encode_int` (current impl) vs normalised big-endian — default: mirror.
- Treat `encode_uint16/32/64` as partial functions with precondition `0 ≤ n < 2^bits`.
- Transaction round-trip scope: only `version3_multi_io.hex` (golden).

**Why**: Ruby codebase with golden fixtures from Go SDK = high-quality spec hints.
**How to apply**: Pick the highest-tier unstarted target. Build incrementally.
