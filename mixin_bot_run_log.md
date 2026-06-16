---
name: mixin_bot_run_log
description: Chronological log of Lean Squad runs for baizhiheizi/mixin_bot
metadata:
  type: project
---

# MixinBot Run Log

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
