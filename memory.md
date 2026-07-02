---
name: repo-assist-memory
description: Persistent state for Repo Assist runs on baizhiheizi/mixin_bot
metadata:
  type: project
---

# Repo Assist Memory — baizhiheizi/mixin_bot

## Current state (as of 2026-07-02 15:25 UTC)

- **CI on `main`** is GREEN at `3540515`. Default branch unchanged.
- **Open issues**: 12 — 0 unlabelled. Most are `[aw]` workflow-failure trackers (expires-2026-07-08).
- **Open PRs**: 0.
- **Test coverage**: 12 merged (#117, #123, #126, #131, #141, #142, #148, #152, #156, #167, #168, #171). `payment.rb` test branch ready locally but PR push failed again this run.
- **Selected tasks** at run 28599951608: 2, 9, 3.

## Cursors

- **Task 2 cursor**: 0 — #114 commented 2026-06-28 (recommend close). All others are auto-generated trackers.
- **Task 3 cursor**: 0 — no user-reported bugs; `UrlScheme` quirks require maintainer review.
- **Task 4 cursor**: empty — Dependabot-managed, CI clean.
- **Task 5 cursor**: 12 merged test PRs. Payment test attempt (2026-07-02) — **sixth** observed `create_pull_request` silent failure.
- **Task 8 cursor**: All `bytes += X` migrated.

## Critical 2026-07-02 15:25 UTC failure (and the historical pattern)

**Confirmed safe-output `create_pull_request` silently failed this run** (consistent with the five prior documented cases in 2026-06-29 #165, 2026-06-30 #166, 2026-07-01 #170, 2026-06-28 #162, and 2026-07-02 #171 branch):

- Created branch `repo-assist/test-payment-module-2026-07-02` (commit `e6d0956`, 1 file, 241 lines = `test_payment.rb` with 12 offline tests for `Payment#safe_pay_url`).
- `create_pull_request` reported success with bundle (3634 bytes) + patch (10294 bytes) persisted to `/tmp/gh-aw/aw-repo-assist-test-payment-module-2026-07-02.{bundle,patch}`.
- Branch does NOT appear in `list_branches` (only 13 remote branches listed, my new one is missing).
- PR does NOT appear in `list_pull_requests` (state=open) or `search_pull_requests`.
- Local commit + branch persist on disk; `git rev-parse HEAD` returns `e6d0956444ff6412861e51e5a03a16b340e8be0e`.
- Per the standing anti-pattern (don't retry `create_pull_request` more than once for same content), did NOT retry. Recorded for next-run verification.

**Also confirmed safe-output `update_issue` silently failed this run** on Monthly Activity #169 (similar pattern to the 05:35 UTC run on the same issue):

- Sent full new body (~10 KB) with `operation: "replace"`.
- Reported "success" but issue body is unchanged (verified via `issue_read`).
- Recovery attempt: `add_comment` with new run history. Reported success with `temporary_id: aw_CHlYju6U`, but the comment is not yet visible in `get_comments` (only the 05:35 comment from id 4862626442 shows). Per the anti-pattern, did not retry.

**The June/July 2026 test PRs (#167, #168, #171) eventually published after 2-3 silent failures each**, so the content eventually lands — but only when the workflow infrastructure permits. Maintainer review of issues #162, #165, #166, #170 may help diagnose the underlying `git push exit 128` cause.

## Verified-payment-tests info (for next-run retry)

- Test file: `test/mixin_bot/api/test_payment.rb` (12 tests, 241 lines)
- Standalone verifier: `/tmp/gh-aw/agent/verify_payment.rb` — replays every assertion, **17/17 pass** against the installed `mixin_bot (2.3.0)`.
- Branch + bundle + patch all real and persisted.
- Can be re-published via `push_to_pull_request_branch` once a PR number is known, or `create_pull_request` re-attempted with same content in a future run.

## Anti-patterns to avoid (additions this run)

- **`MixinBot::API::Payment#safe_pay_url` renders small floats in scientific notation** — `amount: 0.00000001` → `amount=1.0e-08` in the URL because the implementation interpolates `amount` directly without a `BigDecimal` conversion. Mixin's URL parser does NOT accept scientific notation, so very small amounts will be rejected by the web UI. Test `test_safe_pay_url_encodes_amount_without_scientific_notation_regression` pins this bug; flip the assertion when fixed.
- **The original `test_payment.rb` passed `trace:` instead of `trace_id:`** — silently ignored because the method reads `kwargs[:trace_id]`, so the test happened to pass via the `SecureRandom.uuid` default. Test `test_safe_pay_url_does_not_pass_unknown_kwargs_through` pins this regression.
- **`update_issue` and `add_comment` on Monthly Activity #169 also intermittently silently fail** — verify with `issue_read` / `get_comments` after each call. If neither persists, the local memory file is the canonical state.

## Decisions this run (2026-07-02, 15:25 UTC)

- Selected tasks: 2, 9, 3. Task 2 + Task 3 no-action (no user-reported bugs, all open issues are workflow trackers). Task 9 created branch + commit, push failed (sixth time).
- Task 9: 12 offline unit tests for `Payment#safe_pay_url`. Bundle + patch persisted to `/tmp/gh-aw/aw-repo-assist-test-payment-module-2026-07-02.{bundle,patch}`. PR did not publish.
- Task 11: attempted `update_issue` on #169 (Monthly Activity) — silently failed. Recovery `add_comment` — reported success but not yet visible.

## Previous decisions (2026-07-02, 05:35 UTC)

- Selected tasks: 4, 10, 9. Task 4 no-action (Dependabot/CI clean). Task 9 created branch + commit, push failed. Task 10 attempted to take repo forward with blaze tests (highest-leverage candidate from memory).
- Task 4 no-action: `.github/workflows/ci.yml` uses `actions/checkout@v7`, `ruby/setup-ruby@v1`, `bundle-cache: true`. Gemspec dependencies all at current versions. No actionable engineering improvements identified.
- Task 9: 18 offline unit tests for `blaze.rb` helpers. Bundle + patch persisted to `/tmp/gh-aw/aw-repo-assist-test-blaze-2026-07-02-3f8a.{bundle,patch}`. PR did not publish.
- Task 10: aligned memory with current GitHub state (PRs #167/#168 actually merged), then pursued blaze tests as Task 9.
- Task 11: will attempt `update_issue` on #169 (Monthly Activity) — if it silently fails, document and rely on memory for the history.

## Previous decisions (2026-07-01, 05:29 UTC)

- Selected tasks: 5, 2, 3. Task 2 + Task 3 no-action. Task 5 attempted but failed at the safe-outputs layer.
- Test branch `repo-assist/test-bot-auth-url-scheme-2026-07-01-a1b2c3` (`90b7ae4`) was committed locally — `create_pull_request` reported success without publishing the branch. **But that branch + content eventually published as PRs #167 and #168 in a subsequent run.**

## Previous decisions (2026-06-30, 15:34 UTC)

- Selected tasks: 2, 4, 3. All three no-action.
- Updated Monthly Activity #99: replaced stale `#aw_test1` placeholder (never materialised) with note about lost test PR.

## Earlier history (2026-06-16 through 2026-06-28)

- **2026-06-28**: Selected tasks: 2, 4, 8. Task 2 commented on #114; Task 4 no-action; Task 8 produced PR #163.
- **2026-06-27**: Selected tasks: 2, 4, 10. Task 2 + Task 4 no-action; Task 10 produced PR #159.
- **2026-06-25**: PR #152 (`test_small_modules.rb`, 27 assertions) merged. PR #148 (Ruby 4.0 `legacy_user.rb` fix) merged.
- **2026-06-24**: PR #148 merged. PRs #145 + #146 superseded.
- **2026-06-23**: PR #142 (`test_multisig.rb`) merged.
- **2026-06-22**: PR #138 (`bytes += X` migration in `Transaction::Encoder`, 70 sites) merged 2026-06-25.
- **2026-06-20**: PR #133 (`fix-rubocop-variable-number`) merged.
- **2026-06-19**: PR #123 (`test_chain.rb`) merged. PR #126 (`test-output-threshold-script`) merged.
- **2026-06-18**: PR #117 (`test-tip-bodies`) merged. Issue #114 (docs-version-bump, superseded by PR #128) created.
- **2026-06-16**: Created Monthly Activity Summary issue #99.

## Forward work candidates

- **RETRY: `Payment` test coverage** — sixth silent `create_pull_request` failure this run. The content is committed locally at `repo-assist/test-payment-module-2026-07-02` (`e6d0956`), bundle + patch persisted. 12 tests, 17 assertions all pass offline.
- **FIX: `Payment#safe_pay_url` scientific notation bug** — `amount=1.0e-08` for small floats breaks Mixin web UI URL parsing. Fix is one-line: `format('%.8f', amount.to_d.to_r).gsub(/\.?0+$/, '')` like `build_safe_recipient` already does.
- **2.3.1 release preparation**: `sha3` + Lean Squad removal in `[Unreleased]`; 4 perf PRs (#138, #158, #159, #163) unreleased. Requires protected-files workaround.
- **Two `UrlScheme` quirks** (see anti-patterns): worth focused bug-fix PRs after maintainer review.
- **Documentation gap**: `lib/mixin_bot/api/blaze.rb` has minimal rdoc on the websocket-message encoder methods.
- **Consider splitting `lib/mixin_bot/api/message.rb`** — at 211 lines it mixes HTTP-push (`send_message`), pull/ack (`acknowledge_message`), WebSocket encoder (`write_ws_message` / `ws_message`), and message-build helpers (`plain_text`, `plain_image`, etc.). The WebSocket encoder pair belongs naturally with `Blaze`.

## Standing anti-patterns

- Do not comment on `github-actions[bot]`-generated issues.
- Do not duplicate Lean Squad output.
- Do not bump action versions in dormant `lean-ci.yml`.
- Do not bundle CHANGELOG/version bump into docs-only PR.
- **Do not attempt another PR touching `README.md`, `AGENTS.md`, `CLAUDE.md`, or `CHANGELOG.md` via `create_pull_request`** until protected-files workaround in place.
- **Do not retry `create_pull_request` more than once** for same content — repeated silent failures are documented (now SIX cases: #162, #165, #166, #170, 2026-07-02-blaze, 2026-07-02-payment).
- **Do not call `assert_raises(ArgumentError)` (unqualified) inside `module MixinBot`** when production raises custom `MixinBot::ArgumentError`.
- **Do not use `WebMock.after_request` for request body capture** — use `to_return do |request|` block.
- **Do not assume `CGI.escape` encodes spaces as `%20`** — encodes as `+`. `URI.encode_www_form_component` encodes as `%20`.
- **Do not assume a `create_pull_request` call published a PR** — always verify the branch exists at start of next run before relying on the PR number. `safeoutputs create_pull_request` can silently drop the PR (this is now the **sixth** documented case).
- **Do not assume `safeoutputs update_issue` / `create_issue` / `add_comment` wrote successfully just because the tool reported "success"** — verify with `issue_read` or `list_issues` if downstream code depends on it. Confirmed `update_issue` failure on #169 in the 2026-07-02 15:25 run.
- **`write_ws_message` produces signed bytes via `unpack('c*')`** — second gzip-magic byte is `-117`, not `0x8b`.
- **Two envelopes with same payload have different envelope/message UUIDs** — `blaze_send_post` vs `blaze_send_plain_text` content-equivalent but envelope-distinct.
- **`Payment#safe_pay_url` renders small floats in scientific notation** — `amount: 0.00000001` → `amount=1.0e-08` in URL. Implementation interpolates `amount` directly; should mirror `build_safe_recipient`'s `format('%.8f', amount.to_d.to_r).gsub(/\.?0+$/, '')`.
- **`Payment#safe_pay_url` silently ignores `trace:` (without `_id`)** — original test passed this typo and it masked the `SecureRandom.uuid` default.