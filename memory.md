---
name: repo-assist-memory
description: Persistent state for Repo Assist runs on baizhiheizi/mixin_bot
metadata:
  type: project
---

# Repo Assist Memory — baizhiheizi/mixin_bot

## Current state (as of 2026-06-18)

- **Repo activity**: predominantly automated workflows (Lean Squad, Agentic Wiki Writer, Dependabot, doc-updater, threat-detection tracking). Last human contributor commit (an-lee): 2026-05-27.
- **Open issues**: 11 — all automated workflow-tracking outputs from `github-actions[bot]`:
  - #90 `[aw] Detection Runs` — auto-managed threat-detection tracker (do not close)
  - #91 `[aw] Agentic Wiki Writer hit AI credits rate limit` — workflow failure tracker (expires 2026-06-22)
  - #92 `[lean-squad] Research & target identification + Lean CI scaffold` — failed PR creation landed as issue body (the actual PR content is now in #97 and #103)
  - #93 `[lean-squad] Formal Verification Status` — Lean Squad status tracker (updated with run 7 summary)
  - #99 `[repo-assist] Monthly Activity 2026-06` — the issue we maintain
  - #106 `[aw] Repo Assist hit AI credits rate limit` — workflow failure tracker (expires 2026-06-24)
  - #107 `[aw] Lean Squad failed` — workflow failure tracker (expires 2026-06-24)
  - #108 `[aw] Agentic Wiki Writer hit AI credits rate limit` — workflow failure tracker (expires 2026-06-24)
  - #110 `[aw] Repo Assist failed` — workflow failure tracker (expires 2026-06-24)
  - #112 `[aw] No-Op Runs` — auto-managed no-op tracker (expires 2026-07-17)
  - #113 `[aw] Lean Squad failed` — workflow failure tracker (expires 2026-06-25)
- **Open PRs**: 1 — `repo-assist/improve-version-bump-2026-06-18` (draft, created this run; will appear in API after workflow processes the create_pull_request patch).
- **Repo Assist PRs**: 1 (the version-bump PR above; may be merged or closed by maintainer).
- **Unlabelled issues**: 0
- **Monthly Activity issue**: [issue #99](https://github.com/baizhiheizi/mixin_bot/issues/99) for 2026-06 (active; updated this run).
- **Notable version drift fixed this run**: 4 stale `2.2.1` references in `README.md`, `llms.txt`, `AGENTS.md`, `CLAUDE.md` were bumped to `2.3.0` to match `lib/mixin_bot/version.rb`. Captured in PR on branch `repo-assist/improve-version-bump-2026-06-18`.

## Backlog cursor

- **Task 2 (Issue Comment) cursor**: 0 — all open issues reviewed; no comment-worthy items this run (all 11 are automated workflow outputs from `github-actions[bot]`).
- **Task 3 (Issue Fix) cursor**: 0 — no `bug`/`help wanted`/`good first issue` labelled issues exist.
- **Task 5 (Coding Improvements) cursor**: this run found a small docs win (stale version references) and shipped it as a draft PR. Future runs should continue grepping for stale version references, dead comments, and TODO/FIXME markers; current sweep found none beyond the version-bump.

## Decisions / substitutions this run (2026-06-18)

- Selected tasks: 5 (Coding Improvements), 2 (Issue Comment), 4 (Engineering Investments).
- Task 2: skipped comment action — all 11 open issues are automated, not user-facing.
- Task 4: no engineering action — same as previous runs; Dependabot current, CI current, RuboCop tuned.
- Task 5: created draft PR `repo-assist/improve-version-bump-2026-06-18` (4-line docs bump, 4 files, no code change). Local test run blocked by sandboxed environment (`bundle install` cannot reach rubygems.org per firewall-blocked workflow-failure issues); CI on `main` is unaffected.
- Cleaned up Suggested Actions in #99: removed #98 (closed/expired), #104 (closed/expired), #105 (closed/expired) — no longer in the open issue inventory. Also retired the `lean-ci.yml` action-version bump candidate from Future Work since it's already flagged as an anti-pattern (don't bump action versions in dormant workflows).

## Forward work candidates (next runs)

- Watch for human contributor activity (low signal at present).
- Doc-updater limitation: workflow produces documentation patches for `README.md` and `AGENTS.md` but cannot push them (workflow files are "protected" from being modified by workflows). The maintainer needs to apply the patch manually or adjust the workflow's permissions.
- Lean Squad Tier 3 (`Transaction`, `Nfo`) is the next formal-verification phase per `formal-verification/TARGETS.md`. Per `CRITIQUE.md` the state is now 14 `sorry` + 5 `axiom` across 4 files; 101 byte-level `#guard` correspondence checks live (77 Tier 1 + 24 UUID).
- If a 2.3.1 release is wanted, the CHANGELOG `[Unreleased]` still contains the `sha3` dependency upgrade from PR #84 — that's a separate maintainer decision (version bump, CHANGELOG restructure, tag push) and was deliberately kept out of the docs-only version-bump PR.

## Anti-patterns to avoid

- Do not comment on `github-actions[bot]`-generated issues (auto-managed, informational only).
- Do not create PRs duplicating Lean Squad output (the workflow owns that pipeline).
- Do not close auto-managed issues like #90 (the framework manages those).
- Do not bump action versions in the dormant `lean-ci.yml` for the sake of a tiny version consistency — it's not a real improvement until the workflow runs.
- Do not re-propose the duplicate-PR investigation (PRs #95 and #96 are closed/merged as of this run).
- Do not bundle the CHANGELOG / version bump for a 2.3.1 release into a docs-only PR — release prep is a maintainer-driven decision and should remain a separate, larger change.
