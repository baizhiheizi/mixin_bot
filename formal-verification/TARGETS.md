# Formal Verification Targets — MixinBot

> 🔬 *Lean Squad — automated formal verification for `baizhiheizi/mixin_bot`.*

**Status**: Initial target list defined. Phase 1 targets ready for spec extraction.

## Convention

Each target row contains:

- **Phase**: current progress (1=research, 2=informal spec, 3=Lean spec, 4=Lean impl, 5=proofs)
- **Property**: the headline property we want to prove
- **Effort**: rough proof engineering effort (low/medium/high)
- **Value**: bug-catching potential (low/medium/high)

## Targets

### Tier 1 — Foundation (small, high tractability, used everywhere)

| Target | File(s) | Phase | Property | Effort | Value |
|--------|---------|-------|----------|--------|-------|
| `UUID` round-trip | `lib/mixin_bot/uuid.rb` | 1 | `packed ∘ unpacked = id` and `unpacked ∘ packed = id` (on valid inputs) | low | high |
| Varint integer codec | `lib/mixin_bot/utils/encoder.rb` (`encode_int`), `lib/mixin_bot/utils/decoder.rb` (`decode_int`) | 1 | `decode_int (encode_int n) = n` for non-negative `n` | low | high |
| Fixed-width uint codec | same files (`encode_uint16/32/64`, `decode_uint16/32/64`) | 1 | round-trip for `0 ≤ n < 2^bits`; output length is exact `bits/8` | low | high |

### Tier 2 — Address formats (security-sensitive, golden-tested)

| Target | File(s) | Phase | Property | Effort | Value |
|--------|---------|-------|----------|--------|-------|
| `MainAddress` round-trip + invariants | `lib/mixin_bot/address.rb` (`MainAddress`) | 1 | `MainAddress.new(public_key:).address` then `MainAddress.new(address:).public_key = original`; address starts with `XIN`, valid base58, valid SHA3-256 checksum | medium | high |
| `MixAddress` round-trip + invariants | `lib/mixin_bot/address.rb` (`MixAddress`) | 1 | round-trip for valid member lists; address starts with `MIX`; members + threshold + version preserved; `XIN`/UUID members separated correctly | medium | high |

### Tier 3 — Larger formats (builds on Tiers 1+2)

| Target | File(s) | Phase | Property | Effort | Value |
|--------|---------|-------|----------|--------|-------|
| `Transaction` round-trip | `lib/mixin_bot/transaction/encoder.rb`, `decoder.rb` | 1 | `decode ∘ encode = id` on the golden hex fixture; magic/version/asset/inputs/outputs/extra/signatures preserved | high | high |
| `Nfo` (NFT memo) round-trip | `lib/mixin_bot/nfo.rb` | 1 | `decode ∘ encode = id`; mask bit-encoding invariant; UUID packing preserved | medium | medium |

### Tier 4 — Stretch goals

| Target | File(s) | Phase | Property | Effort | Value |
|--------|---------|-------|----------|--------|-------|
| `Invoice` round-trip | `lib/mixin_bot/invoice.rb` | 1 | `decode ∘ encode = id` for two-entry invoice golden fixture | medium | medium |
| `access_token` JWT structure | `lib/mixin_bot/utils/crypto.rb` | 1 | JWT header/payload structure preserved through signing; sig hash matches expected | high | medium |
| Address sort-order invariant | `lib/mixin_bot/address.rb` (`MixinAddress` constructor) | 1 | members list is sorted by construction | low | low |

## Phasing Plan

- **Run 1 (this run)**: Phase 1 — produce RESEARCH.md (done), TARGETS.md (this
  file). Set up CI scaffolding.
- **Run 2**: Tier 1 informal specs → Lean specs → impl → proofs.
- **Run 3+**: Tier 2.
- **Run 4+**: Tier 3.

The phasing is heuristic; the squad adapts based on prior-run findings and
critique feedback.

## Source / Sink Files Map

| Lean file (planned) | Ruby source | Notes |
|---------------------|-------------|-------|
| `FVSquad/UUID.lean` | `lib/mixin_bot/uuid.rb` | Hex ↔ raw ↔ dashed-UUID bijection |
| `FVSquad/Varint.lean` | `lib/mixin_bot/utils/encoder.rb` (`encode_int`, `decode_int`) | Little-endian varint |
| `FVSquad/UintCodec.lean` | `lib/mixin_bot/utils/encoder.rb` (`encode_uint16/32/64`) | Big-endian fixed-width |
| `FVSquad/MainAddress.lean` | `lib/mixin_bot/address.rb` (`MainAddress`) | XIN-prefixed |
| `FVSquad/MixAddress.lean` | `lib/mixin_bot/address.rb` (`MixAddress`) | MIX-prefixed, multi-member |
| `FVSquad/Transaction.lean` | `lib/mixin_bot/transaction/{encoder,decoder}.rb` | Golden fixture |
| `FVSquad/Nfo.lean` | `lib/mixin_bot/nfo.rb` | NFT memo encoding |

---

## Last Updated
- **Date**: 2026-06-15 06:38 UTC
- **Commit**: `<pending — to be filled when PR is opened>`
