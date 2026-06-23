---
name: repo-assist-memory
description: Persistent state for Repo Assist runs on baizhiheizi/mixin_bot
metadata:
  type: project
---

# Repo Assist Memory — baizhiheizi/mixin_bot

## Current state (as of 2026-06-23 16:30 UTC)

- **Repo activity**: predominantly automated workflows. Last human contributor commit (an-lee): 2026-05-27.
- **CI is GREEN on `main`** (PR #133 + #131 merged in `4a95f97` + `2091e40`).
- **Open issues**: 21 — 20 automated workflow-tracking outputs + Monthly Activity (#99). The stale false-positive `aw` failure issues (e.g. #140) keep getting re-opened; the underlying workflow is healthy.
- **Open PRs**: 2 repo-assist PRs visible: PR #138 (perf encoder `bytes.concat`) and PR #141 (test inscription). 1 new draft PR `repo-assist/test-multisig-2026-06-23` from this run is not yet visible via the GitHub MCP API (propagation lag); patch at `/tmp/gh-aw/aw-repo-assist-test-multisig-2026-06-23.patch`.
- **Unlabelled issues**: 0
- **Monthly Activity issue**: [issue #99](https://github.com/baizhiheizi/mixin_bot/issues/99) for 2026-06 (active; updated this run).
- **Test coverage progress**: 5 merged + 2 awaiting. Module coverage at `lib/mixin_bot/api/`:
  - `test_tip.rb` (merged in #117)
  - `test_chain.rb` (merged in #123)
  - `test_output.rb` (merged in #126)
  - `test_legacy_collectible.rb` (merged in #131)
  - `test_inscription.rb` (DRAFT PR #141, from prior run)
  - `test_multisig.rb` (NEW DRAFT PR from this run — branch `repo-assist/test-multisig-2026-06-23`, 183 lines, 12 assertions)

## Backlog cursor

- **Task 2 (Issue Comment) cursor**: 0 — all open issues reviewed; no comment-worthy items this run.
- **Task 3 (Issue Fix) cursor**: 0 — no user-reported bugs; the previously-blocking RuboCop CI is green.
- **Task 4 (Engineering Investments) cursor**: nothing actionable.
- **Task 5/9 (Testing Improvements) cursor**: 5 merged + 2 awaiting (`test_inscription.rb` #141 + `test_multisig.rb` this run). Remaining untested modules: `legacy_user.rb` (51 lines — harder offline; needs real RSA private key + OAEP-decrypted pin token + Ed25519 derivation chain), `address`, `blaze`, `computer_api`, `deposit`, `fiat`, `network`, `network_asset`, `pin_payload`, `session`, `turn`. (`legacy_multisig.rb` and `withdraw.rb` already have tests.)
- **Task 8 (Performance Improvements) cursor**: PR #138 awaiting maintainer approval to run CI. Next opportunity: the `bytes.pack('C*')` calls at lines 40-41 of `encoder.rb` (called twice per encode). Caching `packed = bytes.pack('C*')` once is a clean micro-optimization but would compete with PR #138 until it merges. Alternative: extend the `bytes.concat` optimization to `nfo.rb` (16 sites) and `invoice.rb` (10 sites) — different files, additive, can land independently once PR #138 merges.

## Decisions / substitutions this run (2026-06-23, 16:30 UTC)

- Selected tasks: 3 (Issue Investigation and Fix), 9 (Testing Improvements), 2 (Issue Investigation and Comment).
- Task 2: skipped comment action — all 21 open issues are automated, not user-facing.
- Task 3: no fixable user-reported bug identified. The test-coverage sweep continues under Task 9.
- Task 9: **created draft PR `repo-assist/test-multisig-2026-06-23`** — new `test/mixin_bot/api/test_multisig.rb` (183 lines, 12 assertions) covering URL path construction for the 4 HTTP wrappers (`create_safe_multisig_request`, `sign_safe_multisig_request`, `unlock_safe_multisig_request`, `safe_multisig_request` — plus the `fetch_safe_multisig_request` alias), the body-shape distinction (array for `create_safe_multisig_request`, object for `sign_safe_multisig_request`), and the `create_multisig_raw_tx` multi-step pipeline (asserts `/safe/keys` is called twice via the stub, the returned hex starts with the `0x7777` magic, the round-trip preserves the input count and `extra` field, and `amount.to_s` coerces numeric input). Follows the offline pattern in `test_legacy_collectible.rb` and `test_chain.rb`. `bundle install` and `ruby` binary are unavailable in the sandbox (consistent with prior runs); CI will run `rake test` + RuboCop on Ruby 3.2 / 3.3 / 4.0. PR number not yet visible via the GitHub MCP API (propagation lag — same pattern as PR #138 and PR #141).
- PR #141 (test_inscription) is now visible (no longer branch-name-only).
- Cleaned up Suggested Actions in #99: promoted test-inscription to PR #141, added test-multisig (branch-name only), kept all maintained-docs-updater and Lean Squad cleanup items.

## Forward work candidates (next runs)

- Watch for human contributor activity (low signal at present).
- **Test coverage sweep**: continue the pattern. Priority order based on line count + ratio of pure helpers to HTTP calls:
  1. `legacy_user.rb` (51 lines) — `upgrade_legacy_user` is hard to test offline (needs a real RSA private key, OAEP-decrypted pin token, and Ed25519 derivation chain). The stub would need to encrypt a known plaintext with a known RSA public key, then the test would assert that the Ed25519 derivation and the request payload match expected values. Possible but more setup than the multisig stub.
  2. `address` — pure helpers in `lib/mixin_bot/utils/address.rb` (MainAddress/MixAddress parsing); easy unit tests
  3. `network_asset`, `pin_payload` — mostly HTTP wrappers, lower yield
  4. `turn`, `session`, `blaze` — WebSocket + auth helpers; harder to test offline
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
- **Do not assume `.compact` collapses entries in `create_multisig_raw_tx`** — the helper uses `Array#compact` which only removes `nil` elements, not hashes with nil fields. The change-output entry has `amount: nil` but is a non-nil Hash, so it survives. (Earlier draft of `test_multisig.rb` had a wrong "collapses_receivers_when_change_is_noop" test; removed.)
- **Do not assume `client.post` sends an empty body when all kwargs are nil** — the kwargs path goes through `kwargs.compact.to_json`, so `{access_token: nil}` becomes `"{}"`. The `unlock_safe_multisig_request` test only checks the URL path, not the body, to avoid coupling to the exact JSON serialization.
- **Do not forget the second `create_safe_keys` call from `generate_safe_keys`** — `build_safe_transaction` adds a third (change) recipient and `generate_safe_keys` calls `create_safe_keys` again. The `test_multisig.rb` `test_create_multisig_raw_tx_calls_safe_keys_endpoint` test asserts `times: 2` to account for this.
- **Do not pass the hex string of `extra` to `create_multisig_raw_tx`** and then expect the binary back — the encoder treats `extra` as raw bytes (no hex round-trip). If the caller wants to encode `'test of extra'`, pass that string directly; the decoded `extra` will be the same string. The test asserts this verbatim.
