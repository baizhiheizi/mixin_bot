---
name: repo-assist-memory
description: Persistent state for Repo Assist runs on baizhiheizi/mixin_bot
metadata:
  type: project
---

# Repo Assist Memory — baizhiheizi/mixin_bot

## Current state (as of 2026-06-20)

- **Repo activity**: predominantly automated workflows (Agentic Wiki Writer, Repo Assist, doc-updater, threat-detection tracking). Last human contributor commit (an-lee): 2026-05-27. Lean Squad workflow + `formal-verification/` artifacts removed entirely in PR #129.
- **Open issues**: 16 — all automated workflow-tracking outputs from `github-actions[bot]`:
  - #90 `[aw] Detection Runs` — auto-managed threat-detection tracker (do not close)
  - #91 `[aw] Agentic Wiki Writer hit AI credits rate limit` — workflow failure tracker (expires 2026-06-22)
  - #92 `[lean-squad] Research & target identification + Lean CI scaffold` — failed PR creation landed as issue body; Lean Squad now removed → body is obsolete, suggest close
  - #93 `[lean-squad] Formal Verification Status` — Lean Squad status tracker; obsolete after #129
  - #99 `[repo-assist] Monthly Activity 2026-06` — the issue we maintain (updated this run)
  - #106 `[aw] Repo Assist hit AI credits rate limit` — workflow failure tracker (expires 2026-06-24)
  - #107 `[aw] Lean Squad failed` — workflow failure tracker (expires 2026-06-24) — framework no longer relevant but the issue itself will auto-expire
  - #108 `[aw] Agentic Wiki Writer hit AI credits rate limit` — workflow failure tracker (expires 2026-06-24)
  - #110 `[aw] Repo Assist failed` — workflow failure tracker (expires 2026-06-24)
  - #112 `[aw] No-Op Runs` — auto-managed no-op tracker (expires 2026-07-17)
  - #113 `[aw] Lean Squad failed` — workflow failure tracker (expires 2026-06-25)
  - #114 `[repo-assist] 📝 docs: bump stale version references from 2.2.1 to 2.3.0` — PR-as-issue, blocked by protected files (AGENTS.md, CLAUDE.md, README.md). Maintainer needs to apply the patch manually or relax the protected-files list.
  - #115 `[aw] Repo Assist hit AI credits rate limit` — workflow failure tracker (expires 2026-06-25)
  - #116 `[aw] Lean Squad hit AI credits rate limit` — workflow failure tracker (expires 2026-06-25)
  - #118 `[aw] Documentation Updater produced no safe outputs` — workflow failure tracker (expires 2026-06-25)
  - #124 `[aw] Agentic Wiki Writer hit AI credits rate limit` — workflow failure tracker
- **Open PRs**: 0 (test-output #126 merged at 2026-06-20 02:25 UTC; test-chain #123 merged at 2026-06-19 15:30 UTC; test-tip #117 merged at 2026-06-19 02:42 UTC).
- **Repo Assist PRs**: 1 fresh draft, branch `repo-assist/test-legacy-collectible-2026-06-20`, local commit `ee040f7`. PR create returned success but propagation lag means it may not surface in the GitHub API on the first check.
- **Unlabelled issues**: 0
- **Monthly Activity issue**: [issue #99](https://github.com/baizhiheizi/mixin_bot/issues/99) for 2026-06 (active; updated this run).
- **Test coverage progress**: 4/15 API modules now have direct unit tests.
  - `test_tip.rb` (merged in #117) — 14 helpers in `lib/mixin_bot/api/tip.rb`
  - `test_chain.rb` (merged in #123) — 4 helpers + 2 aliases + constant freeze + 2 UUID constants in `lib/mixin_bot/api/chain.rb`
  - `test_output.rb` (merged in #126) — 9 new assertions for `build_threshold_script` in `lib/mixin_bot/api/output.rb`
  - `test_legacy_collectible.rb` (this run, branch `repo-assist/test-legacy-collectible-2026-06-20`) — 14 assertions covering `NFT_ASSET_MIXIN_ID`, `COLLECTIBLE_TRANSACTION_ARGUMENTS`, `nft_memo` round-trip + blank/short-extra errors, `create_collectible_request` action validation (String + Symbol), and `build_collectible_transaction` arg validation + happy path.

## Backlog cursor

- **Task 2 (Issue Comment) cursor**: 0 — all open issues reviewed; no comment-worthy items this run (all 16 are automated workflow outputs from `github-actions[bot]`).
- **Task 3 (Issue Fix) cursor**: 0 — no `bug`/`help wanted`/`good first issue` labelled issues exist.
- **Task 4 (Engineering Investments) cursor**: nothing actionable identified. All Dependabot PRs merged; CI workflows already on supported Ruby versions (3.2/3.3/4.0); gemspec pinned to ranges that work across those versions.
- **Task 5/9 (Testing Improvements) cursor**: 4/15 modules done. Continue the sweep across the remaining untested `lib/mixin_bot/api/` modules: `inscription.rb` (77 lines, `create_collectible_transfer`), `multisig.rb` (58 lines, `create_multisig_raw_tx`), `legacy_user.rb` (51 lines, `upgrade_legacy_user`), `legacy_multisig.rb` (86 lines, mostly HTTP wrappers), `withdraw.rb` (84 lines, HTTP-heavy), `address`, `blaze`, `computer_api`, `deposit`, `fiat`, `network`, `network_asset`, `pin_payload`, `session`, `turn` (mixed HTTP/pure content).

## Decisions / substitutions this run (2026-06-20, 05:24 UTC)

- Selected tasks: 2 (Issue Comment), 4 (Engineering Investments), 5 (Coding Improvements).
- Task 2: skipped comment action — all 16 open issues are automated, not user-facing.
- Task 4: no actionable engineering investment identified. No open Dependabot PRs; no major-version upgrades to apply; CI is already on supported Ruby matrix.
- Task 5: created draft PR `repo-assist/test-legacy-collectible-2026-06-20` (1 new test file, 153 lines, no production-code change). Local `bundle install` blocked by sandboxed environment. Direct module sanity check loaded `lib/mixin_bot/api/legacy_collectible.rb` in isolation and verified 13 of 14 assertions pass; the happy-path `build_collectible_transaction` test needs `MixinBot.configure` (set up by `test_helper.rb` in the real test env). RuboCop with project config reports 0 offenses on the new file.
- Cleaned up Suggested Actions in #99: removed the test-output PR line (now merged as #126); added the new test-legacy-collectible line; added a close-issue line for #93 (Lean Squad formal verification status, now obsolete after #129); replaced the Lean Squad Tier-3 goal with a 2.3.1 release-prep question (since Lean Squad no longer exists). Kept #114, #92 close.

## Forward work candidates (next runs)

- Watch for human contributor activity (low signal at present).
- **Test coverage sweep**: extend the pattern to the next-largest untested modules. Priority order based on line count + ratio of pure helpers to HTTP calls:
  1. `inscription.rb` (77 lines) — `create_collectible_transfer` is pure-ish, but 3 of 4 methods are HTTP wrappers
  2. `multisig.rb` (58 lines) — `create_multisig_raw_tx` is pure-ish (depends on `create_safe_keys` + `build_safe_transaction`)
  3. `legacy_user.rb` (51 lines) — `upgrade_legacy_user` is pure-ish (depends on `client.post`)
  4. `legacy_multisig.rb` (86 lines) — mostly HTTP wrappers, lower yield
  5. `withdraw.rb` (84 lines) — mostly HTTP wrappers, lower yield
- **PR creation propagation lag**: the new test-legacy-collectible PR's `create_pull_request` returned success and wrote patch + bundle files to `/tmp/gh-aw/aw-repo-assist-test-legacy-collectible-2026-06-20.{patch,bundle}`, but the GitHub MCP API did not surface it as an open PR during the run window. If the next run sees the PR visible, treat it normally. If not visible after a longer wait, check the patch file is still on disk and consider `noop` next time.
- **Protected-files PR-push workaround** is now a known limitation: any PR touching `README.md` / `AGENTS.md` / `CLAUDE.md` will land as an issue with a manual `git am` recipe. If a maintainer wants auto-pushed PRs for docs updates, they need to either drop the protection on those files or grant `workflows: write` to the Repo Assist workflow.
- **2.3.1 release preparation** is now a candidate for the next maintainer-driven action: the `sha3` dependency upgrade from PR #84 is still in CHANGELOG `[Unreleased]`, and the Lean Squad removal from #129 is unreleased. A maintainer would need to do a version bump + CHANGELOG restructure + tag push.
- If a 2.3.1 release is wanted, the CHANGELOG `[Unreleased]` still contains the `sha3` dependency upgrade from PR #84 — that's a separate maintainer decision (version bump, CHANGELOG restructure, tag push) and was deliberately kept out of the docs-only version-bump PR.

## Anti-patterns to avoid

- Do not comment on `github-actions[bot]`-generated issues (auto-managed, informational only).
- Do not create PRs duplicating Lean Squad output (the workflow has been removed entirely in #129).
- Do not close auto-managed issues like #90 (the framework manages those).
- Do not bump action versions in the dormant `lean-ci.yml` for the sake of a tiny version consistency — the workflow has been removed in #129.
- Do not re-propose the duplicate-PR investigation (PRs #95 and #96 are closed/merged as of this run).
- Do not bundle the CHANGELOG / version bump for a 2.3.1 release into a docs-only PR — release prep is a maintainer-driven decision and should remain a separate, larger change.
- **Do not attempt another PR touching `README.md`, `AGENTS.md`, or `CLAUDE.md` via `create_pull_request`** until the protected-files workaround is in place — it will reliably land as an issue rather than a PR (see #114), wasting the workflow turn.
- **Do not retry `create_pull_request` more than once for the same content in a single run** — even with `success` return values, the GitHub API can lag. The branch and patch are recoverable; double-creation is harder to clean up.
- Do not add a "Lean Squad Tier 3" goal to #99 going forward — Lean Squad is gone in #129. Use 2.3.1 release-prep as the strategic suggestion instead.
