---
name: repo-assist-memory
description: Persistent state for Repo Assist runs on baizhiheizi/mixin_bot
metadata:
  type: project
---

# Repo Assist Memory — baizhiheizi/mixin_bot

## Current state (as of 2026-06-16)

- **Repo activity**: predominantly automated workflows (Lean Squad, Agentic Wiki Writer, Dependabot, threat-detection tracking). Last human contributor commit (an-lee): 2026-05-27.
- **Open issues**: 4 — all automated workflow-tracking outputs from `github-actions[bot]`:
  - #90 `[aw] Detection Runs` — auto-managed threat-detection tracker (do not close)
  - #91 `[aw] Agentic Wiki Writer hit AI credits rate limit` — workflow failure tracker (expires 2026-06-22)
  - #92 `[lean-squad] Research & target identification + Lean CI scaffold` — failed PR creation landed as issue body (the actual PR content is now in #95/#96)
  - #93 `[lean-squad] Formal Verification Status` — Lean Squad status tracker
- **Open PRs**: 2 — both Lean Squad Tier 1 specs, **apparent duplicates**:
  - #95 `lean-squad/tier1-lean-specs-184bfc9497ccffa3`
  - #96 `lean-squad/tier1-lean-specs-6142770b550b6c22` — looks like a re-attempt of the same push. Recommend closing one.
- **Repo Assist PRs**: 0
- **Unlabelled issues**: 0
- **Monthly Activity issue**: created for 2026-06 ([link](https://github.com/baizhiheizi/mixin_bot/issues))

## Backlog cursor

- **Task 2 (Issue Comment) cursor**: 0 — all open issues reviewed; no comment-worthy items this run (all are automated workflow outputs).
- **Task 3 (Issue Fix) cursor**: 0 — no `bug`/`help wanted`/`good first issue` labelled issues exist.

## Decisions / substitutions this run

- Task 3 → Task 2 fallback (no fixable issues)
- Task 2: skipped comment action — all open issues are automated, not user-facing (per "When in doubt, do nothing" guideline)

## Forward work candidates (next runs)

- Watch for human contributor activity (low signal at present).
- PR #96 vs #95 duplication — already flagged in Monthly Activity suggested actions.
- Lean Squad Tier 2 (`MainAddress`, `MixAddress`) is the next formal-verification phase per `formal-verification/TARGETS.md`.
- Engineering investments: minor RuboCop config drift, CLI polish.

## Anti-patterns to avoid

- Do not comment on `github-actions[bot]`-generated issues (auto-managed, informational only).
- Do not create PRs duplicating Lean Squad output (the workflow owns that pipeline).
- Do not close auto-managed issues like #90 (the framework manages those).