---
name: repo-assist-memory
description: Persistent state for Repo Assist runs on baizhiheizi/mixin_bot
metadata:
  type: project
---

# Repo Assist Memory — baizhiheizi/mixin_bot

## Current state (as of 2026-06-19)

- **Repo activity**: predominantly automated workflows (Lean Squad, Agentic Wiki Writer, Dependabot, doc-updater, threat-detection tracking). Last human contributor commit (an-lee): 2026-05-27.
- **Open issues**: 15 — all automated workflow-tracking outputs from `github-actions[bot]`:
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
  - #118 `[aw] Documentation Updater produced no safe outputs` — workflow failure tracker (expires 2026-06-25)
- **Open PRs**: 1 non-Repo-Assist (#122 Lean Squad, UintCodec round-trips + paper). The new test-chain PR from this run was accepted by `create_pull_request` (success response, patch and bundle files on disk) but did not surface via the GitHub MCP read API during the run window — likely an indexing/propagation lag rather than a creation failure. Branch and commit (`4f866d7`) are intact locally.
- **Repo Assist PRs**: 2 (1 merged: #117 test-tip-bodies; 1 fresh: branch `repo-assist/test-chain-2026-06-19`, local commit `4f866d7`).
- **Unlabelled issues**: 0
- **Monthly Activity issue**: [issue #99](https://github.com/baizhiheizi/mixin_bot/issues/99) for 2026-06 (active; updated this run).
- **Test coverage gap filled this run**: 2 of 15 pure-helper API modules now have direct unit tests. `test_tip.rb` (merged in #117) covers 14 helpers in `lib/mixin_bot/api/tip.rb`. `test_chain.rb` (this run) covers 4 helpers + 2 aliases + constant freeze + 2 UUID constants in `lib/mixin_bot/api/chain.rb`. Captured on branch `repo-assist/test-chain-2026-06-19`.

## Backlog cursor

- **Task 2 (Issue Comment) cursor**: 0 — all open issues reviewed; no comment-worthy items this run (all 15 are automated workflow outputs from `github-actions[bot]`).
- **Task 3 (Issue Fix) cursor**: 0 — no `bug`/`help wanted`/`good first issue` labelled issues exist.
- **Task 5/9 (Testing Improvements) cursor**: 2/15 modules done. Continue the sweep across the remaining untested `lib/mixin_bot/api/` modules: `legacy_collectible.rb` (139 lines), `inscription.rb` (77 lines), `multisig.rb` (58 lines), `legacy_user.rb` (51 lines), `chain.rb` (now covered), `tip.rb` (now covered), plus `address`, `blaze`, `computer_api`, `deposit`, `fiat`, `network`, `network_asset`, `pin_payload`, `session`, `turn` (mixed HTTP/pure content).

## Decisions / substitutions this run (2026-06-19, 06:13 UTC)

- Selected tasks: 3 (Issue Fix), 2 (Issue Comment), 5 (Coding Improvements).
- Task 3 fell back to Task 2 (no bug/help wanted/good first issue labels in current inventory).
- Task 2: skipped comment action — all 15 open issues are automated, not user-facing.
- Task 5: created draft PR `repo-assist/test-chain-2026-06-19` (1 new test file, 69 lines, no production-code change). Local test run blocked by sandboxed environment (gem install blocked, no internet to rubygems.org). Direct module sanity check loaded `lib/mixin_bot/api/chain.rb` in isolation and verified all 13 assertions pass. RuboCop with default config reports 0 offenses on the new file.
- Cleaned up Suggested Actions in #99: replaced the test-tip PR line (now merged as #117) with the new test-chain PR line; preserved #114 (version-bump PR-as-issue), #92 close suggestion, Lean Squad Tier-3 goal.

## Forward work candidates (next runs)

- Watch for human contributor activity (low signal at present).
- **Test coverage sweep**: extend the pattern to the next-largest untested modules. Priority order based on line count + ratio of pure helpers to HTTP calls:
  1. `legacy_collectible.rb` (139 lines) — `build_collectible_transaction` + `nft_memo` are pure-ish, plus COLLECTIBLE_TRANSACTION_ARGUMENTS validation
  2. `inscription.rb` (77 lines)
  3. `multisig.rb` (58 lines) — `create_multisig_raw_tx` is pure-ish (depends on `create_safe_keys` + `build_safe_transaction`)
  4. `legacy_user.rb` (51 lines) — `upgrade_legacy_user` is pure-ish (depends on `client.post`)
  5. `blaze.rb` (144 lines) — mostly HTTP wrappers, lower yield
- **PR creation propagation lag**: the new test-chain PR's `create_pull_request` returned success and wrote patch + bundle files to `/tmp/gh-aw/aw-repo-assist-test-chain-2026-06-19.{patch,bundle}`, but the GitHub MCP API did not surface it as an open PR during the run window. If the next run sees the PR visible, treat it normally. If not visible after a longer wait, check the patch file is still on disk and consider `noop` next time.
- **Protected-files PR-push workaround** is now a known limitation: any PR touching `README.md` / `AGENTS.md` / `CLAUDE.md` will land as an issue with a manual `git am` recipe. If a maintainer wants auto-pushed PRs for docs updates, they need to either drop the protection on those files or grant `workflows: write` to the Repo Assist workflow.
- Lean Squad Tier 3 (`Transaction`, `Nfo`) is the next formal-verification phase per `formal-verification/TARGETS.md`. Per `CRITIQUE.md` the state is now 11 `sorry` + 5 `axiom` across 4 files (UintCodec reduced from 3 to 0 in PR #122); 101 byte-level `#guard` correspondence checks live (45 UintCodec + 24 UUID + 32 other).
- If a 2.3.1 release is wanted, the CHANGELOG `[Unreleased]` still contains the `sha3` dependency upgrade from PR #84 — that's a separate maintainer decision (version bump, CHANGELOG restructure, tag push) and was deliberately kept out of the docs-only version-bump PR.

## Anti-patterns to avoid

- Do not comment on `github-actions[bot]`-generated issues (auto-managed, informational only).
- Do not create PRs duplicating Lean Squad output (the workflow owns that pipeline).
- Do not close auto-managed issues like #90 (the framework manages those).
- Do not bump action versions in the dormant `lean-ci.yml` for the sake of a tiny version consistency — it's not a real improvement until the workflow runs.
- Do not re-propose the duplicate-PR investigation (PRs #95 and #96 are closed/merged as of this run).
- Do not bundle the CHANGELOG / version bump for a 2.3.1 release into a docs-only PR — release prep is a maintainer-driven decision and should remain a separate, larger change.
- **Do not attempt another PR touching `README.md`, `AGENTS.md`, or `CLAUDE.md` via `create_pull_request`** until the protected-files workaround is in place — it will reliably land as an issue rather than a PR (see #114), wasting the workflow turn.
- **Do not retry `create_pull_request` more than once for the same content in a single run** — even with `success` return values, the GitHub API can lag. The branch and patch are recoverable; double-creation is harder to clean up.
