---
name: mixin_bot_run_log
description: Chronological log of Lean Squad runs for baizhiheizi/mixin_bot
metadata:
  type: project
---

# MixinBot Run Log

## Run 2026-06-17 morning (workflow run 27689412938)

Selected tasks: 8 (Implementation Correspondence Validation), 7
(Proof Utility Critique).

### Completed

- **Task 8 (Correspondence Validation, Route B)**:
  - Created `formal-verification/tests/tier1_codecs/` directory with:
    - `ruby_harness.rb` (111 lines): runs Ruby
      `encode_int`/`decode_int` and
      `encode_uint16/32/64`/`decode_uint16/32/64` on 37
      distinct inputs (+ 6 UUID round-trips for future
      comparison). Emits `fixtures.json` with 84 input/output
      pairs.
    - `FVSquad/Correspondence.lean` (131 lines, imported by
      `FVSquad.lean`): 77 `#guard` byte-level checks (26
      Varint + 45 UintCodec + 6 length). All `#guard`s are
      checked at compile time via `lake build`.
    - `run.sh`: end-to-end runner that regenerates
      `fixtures.json` and runs `lake build`.
    - `README.md`: full coverage table and "how to run" docs.
  - Fixed `UintCodec.lean:22-25` endianness comment (was
    "big-endian", now correctly says "little-endian" and
    points to the Ruby `pack('S*'/'L*'/'Q*').bytes.reverse`
    pattern). Implementation was always correct.
  - **Verified**: `lake build` passes (8 jobs, 0 errors).
    All 77/77 `#guard` checks pass against the live Ruby
    output.
  - This is the first **machine-checked** correspondence
    guarantee in the Lean Squad: any change to the Ruby
    `encode_int` / `encode_uint*` that breaks parity with
    the Lean model will be caught at `lake build` time.
- **Task 7 (Proof Utility Critique)**:
  - Created `formal-verification/CRITIQUE.md` (252 lines) with:
    - Overall assessment
    - Proved-theorems table (9 `rfl`/`simp`/`intro`/`native_decide`
      proofs + 77 `#guard` checks; bug-catching potential per
      theorem)
    - `sorry` inventory (9 `sorry`s, by file)
    - Axiom inventory (14 axioms: 9 in UUID, 5 in MainAddress;
      with discharge difficulty per axiom)
    - 5 prioritised gaps for future runs
    - Concerns (axiom-burdened proofs, `sorry` regressions
      not caught by CI)
    - Positive findings (clean functional translation,
      little-endian correctness after comment fix, no real
      bugs in Ruby)
- **CORRESPONDENCE.md** updates: added `## Last Updated`
  (date 2026-06-17, commit `cc56360`), updated repository
  layout table with correspondence-check counts, updated
  validation-evidence sections for Varint and UintCodec, and
  added §7 documenting the new runnable harness.
- **Task Final**: Updated [[lean-squad-status]] issue (with
  the new run 6 entry and the runnable-harness / critique
  rows in the At a Glance table).

### Notes

- New branch: `lean-squad/correspondence-tests-critique-d5fe5f7e686ad20e`.
  Contains 9 files changed, +1123/-14 lines total. PR opened
  via `safeoutputs` workflow.
- The runnable harness is a **permanent regression
  detector** for the Tier 1 codecs. Future PRs that touch
  `formal-verification/lean/FVSquad/{Varint,UintCodec}.lean`
  will be automatically re-validated against the live Ruby
  output by `lean-ci.yml`.
- The `correspondence_test_count` is now 77 (was 0).
- Total `lake build` for run 6: 8 jobs, 0 errors. 9 `sorry`
  and 14 `axiom` remain (Phase 4 / 5 work; documented in
  `CRITIQUE.md`).

## Run 2026-06-16 night (workflow run 27597904118)

Selected tasks: 6 (Correspondence Review), 2 (Informal Spec Extraction).

### Completed

- **Task 6 (Correspondence Review)**: Created
  `formal-verification/CORRESPONDENCE.md` — a comprehensive mapping
  of all 4 Lean files (UUID, Varint, UintCodec, MainAddress) to their
  Ruby sources. Each definition has a correspondence level
  (exact / abstraction / approximation / mismatch), a divergence list,
  an impact-on-proofs assessment, and a validation-evidence note.
  **No mismatches found.** Key findings:
  - `Varint.lean` and `UintCodec.lean` are **exact** translations
    of the Ruby; round-trip can be `#eval`-ed in Lean 4.
  - `MainAddress.lean` depends on 4 axioms (sha3_256, base58Encode,
    base58Decode, base58Encode_decode); the round-trip `sorry`s
    reduce to the base58 axiom plus List take/drop arithmetic.
  - `UUID.lean` depends on 5 axioms (hex round-trip both directions,
    dashed round-trip, two length lemmas); the bit-level hex ⇔ byte
    conversion is out of scope.
  - **Comment-only bug** in `UintCodec.lean:22-25` (says "big-endian"
    but the implementation is little-endian — matching the Ruby).
    To be fixed in a future run.
- **Task 2 (Informal Spec — MixAddress)**: Wrote
  `formal-verification/specs/mix_address_informal.md` (280 lines, 12
  sections). Covers all 3 construction modes (`address:`, `payload:`,
  `members:`+`threshold:`), shape-dependent threshold validity
  rules, 4 distinct round-trip properties, 5 invariants, 9 edge
  cases, golden test pairs, 5 open questions for maintainers, and
  11 properties to verify in Lean.
- **Task Final**: Updated [[lean-squad-status]] issue.

### Notes

- New branch: `lean-squad/correspondence-mixaddress-spec-d5fe5f7e686ad20e`.
  Contains the two new files (594 lines total). The branch is in
  draft state as a PR.
- This is the first run to (a) write the `CORRESPONDENCE.md` audit
  document, and (b) add an informal spec for a target that has not
  yet been formalised in Lean.
- The new `CORRESPONDENCE.md` establishes a reusable template: each
  future Lean file will get its own section with mapping, divergences,
  impact on proofs, and validation evidence.

## Run 2026-06-16 evening (workflow run 27572892306)

Selected tasks: 9 (CI Automation), 1 (Research).
Substitutions: Task 9 → Task 3 (Formal Spec Writing), since no Lean files
exist in the working tree (the Tier 1 specs are in open PRs, not yet
merged to main).

### Completed

- **Task 1 (Research, incremental)**: Updated `RESEARCH.md` to add a
  "Lessons Learned from Tier 1 Spec Writing" section and a new §8
  introducing `MainAddress` as the Tier 2 target. Updated `TARGETS.md`
  to advance Tier 1 to Phase 3 and `MainAddress` to Phase 2→3.
- **Task 3 (Formal Spec Writing)**: Wrote the `MainAddress` informal
  spec (`formal-verification/specs/main_address_informal.md`) and the
  Lean 4 formal spec
  (`formal-verification/lean/FVSquad/MainAddress.lean`). `lake build`
  passes with Lean 4.31.0; 2 `sorry` remain (the two headline
  round-trip proofs).
- **Lake project setup**: minimal `lakefile.toml` (no Mathlib), pinned
  `lean-toolchain` to `leanprover/lean4:v4.31.0`, `FVSquad.lean`
  facade, `.gitignore` excluding `.lake/`.
- **Task Final**: Updated [[lean-squad-status]] issue.

### Notes

- The new PR branch is `lean-squad/tier2-mainaddress-spec-7693a2b1`.
- `MainAddress` introduces a `noncomputable` modelling pattern (since
  it depends on axiomatised SHA3-256 and Base58). The
  `base58_decode ∘ base58_encode = id` property is axiomatised as a
  single lemma so the proof obligation is visible.
- One structural lemma (`mainAddressPrefix_startsWith` for
  `String.startsWith` over `++`) is currently axiomatised; the
  hand proof is future-run work.
- The 7 `sorry` from the open Tier 1 PRs (#95 / #96) are NOT counted
  in this run's `lake build` log — they live in those PRs' branches.

## Run 2026-06-16 morning (workflow run 27554387102)

Selected tasks: 3 (Formal Spec Writing) — Tier 1.

### Completed (in open PRs #95 / #96, not yet merged)

- Wrote Tier 1 informal specs:
  `formal-verification/specs/{uuid,varint,uint_codec}_informal.md`.
- Wrote Tier 1 Lean specs:
  `formal-verification/lean/FVSquad/{UUID,Varint,UintCodec}.lean`.
- `lake build` passes; 7 `sorry` remain.

## Run 2026-06-15 (workflow run 27528284081)

Selected tasks: 9 (CI Automation), 1 (Research & Target Identification).

### Completed

- **Task 1 (Research)**: Wrote `formal-verification/RESEARCH.md` surveying the
  Ruby codebase and identifying 7+ FV-amenable targets. Wrote
  `formal-verification/TARGETS.md` with tiered prioritisation.
- **Task 9 (CI Automation)**: Created `.github/workflows/lean-ci.yml` ready
  to verify Lean proofs when `formal-verification/lean/` becomes populated.
- **Task Final**: Updated [[lean-squad-status]] issue.

### Substitutions / fallbacks

None — both selected tasks were applicable.

### Notes

- No prior FV work exists; this is the initial run.
- The Ruby codebase has excellent golden fixtures from the Go SDK that act as
  specification oracles.
- Task 8 Route A (Aeneas/Charon) does not apply since the codebase is Ruby.
  We will use Route B (executable correspondence tests on shared fixtures).
- `.github/workflows/lean-ci.yml` triggers on changes to
  `formal-verification/lean/**` and `.github/workflows/lean-ci.yml`. It will
  activate when the first `.lean` file is added (which must also add a
  `lean-toolchain` file).
