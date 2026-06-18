---
name: repo-assist-memory
description: Persistent state for Repo Assist runs on baizhiheizi/mixin_bot
metadata:
  type: project
---

# Repo Assist Memory — baizhiheizi/mixin_bot

## Current state (as of 2026-06-18)

- **Repo activity**: predominantly automated workflows (Lean Squad, Agentic Wiki Writer, Dependabot, doc-updater, threat-detection tracking). Last human contributor commit (an-lee): 2026-05-27.
- **Open issues**: 14 — all automated workflow-tracking outputs from `github-actions[bot]`:
  - #90 `[aw] Detection Runs` — auto-managed threat-detection tracker (do not close)
  - #91 `[aw] Agentic Wiki Writer hit AI credits rate limit` — workflow failure tracker (expires 2026-06-22)
  - #92 `[lean-squad] Research & target identification + Lean CI scaffold` — failed PR creation landed as issue body (the actual PR content is now in #97 and #103)
  - #93 `[lean-squad] Formal Verification Status` — Lean Squad status tracker
  - #99 `[repo-assist] Monthly Activity 2026-06` — the issue we maintain (updated this run)
  - #106 `[aw] Repo Assist hit AI credits rate limit` — workflow failure tracker (expires 2026-06-24)
  - #107 `[aw] Lean Squad failed` — workflow failure tracker (expires 2026-06-24)
  - #108 `[aw] Agentic Wiki Writer hit AI credits rate limit` — workflow failure tracker (expires 2026-06-24)
  - #110 `[aw] Repo Assist failed` — workflow failure tracker (expires 2026-06-24)
  - #112 `[aw] No-Op Runs` — auto-managed no-op tracker (expires 2026-07-17)
  - #113 `[aw] Lean Squad failed` — workflow failure tracker (expires 2026-06-25)
  - #114 `[repo-assist] 📝 docs: bump stale version references from 2.2.1 to 2.3.0` — PR-as-issue, blocked by protected files (AGENTS.md, CLAUDE.md, README.md). Maintainer needs to apply the patch manually or relax the protected-files list.
  - #115 `[aw] Repo Assist hit AI credits rate limit` — workflow failure tracker (expires 2026-06-25)
  - #116 `[aw] Lean Squad hit AI credits rate limit` — workflow failure tracker (expires 2026-06-25)
- **Open PRs**: 0 (the test-tip-bodies PR is in flight server-side; if it lands as issue-as-PR again, the issue will get a new number).
- **Repo Assist PRs**: 1 (test-tip-bodies, branch `repo-assist/test-tip-bodies-2026-06-18`, local commit `0672944`).
- **Unlabelled issues**: 0
- **Monthly Activity issue**: [issue #99](https://github.com/baizhiheizi/mixin_bot/issues/99) for 2026-06 (active; updated this run).
- **Test coverage gap filled this run**: 14 of 15 pure-function helpers in `lib/mixin_bot/api/tip.rb` now have direct unit tests in `test/mixin_bot/api/test_tip.rb`. Captured on branch `repo-assist/test-tip-bodies-2026-06-18`.

## Backlog cursor

- **Task 2 (Issue Comment) cursor**: 0 — all open issues reviewed; no comment-worthy items this run (all 14 are automated workflow outputs from `github-actions[bot]`).
- **Task 3 (Issue Fix) cursor**: 0 — no `bug`/`help wanted`/`good first issue` labelled issues exist.
- **Task 9 (Testing Improvements) cursor**: this run filled the tip.rb coverage gap. Future runs should continue the sweep across the remaining untested `lib/mixin_bot/api/` modules: `chain.rb` (94 lines), `multisig.rb` (58 lines), `legacy_collectible.rb` (139 lines), `inscription.rb` (77 lines), `legacy_user.rb` (51 lines) — most are mixins with both API calls and pure helpers worth covering.

## Decisions / substitutions this run (2026-06-18, 19:01 UTC)

- Selected tasks: 2 (Issue Comment), 3 (Issue Fix), 9 (Testing Improvements).
- Task 3 fell back to Task 2 (no bug/help wanted/good first issue labels in current inventory).
- Task 2: skipped comment action — all 14 open issues are automated, not user-facing.
- Task 9: created draft PR `repo-assist/test-tip-bodies-2026-06-18` (1 new test file, 89 lines, no production-code change). Local test run blocked by sandboxed environment (`bundle install` cannot reach rubygems.org per firewall-blocked workflow-failure issues #107 / #108 / #110 / #112 / #113 / #115 / #116); CI on `main` is unaffected.
- Cleaned up Suggested Actions in #99: re-flagged the version-bump PR as issue **#114** (it landed as an issue because the patch touched workflow-protected files and could not auto-push), added the new test-tip-bodies PR line, preserved the Lean Squad Tier-3 goal and the #92 close suggestion.

## Forward work candidates (next runs)

- Watch for human contributor activity (low signal at present).
- **Test coverage sweep**: extend the `test_tip.rb` pattern to the next-largest untested modules. Priority order based on line count + ratio of pure helpers to HTTP calls:
  1. `legacy_collectible.rb` (139 lines)
  2. `inscription.rb` (77 lines)
  3. `multisig.rb` (58 lines) — has both `create_multisig_raw_tx` (pure-ish, depends on `create_safe_keys` + `build_safe_transaction`) and 4 thin API wrappers.
  4. `legacy_user.rb` (51 lines)
  5. `chain.rb` (94 lines)
- **Protected-files PR-push workaround** is now a known limitation: any PR touching `README.md` / `AGENTS.md` / `CLAUDE.md` will land as an issue with a manual `git am` recipe. If a maintainer wants auto-pushed PRs for docs updates, they need to either drop the protection on those files or grant `workflows: write` to the Repo Assist workflow.
- Lean Squad Tier 3 (`Transaction`, `Nfo`) is the next formal-verification phase per `formal-verification/TARGETS.md`. Per `CRITIQUE.md` the state is now 14 `sorry` + 5 `axiom` across 4 files; 101 byte-level `#guard` correspondence checks live (77 Tier 1 + 24 UUID).
- If a 2.3.1 release is wanted, the CHANGELOG `[Unreleased]` still contains the `sha3` dependency upgrade from PR #84 — that's a separate maintainer decision (version bump, CHANGELOG restructure, tag push) and was deliberately kept out of the docs-only version-bump PR.

## Anti-patterns to avoid

- Do not comment on `github-actions[bot]`-generated issues (auto-managed, informational only).
- Do not create PRs duplicating Lean Squad output (the workflow owns that pipeline).
- Do not close auto-managed issues like #90 (the framework manages those).
- Do not bump action versions in the dormant `lean-ci.yml` for the sake of a tiny version consistency — it's not a real improvement until the workflow runs.
- Do not re-propose the duplicate-PR investigation (PRs #95 and #96 are closed/merged as of this run).
- Do not bundle the CHANGELOG / version bump for a 2.3.1 release into a docs-only PR — release prep is a maintainer-driven decision and should remain a separate, larger change.
- **Do not attempt another PR touching `README.md`, `AGENTS.md`, or `CLAUDE.md` via `create_pull_request`** until the protected-files workaround is in place — it will reliably land as an issue rather than a PR (see #114), wasting the workflow turn.