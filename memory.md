---
name: repo-assist-memory
description: Persistent state for Repo Assist runs on baizhiheizi/mixin_bot
metadata:
  type: project
---

# Repo Assist Memory — baizhiheizi/mixin_bot

## Current state (as of 2026-06-20 15:18 UTC)

- **Repo activity**: predominantly automated workflows (Agentic Wiki Writer, Repo Assist, doc-updater, threat-detection tracking). Last human contributor commit (an-lee): 2026-05-27. Lean Squad workflow + `formal-verification/` artifacts removed entirely in PR #129.
- **Open issues**: 17 — all automated workflow-tracking outputs from `github-actions[bot]`. (Issue #132 `[aw] Repo Assist hit AI credits rate limit` is new since the prior run; will auto-expire.)
- **Open PRs**: 2 — #131 (test-legacy-collectible, from prior run, awaiting CI) and the new PR from this run (`repo-assist/fix-rubocop-variable-number-2026-06-20`). PR-create API often returns success before the PR is visible; check patch files in `/tmp/gh-aw/aw-repo-assist-*.patch` if the GitHub MCP API doesn't surface a PR.
- **CRITICAL — `main` CI is currently RED**: every push to `main` and every PR has been failing RuboCop since the rubocop 1.87.0 → 1.88.0 bump (PR #120, 2026-06-19). The failing offense is `Naming/VariableNumber: Use normalcase for method name numbers.` at `test/mixin_bot/api/test_output.rb:48` on the method `test_build_threshold_script_255`. **Fix PR opened this run** (`repo-assist/fix-rubocop-variable-number-2026-06-20`, 1-line rename → `test_build_threshold_script_for_max_byte`). Once that merges, `main` will be green again and #131 will be unblocked.
- **Unlabelled issues**: 0
- **Monthly Activity issue**: [issue #99](https://github.com/baizhiheizi/mixin_bot/issues/99) for 2026-06 (active; updated this run).
- **Test coverage progress**: 4 merged + 1 awaiting CI + 1 bug-fix pending. Module coverage at `lib/mixin_bot/api/`:
  - `test_tip.rb` (merged in #117)
  - `test_chain.rb` (merged in #123)
  - `test_output.rb` (merged in #126)
  - `test_legacy_collectible.rb` (PR #131, awaiting CI)

## Backlog cursor

- **Task 2 (Issue Comment) cursor**: 0 — all open issues reviewed; no comment-worthy items this run (all 17 are automated workflow outputs from `github-actions[bot]`).
- **Task 3 (Issue Fix) cursor**: 0 — addressed this run via the RuboCop fix PR.
- **Task 4 (Engineering Investments) cursor**: nothing actionable identified. All Dependabot PRs merged; CI workflows already on supported Ruby versions (3.2/3.3/4.0); gemspec pinned to ranges that work across those versions.
- **Task 5/9 (Testing Improvements) cursor**: 4/15 modules merged + 1 awaiting CI. Continue the sweep across the remaining untested `lib/mixin_bot/api/` modules: `inscription.rb` (77 lines, `create_collectible_transfer`), `multisig.rb` (58 lines, `create_multisig_raw_tx`), `legacy_user.rb` (51 lines, `upgrade_legacy_user`), `legacy_multisig.rb` (86 lines, mostly HTTP wrappers), `withdraw.rb` (84 lines, HTTP-heavy), `address`, `blaze`, `computer_api`, `deposit`, `fiat`, `network`, `network_asset`, `pin_payload`, `session`, `turn` (mixed HTTP/pure content).
- **Task 8 (Performance Improvements) cursor**: noted `lib/mixin_bot/transaction/encoder.rb` `bytes += X` opportunity (70 sites). Not implemented — too large for a single-pass fix; needs separate PR with benchmarks.

## Decisions / substitutions this run (2026-06-20, 15:18 UTC)

- Selected tasks: 3 (Issue Fix), 2 (Issue Comment), 8 (Performance).
- Task 3: **fixed the broken `main` CI**. Root cause: RuboCop 1.88.0 (PR #120) changed the default `Naming/VariableNumber` style for method names from `snake_case` to `normalcase`. The one offending line was `test_build_threshold_script_255` in `test/mixin_bot/api/test_output.rb`. Fixed by renaming to `test_build_threshold_script_for_max_byte` to match the descriptive pattern of neighbouring tests. Branch: `repo-assist/fix-rubocop-variable-number-2026-06-20`. Verified locally with rubocop 1.88.0 (the version pinned in `Gemfile.lock`): pre-fix 1 offense, post-fix 0 offenses across 151 files. RuboCop-rake plugin is unavailable in the sandbox so I ran with a copy of `.rubocop.yml` minus the `plugins: rubocop-rake` line; the project config preserves the same exclusions (`Naming/AccessorMethodName` on `computer_api.rb`, `Style/OneClassPerFile` on `cli.rb`, `Naming/PredicateMethod` on `monitor.rb`).
- Task 2: skipped comment action — all 17 open issues are automated, not user-facing.
- Task 8: no clearly beneficial, low-risk improvement identified this run. Encoder.rb `bytes += X` pattern is a real opportunity but requires a separate PR with benchmarks rather than a sweeping refactor in a single run.
- Cleaned up Suggested Actions in #99: replaced the single-PR `repo-assist/test-legacy-collectible-2026-06-20` line with two distinct entries (the new RuboCop fix PR, and #131 which is now a separate open PR); added a "Future Work" note about the encoder.rb `bytes += X` opportunity and why it was deferred.

## Forward work candidates (next runs)

- Watch for human contributor activity (low signal at present).
- **Test coverage sweep**: extend the pattern to the next-largest untested modules. Priority order based on line count + ratio of pure helpers to HTTP calls:
  1. `inscription.rb` (77 lines) — `create_collectible_transfer` is pure-ish, but 3 of 4 methods are HTTP wrappers
  2. `multisig.rb` (58 lines) — `create_multisig_raw_tx` is pure-ish (depends on `create_safe_keys` + `build_safe_transaction`)
  3. `legacy_user.rb` (51 lines) — `upgrade_legacy_user` is pure-ish (depends on `client.post`)
  4. `legacy_multisig.rb` (86 lines) — mostly HTTP wrappers, lower yield
  5. `withdraw.rb` (84 lines) — mostly HTTP wrappers, lower yield
- **RuboCop fix PR visibility**: the new `repo-assist/fix-rubocop-variable-number-2026-06-20` PR's `create_pull_request` returned success and wrote patch + bundle files to `/tmp/gh-aw/aw-repo-assist-fix-rubocop-variable-number-2026-06-20.{patch,bundle}`, but the GitHub MCP API did not surface it as an open PR during the run window (same propagation-lag pattern as last run's #131). Next run should verify the PR is visible at `https://github.com/baizhiheizi/mixin_bot/pulls` and update Suggested Actions accordingly.
- **CI unblocking chain**: once the RuboCop fix PR merges, every other open PR (notably #131) becomes eligible to pass CI on the next push. This is the highest-impact follow-up for the next run.
- **Performance follow-up**: `lib/mixin_bot/transaction/encoder.rb` has 70 `bytes += X` sites; converting to `bytes.concat(X)` / `bytes << x` would be a measurable speedup. The diff is too large for a single PR; needs a separate, focused PR with benchmarks showing the gain.
- **PR creation propagation lag**: keep noting that the GitHub MCP API can lag behind `create_pull_request` returning success; the patch files on disk are the source of truth until the API catches up.
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
- **Do not attempt to revert or "fix up" the existing `test_build_threshold_script_255` naming in any way other than the canonical rename to `test_build_threshold_script_for_max_byte`** — the latter is what unblocks CI. Trying to keep the `_255` suffix and silence the cop with a `Naming/VariableNumber: EnforcedStyle: snake_case` config would introduce 84 new offenses on the codebase's `var1` / `var2` style local variable names.