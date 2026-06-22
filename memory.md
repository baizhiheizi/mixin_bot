---
name: repo-assist-memory
description: Persistent state for Repo Assist runs on baizhiheizi/mixin_bot
metadata:
  type: project
---

# Repo Assist Memory — baizhiheizi/mixin_bot

## Current state (as of 2026-06-22 07:30 UTC)

- **Repo activity**: predominantly automated workflows (Agentic Wiki Writer, Repo Assist, doc-updater, threat-detection tracking). Last human contributor commit (an-lee): 2026-05-27. Lean Squad workflow + `formal-verification/` artifacts removed entirely in PR #129.
- **CI is GREEN again**: PR #133 (`test_build_threshold_script_255` → `test_build_threshold_script_for_max_byte` rename) merged in commit `4a95f97`. PR #131 (legacy_collectible tests) also merged in commit `2091e40`. The RuboCop-on-`main` red that has been blocking every other PR since 2026-06-19 is resolved.
- **Open issues**: 20 — all automated workflow-tracking outputs from `github-actions[bot]` plus the Monthly Activity issue (#99). New since the prior run: #137 (docs-updater for 2026-06-21; same `CHANGELOG.md`-protected-file pattern as #134).
- **Open PRs**: 0 repo-assist PRs visible via the GitHub MCP API. The new `repo-assist/perf-encoder-bytes-concat-2026-06-22` PR was created with `create_pull_request` returning success; patch at `/tmp/gh-aw/aw-repo-assist-perf-encoder-bytes-concat-2026-06-22.patch`. The prior run's `repo-assist/test-inscription-2026-06-21` PR also never propagated — the test-inscription work is still open and is a candidate for re-implementation in a future run.
- **Unlabelled issues**: 0
- **Monthly Activity issue**: [issue #99](https://github.com/baizhiheizi/mixin_bot/issues/99) for 2026-06 (active; updated this run).
- **Test coverage progress**: 4 merged + 0 awaiting. Module coverage at `lib/mixin_bot/api/`:
  - `test_tip.rb` (merged in #117)
  - `test_chain.rb` (merged in #123)
  - `test_output.rb` (merged in #126)
  - `test_legacy_collectible.rb` (merged in #131)
  - `test_inscription.rb` (NOT YET MERGED — the prior run's `repo-assist/test-inscription-2026-06-21` branch was created but never reached `main`)

## Backlog cursor

- **Task 2 (Issue Comment) cursor**: 0 — all open issues reviewed; no comment-worthy items this run (all 20 are automated workflow outputs or repo-assist/docs-updater issues landing as issues due to the protected-files limitation).
- **Task 3 (Issue Fix) cursor**: 0 — nothing to fix; the previously-blocking RuboCop CI is now green, and the test-coverage sweep continues under Task 5/9.
- **Task 4 (Engineering Investments) cursor**: nothing actionable identified. All Dependabot PRs merged; CI workflows already on supported Ruby versions (3.2/3.3/4.0); gemspec pinned to ranges that work across those versions.
- **Task 5/9 (Testing Improvements) cursor**: 4/15 modules merged. Continue the sweep across the remaining untested `lib/mixin_bot/api/` modules: `multisig.rb` (58 lines, `create_multisig_raw_tx`), `legacy_user.rb` (51 lines, `upgrade_legacy_user`), `legacy_multisig.rb` (86 lines, mostly HTTP wrappers), `withdraw.rb` (84 lines, HTTP-heavy), `address`, `blaze`, `computer_api`, `deposit`, `fiat`, `network`, `network_asset`, `pin_payload`, `session`, `turn` (mixed HTTP/pure content). **Priority reorder**: `inscription.rb` should be re-attempted before `multisig.rb` because the work is already done in the prior run's branch — rebase it on current `main` and re-submit, rather than redoing it from scratch.
- **Task 8 (Performance Improvements) cursor**: addressed in this run. The `bytes += X` → `bytes.concat(X)` change in `lib/mixin_bot/transaction/encoder.rb` (70 sites) has been submitted as `repo-assist/perf-encoder-bytes-concat-2026-06-22`. Next performance opportunity: the `bytes.pack('C*')` calls at lines 40-41 of `encoder.rb` are the dominant remaining cost (a single O(n) walk per encode). Switching to a String buffer with `<<` would eliminate them but is a much larger refactor (changes return types of helpers and of `encode_uint16/32/64`).

## Decisions / substitutions this run (2026-06-22, 07:30 UTC)

- Selected tasks: 8 (Performance Improvements), 2 (Issue Investigation and Comment), 3 (Issue Investigation and Fix).
- Task 2: skipped comment action — all 20 open issues are automated, not user-facing (18 `[aw]` workflow trackers + Monthly Activity + #114 repo-assist docs issue).
- Task 3: no fixable user-reported bug identified. PR #133 and PR #131 are merged, the previously-blocked PR pipeline is unblocked, and the test-coverage sweep continues under Task 5/9.
- Task 8: **created draft PR `repo-assist/perf-encoder-bytes-concat-2026-06-22`** — converts all 70 `bytes += X` sites in `lib/mixin_bot/transaction/encoder.rb` to `bytes.concat(X)`, dropping the encoder from O(n·k) to O(n) for transaction byte assembly. Also folded the one multi-line `bytes += if ... else ... end` into a ternary `bytes.concat(@tx.aggregated.nil? ? encode_signatures : encode_aggregated_signature)` to match the single-line style used everywhere else in the file. Single-file change (70 insertions, 74 deletions), no public API change, no dependency change. Verified with a microbenchmark on Ruby 4.0.5: 2.7× speedup on a 16-input / 16-output transaction (0.656s → 0.242s for 5,000 iterations, byte-for-byte identical output). `ruby -c` syntax check passes; `rake test` and `rubocop` are firewall-blocked locally — CI is the source of truth.
- Cleaned up Suggested Actions in #99: removed merged PRs #131 and #133, removed the prior run's never-propagated test-inscription entry, added the new perf PR (branch-name only; PR number awaiting API propagation), and added issues #114 / #134 / #137 to acknowledge the maintainer's manual `git am` work pending.

## Forward work candidates (next runs)

- Watch for human contributor activity (low signal at present).
- **Test coverage sweep**: continue the pattern. Priority order based on line count + ratio of pure helpers to HTTP calls, with `inscription.rb` re-attempted first because the work is already done in the prior run's branch:
  1. `inscription.rb` (77 lines) — rebase the prior run's `repo-assist/test-inscription-2026-06-21` branch on current `main` and re-submit (the branch may still exist on origin or in the prior patch file)
  2. `multisig.rb` (58 lines) — `create_multisig_raw_tx` is pure-ish (depends on `create_safe_keys` + `build_safe_transaction`); other 4 methods are HTTP wrappers
  3. `legacy_user.rb` (51 lines) — `upgrade_legacy_user` is pure-ish (depends on `client.post`)
  4. `legacy_multisig.rb` (86 lines) — mostly HTTP wrappers, lower yield
  5. `withdraw.rb` (84 lines) — mostly HTTP wrappers, lower yield
- **Performance follow-up**: `bytes.pack('C*')` at lines 40-41 of `encoder.rb` is the dominant remaining cost. Switching to a String buffer with `<<` would eliminate it but is a much larger refactor (changes return types of `encode_uint16/32/64` and the helper methods). Candidate for a separate, benchmarked follow-up PR if profiling motivates it.
- **2.3.1 release preparation** is now overdue: the `sha3` dependency upgrade from PR #84 is still in CHANGELOG `[Unreleased]`, the Lean Squad removal from #129 is unreleased, and the docs-updater issues (#114, #134, #137) all want to add `CHANGELOG.md` `[Unreleased]` bullets that would land in 2.3.1. A maintainer would need to do a version bump + CHANGELOG restructure + tag push.
- **PR creation propagation lag**: keep noting that the GitHub MCP API can lag behind `create_pull_request` returning success; the patch files on disk are the source of truth until the API catches up.
- **Protected-files PR-push workaround** is now a known limitation affecting FOUR workflows: any PR/issue touching `README.md` / `AGENTS.md` / `CLAUDE.md` / `llms.txt` / `CHANGELOG.md` will land as an issue with a manual `git am` recipe. The maintainer needs to either drop the protection on those files or grant `workflows: write` to the Repo Assist and Documentation Updater workflows.

## Anti-patterns to avoid

- Do not comment on `github-actions[bot]`-generated issues (auto-managed, informational only).
- Do not create PRs duplicating Lean Squad output (the workflow has been removed entirely in #129).
- Do not close auto-managed issues like #90 (the framework manages those).
- Do not bump action versions in the dormant `lean-ci.yml` for the sake of a tiny version consistency — the workflow has been removed in #129.
- Do not re-propose the duplicate-PR investigation (PRs #95 and #96 are closed/merged as of this run).
- Do not bundle the CHANGELOG / version bump for a 2.3.1 release into a docs-only PR — release prep is a maintainer-driven decision and should remain a separate, larger change.
- **Do not attempt another PR touching `README.md`, `AGENTS.md`, `CLAUDE.md`, or `CHANGELOG.md` via `create_pull_request`** until the protected-files workaround is in place — it will reliably land as an issue rather than a PR (see #114, #134, #137), wasting the workflow turn.
- **Do not retry `create_pull_request` more than once for the same content in a single run** — even with `success` return values, the GitHub API can lag. The branch and patch are recoverable; double-creation is harder to clean up.
- Do not add a "Lean Squad Tier 3" goal to #99 going forward — Lean Squad is gone in #129. Use 2.3.1 release-prep as the strategic suggestion instead.
- **Do not call `assert_raises(ArgumentError)` (unqualified) in tests inside `module MixinBot`** when the production code raises the custom `MixinBot::ArgumentError` — Ruby resolves unqualified `ArgumentError` to `MixinBot::ArgumentError` inside that namespace. Use `MixinBot::ArgumentError` explicitly when you mean the custom class, or `::ArgumentError` explicitly when you mean the bare Ruby class. Both error classes are raised by `Inscription#create_collectible_transfer` (one for the inscription_hash guard, one for the members guard); the new test file distinguishes them.
- **Do not introduce a `bytes <<` or String-buffer optimization to `encoder.rb` as a sweeping refactor in a single PR** — it changes return types of helpers and of `encode_uint16/32/64`. If pursuing this, do it as a focused, separate, benchmarked PR. The current `Array#concat` change captures most of the win (2.7× on large transactions) with a minimal, mechanical diff.
