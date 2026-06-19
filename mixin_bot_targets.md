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

1. `lib/mixin_bot/uuid.rb` — `UUID.unpacked` / `UUID.packed` round-trip. **Phase 4 (Implementation)** (run 7; 4 functional axioms discharged as concrete `def`s; 7 `sorry`, 0 `axiom` remain). **Executable correspondence harness**: 24 `#guard` byte-level checks in `FVSquad/Correspondence.lean` (4 per UUID × 6 fixtures), all pass on live Ruby.
2. `lib/mixin_bot/utils/encoder.rb` — `encode_int` / `decode_int` varint round-trip. **Phase 3** (merged; 2 `sorry` remain). **Executable correspondence harness**: 26 `#guard` byte-level checks in `FVSquad/Correspondence.lean`, all pass on live Ruby.
3. `lib/mixin_bot/utils/encoder.rb` — `encode_uint16/32/64` / `decode_uint16/32/64` round-trip. **Phase 4 (Implementation)** (run 8; **3 `sorry` → 3 proved theorems** via `simp + toByte_val + omega`). **Executable correspondence harness**: 45 `#guard` byte-level checks, all pass. **Endianness comment fixed in run 6** (was "big-endian", now "little-endian").

## Tier 2 (Address formats — golden-tested)

4. `lib/mixin_bot/address.rb` `MainAddress` round-trip + invariants (`XIN` prefix, valid SHA3-256 checksum). **Phase 3** (merged in PR #97, commit `8026c6d`; 2 `sorry`, 5 `axiom` remain). SHA3-256 and Base58 axiomatised. See `formal-verification/CORRESPONDENCE.md` §4 for the full Ruby↔Lean mapping.
5. `lib/mixin_bot/address.rb` `MixAddress` round-trip + invariants (`MIX` prefix, member list + threshold). **Phase 2 (Informal Spec done in run 5; see `formal-verification/specs/mix_address_informal.md`)**. Next: Phase 3 (Lean spec).

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

- **Endianness confirmed**: Both `encode_int` and `encode_uint16/32/64` are *little-endian* in the Ruby code (push low byte first; `encode_uint` reverses the `pack('S*'/'L*'/'Q*')` big-endian output). The Lean models mirror this exactly. **Comment-only bug in `UintCodec.lean:22-25` FIXED in run 6**: was "big-endian", now "little-endian".
- Treat `encode_uint16/32/64` as partial functions with precondition `0 ≤ n < 2^bits`.
- Transaction round-trip scope: only `version3_multi_io.hex` (golden).
- `MainAddress` and `MixAddress` share the SHA3-256 + Base58 axiomatisation; closing the round-trip `sorry`s will require either (a) re-implementing Base58/SHA3-256 in Lean or (b) using a verified-crypto Lean library.

## Correspondence review

`formal-verification/CORRESPONDENCE.md` (run 4, updated in run 6) maps all 4 Lean files to their Ruby sources with correspondence level, divergences, impact on proofs, and validation evidence. **No mismatches found across 4 models.**

**Runnable correspondence harness** (run 6, branch
`lean-squad/correspondence-tests-critique-d5fe5f7e686ad20e`;
extended in run 7, branch
`lean-squad/uuid-concrete-defs-d5fe5f7e686ad20e`):
**101 `#guard` byte-level checks** at
`formal-verification/lean/FVSquad/Correspondence.lean` (77
Tier 1 codec + 24 UUID round-trips) + Ruby harness at
`formal-verification/tests/tier1_codecs/`. **All 101 pass
on `main`.** End-to-end runner: `bash
formal-verification/tests/tier1_codecs/run.sh`. Permanent
regression detector for the Tier 1 codecs **and** the UUID
codec.

## Critique

`formal-verification/CRITIQUE.md` (run 6, updated run 7):
honest assessment of proof utility. **11 `sorry` and 5 `axiom`
remain** (Phase 4 / 5 work). Net unproved items: **23 → 11**
(run 8, with 3 UintCodec round-trips discharged). 5 prioritised gaps: (1) **add Mathlib to
`lakefile.toml`** (closes 5 UUID + 2 MainAddress sorrys); (2)
hand-write Base58 → MainAddress round-trips provable; (3)
prove Varint round-trip; (4) prove UUID round-trips (now possible with Mathlib); (5)
advance MixAddress to Phase 3.

## Conference paper

`formal-verification/paper/paper.tex` + `paper.bib` (run 8,
branch `lean-squad/run-8-paper-d5fe5f7e686ad20e`, commit
`77e82d9`). ACM `sigconf` 11pt, ~10 pages. PDF not compiled
(no `pdflatex` in workflow runner); compile locally with
`pdflatex paper.tex && bibtex paper && pdflatex paper.tex &&
pdflatex paper.tex`.

**Why**: Ruby codebase with golden fixtures from Go SDK = high-quality spec hints.
**How to apply**: Pick the highest-tier unstarted target. Build incrementally.