# Formal Verification Targets — MixinBot

> 🔬 *Lean Squad — automated formal verification for `baizhiheizi/mixin_bot`.*

**Status**: Both Tier 1 codecs (Varint and UintCodec) now at **Implementation
phase** with 0 `sorry` (round-trip proofs closed). UUID is also at
Implementation phase with 7 `sorry` (blocked on `String.ofList` /
`String.length` opacity without Mathlib). MainAddress is at Lean Spec phase
(2 `sorry` + 5 `axiom`). **9 `sorry` and 5 `axiom` remain across 4 Lean files**.
**101 byte-level `#guard` checks** confirm Ruby↔Lean agreement on all
Tier 1 codecs + UUID. **Recommended next step: add Mathlib to `lakefile.toml`**,
which would close 7 of 9 remaining `sorry`s in under 200 LoC.

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
| `UUID` round-trip | `lib/mixin_bot/uuid.rb` | 4 (Implementation; 7 `sorry`, 0 `axiom`) | `packed ∘ unpacked = id` and `unpacked ∘ packed = id` (on valid inputs) | low | high |
| Varint integer codec | `lib/mixin_bot/utils/encoder.rb` (`encode_int`), `lib/mixin_bot/utils/decoder.rb` (`decode_int`) | **4 (Implementation; 0 `sorry`, 0 `axiom`)** ✅ | `decode_int (encode_int n) = n` for non-negative `n` | low | high |
| Fixed-width uint codec | same files (`encode_uint16/32/64`, `decode_uint16/32/64`) | **4 (Implementation; 0 `sorry`, 0 `axiom`)** ✅ | round-trip for `0 ≤ n < 2^bits`; output length is exact `bits/8` | low | high |

### Tier 2 — Address formats (security-sensitive, golden-tested)

| Target | File(s) | Phase | Property | Effort | Value |
|--------|---------|-------|----------|--------|-------|
| `MainAddress` round-trip + invariants | `lib/mixin_bot/address.rb` (`MainAddress`) | 3 (Lean spec; 2 `sorry`, 5 `axiom` remain) | `MainAddress.new(public_key:).address` then `MainAddress.new(address:).public_key = original`; address starts with `XIN`, valid base58, valid SHA3-256 checksum | medium | high |
| `MixAddress` round-trip + invariants | `lib/mixin_bot/address.rb` (`MixAddress`) | 2 (Informal spec done in run 5; see `formal-verification/specs/mix_address_informal.md`) | round-trip for valid member lists; address starts with `MIX`; members + threshold + version preserved; `XIN`/UUID members separated correctly | medium | high |

### Tier 3 — Larger formats (builds on Tiers 1+2)

| Target | File(s) | Phase | Property | Effort | Value |
|--------|---------|-------|----------|--------|-------|
| `Transaction` round-trip | `lib/mixin_bot/transaction/encoder.rb`, `decoder.rb` | 1 (Phase 1 research done; see `RESEARCH.md` §4) | `decode ∘ encode = id` on the golden hex fixture; magic/version/asset/inputs/outputs/extra/signatures preserved | high | high |
| `Nfo` (NFT memo) round-trip | `lib/mixin_bot/nfo.rb` | 1 | `decode ∘ encode = id`; mask bit-encoding invariant; UUID packing preserved | medium | medium |

### Tier 4 — Stretch goals

| Target | File(s) | Phase | Property | Effort | Value |
|--------|---------|-------|----------|--------|-------|
| `Invoice` round-trip | `lib/mixin_bot/invoice.rb` | 1 | `decode ∘ encode = id` for two-entry invoice golden fixture | medium | medium |
| `access_token` JWT structure | `lib/mixin_bot/utils/crypto.rb` | 1 | JWT header/payload structure preserved through signing; sig hash matches expected | high | medium |
| Address sort-order invariant | `lib/mixin_bot/address.rb` (`MixinAddress` constructor) | 1 | members list is sorted by construction | low | low |

## Phasing Plan

- **Run 1 (2026-06-15)**: Phase 1 — produce RESEARCH.md, TARGETS.md, CI scaffold (PR #94, merged).
- **Run 2 (2026-06-16 morning)**: Tier 1 informal specs + Lean specs (PRs #95 / #96, merged). 7 `sorry` remain.
- **Run 3 (2026-06-16 evening)**: Tier 2 starts. `MainAddress` informal spec + Lean spec (2 `sorry` remain).
- **Run 4–5**: CORRESPONDENCE.md (4 targets) + MixAddress informal spec; correspondence harness scaffolded (PRs #103, #109).
- **Run 6**: 77 byte-level `#guard` checks (Tier 1 codecs) + CRITIQUE.md initial pass.
- **Run 7**: UUID advances to Implementation phase — 4 functional axioms discharged, 24 new UUID `#guard` checks (77 → 101). 9 fewer axioms, 5 new sorrys.
- **Run 8**: Fixed-width uint codec advances to Implementation phase (3 `sorry` → 3 proved theorems via `simp + toByte_val + omega`). Conference paper drafted.
- **Run 9**: Varint codec advances to Implementation phase (2 `sorry` → 2 proved theorems via `Nat.strongRecOn` + `Nat.div_add_mod`). 11 → 9 `sorry` across all files.
- **Run 10 (this run)**: RESEARCH.md §10–11 added (lessons learned + recommended next steps from CRITIQUE feedback). CORRESPONDENCE.md updated for run 9 state.
- **Run 11+**: Add Mathlib to `lakefile.toml` (closes 7 UUID `sorry`s); extend `#guard` harness to MainAddress (golden fixtures in `test_address.rb`); advance MixAddress to Phase 3 (Lean spec). Tier 3 `Transaction` Phase 1 research.

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
- **Date**: 2026-06-19 (current run)
- **Commit**: `5afe7f9` (post-run-9; PR #125 merged — Varint codec
  Implementation phase; both Tier 1 codecs now `sorry`-free)
- **Run**: 10 — Task 1 (Tier 1 codec completion reflected; §10 lessons + §11
  recommendations) + Task 6 (CORRESPONDENCE.md updated for run 9)
