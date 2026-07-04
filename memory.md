---
name: repo-assist-memory
description: Persistent state for Repo Assist runs on baizhiheizi/mixin_bot
metadata:
  type: project
---

# Repo Assist Memory — baizhiheizi/mixin_bot

## Current state (as of 2026-07-04 04:35 UTC)

- **CI on `main`** is GREEN at `48b6d56` (Dependabot bumps #173, #174, #175).
- **Open issues**: 9 — 0 unlabelled. 7 `[aw]` workflow-failure trackers (next expires 2026-07-05), 1 is #114 docs version bump, 1 is #169 (this issue).
- **Open PRs**: 0.
- **Test coverage**: 13 merged (#117, #123, #126, #131, #141, #142, #148, #152, #156, #167, #168, #171, **#172** merged 2026-07-03). The 2026-07-02 payment-test branch eventually published.
- **Selected tasks** at run 28694823573: 3, 8, 2.

## Cursors

- **Task 2 cursor**: 0 — #114 commented 2026-06-28 (recommend close).
- **Task 3 cursor**: 0 — fix applied this run (branch `repo-assist/fix-payment-scientific-notation-2026-07-04`).
- **Task 4 cursor**: empty — Dependabot-managed, CI clean.
- **Task 5 cursor**: 13 merged test PRs. **Seventh** observed `create_pull_request` silent failure.
- **Task 8 cursor**: All `bytes += X` migrated.

## Critical 2026-07-04 04:35 UTC run

**Selected tasks**: Task 3, Task 8, Task 2. Task 8 fallback (no perf sites). Task 2 no-action. Task 3 produced a real bug fix.

**Confirmed safe-output `create_pull_request` silently failed this run** (seventh documented case):
- Branch `repo-assist/fix-payment-scientific-notation-2026-07-04` (commit `a1436ba`, 2 files: `lib/mixin_bot/api/payment.rb` +3, `test/mixin_bot/api/test_payment.rb` +10/-10).
- Bundle + patch persisted to `/tmp/gh-aw/aw-repo-assist-fix-payment-scientific-notation-2026-07-04.{bundle,patch}` (bundle 1910 B, patch 3701 B / 77 lines).
- Per standing anti-pattern, did NOT retry.
- **Historical precedent**: the 2026-07-02 #172 branch eventually published and was merged 2026-07-03. The 2026-07-02 #171 branch also published. The 2026-07-01 #167/#168 branches published in the same run. So this fix may still publish in a future run.

**Fix details**:
- `lib/mixin_bot/api/payment.rb:14-17` — added one line: `amount = format('%.8f', amount.to_d.to_r).gsub(/\.?0+\z/, '')` after `mix_address` is built. Mirrors `MixinBot::Utils::Address#build_safe_recipient`'s existing amount formatting.
- `test/mixin_bot/api/test_payment.rb:64-86` — `test_safe_pay_url_encodes_amount_without_scientific_notation_regression` flipped from `assert_includes '1.0e-08'` (pin the bug) to `refute_includes 'e'` + `assert_equal '0.00000001'` (pin the fix).

**Verified offline**:
- `ruby -c` clean for both files.
- `gem build mixin_bot.gemspec` succeeded.
- Standalone verifier `/tmp/gh-aw/agent/verify_payment_fix.rb` exercises the actual patched production code path: **13/14 assertions pass**. The 1 failure is a stub-incompatibility on `parse_mix_address` multisig hex splitting — production path is fine; covered by `test_multisig.rb`.

**Confirmed safe-output `update_issue` silently failed this run** on Monthly Activity #169:
- Sent full new body (~8 KB) with `operation: "replace"`.
- Reported "success" but issue body is unchanged.
- Recovery: `add_comment` with the new run history. Reported success with `temporary_id: aw_Jrs3xxEQ`, but the comment is not yet visible in `get_comments`.

## Verified-payment-fix info (for next-run retry)

- Branch: `repo-assist/fix-payment-scientific-notation-2026-07-04` (commit `a1436ba`)
- Files: `lib/mixin_bot/api/payment.rb` (+3) + `test/mixin_bot/api/test_payment.rb` (+10/-10)
- Standalone verifier: `/tmp/gh-aw/agent/verify_payment_fix.rb` — 13/14 assertions pass.
- Bundle + patch at `/tmp/gh-aw/aw-repo-assist-fix-payment-scientific-notation-2026-07-04.{bundle,patch}`.

## Anti-patterns (verified, 2026-07-04)

- **`MixinBot::API::Payment#safe_pay_url` scientific-notation bug** — **FIX APPLIED 2026-07-04** in branch `repo-assist/fix-payment-scientific-notation-2026-07-04`. Now uses `format('%.8f', amount.to_d.to_r).gsub(/\.?0+\z/, '')` mirroring `build_safe_recipient`.
- **The original `test_payment.rb` passed `trace:` instead of `trace_id:`** — silently ignored because the method reads `kwargs[:trace_id]`. Test `test_safe_pay_url_does_not_pass_unknown_kwargs_through` pins this regression.
- **`update_issue` and `add_comment` on Monthly Activity #169 also intermittently silently fail** — verify with `issue_read` / `get_comments` after each call. If neither persists, the local memory file is the canonical state.

## Decisions this run (2026-07-04, 04:35 UTC)

- Selected tasks: 3, 8, 2. Task 8 fallback (no perf sites after #138, #158, #159, #163). Task 2 no-action. Task 3 fix applied.
- Task 3: one-line fix in `lib/mixin_bot/api/payment.rb:14-17` mirroring `build_safe_recipient`'s amount formatting; regression test flipped from "pin the bug" to "pin the fix". `gem build` succeeds. Standalone verifier 13/14 pass. Bundle + patch persisted. PR did not publish (seventh time).
- Task 11: attempted `update_issue` on #169 — silently failed (body unchanged). Recovery `add_comment` — reported success but not yet visible.

## Earlier runs (condensed)

- **2026-07-02 15:25 UTC** — Selected: 2, 9, 3. Task 9: payment-test branch (`e6d0956`, 12 tests). Bundle + patch persisted. **Eventually published as PR #172, merged 2026-07-03.** Task 11: `update_issue` silently failed.
- **2026-07-02 05:35 UTC** — Selected: 4, 10, 9. Task 9: blaze-test branch (`e0919db`, 18 tests). Bundle + patch persisted. **Eventually published as PR #171, merged 2026-07-03.** Task 11: `update_issue` silently failed.
- **2026-07-01 05:29 UTC** — Selected: 5, 2, 3. Task 5: 45 tests (BotAuth + UrlScheme). **Eventually published as PRs #167 + #168, merged.** Closed June 2026 monthly summary #99.
- **2026-06-30 15:34 UTC** — Selected: 2, 4, 3. All no-action. Updated #99: replaced stale `#aw_test1` placeholder.
- **2026-06-28** — Selected: 2, 4, 8. Task 2 commented on #114; Task 8 produced PR #163 (perf).
- **2026-06-27** — Selected: 2, 4, 10. Task 10 produced PR #159 (perf).
- **2026-06-25** — PR #152 (`test_small_modules.rb`, 27 assertions) merged. PR #148 merged.
- **2026-06-23** — PR #142 (`test_multisig.rb`) merged.
- **2026-06-22** — PR #138 (`bytes += X` migration, 70 sites) merged 2026-06-25.
- **2026-06-20** — PR #133 (`fix-rubocop-variable-number`) merged.
- **2026-06-19** — PR #123 (`test_chain.rb`) merged. PR #126 (`test-output-threshold-script`) merged.
- **2026-06-18** — PR #117 (`test-tip-bodies`) merged. Issue #114 created.
- **2026-06-16** — Created Monthly Activity Summary issue #99.

## Forward work candidates

- **RETRY: safe_pay_url amount scientific-notation fix** (branch `repo-assist/fix-payment-scientific-notation-2026-07-04`, commit `a1436ba`). One-line fix + flipped regression test. Verifier 13/14 pass. **Likely to eventually publish** (precedent: #171, #172, #167/#168 all published after delayed silent failures).
- **2.3.1 release preparation**: `sha3` + Lean Squad removal in `[Unreleased]`; 4 perf PRs (#138, #158, #159, #163) + 1 bug fix branch (safe_pay_url amount) unreleased. Requires protected-files workaround.
- **Two `UrlScheme` quirks** (see standing anti-patterns): worth focused bug-fix PRs after maintainer review.
- **Documentation gap**: `lib/mixin_bot/api/blaze.rb` has minimal rdoc on the websocket-message encoder methods.
- **Consider splitting `lib/mixin_bot/api/message.rb`** — at 211 lines it mixes HTTP-push, pull/ack, WebSocket encoder, and message-build helpers.

## Standing anti-patterns

- Do not comment on `github-actions[bot]`-generated issues.
- Do not duplicate Lean Squad output.
- Do not bump action versions in dormant `lean-ci.yml`.
- Do not bundle CHANGELOG/version bump into docs-only PR.
- **Do not attempt another PR touching `README.md`, `AGENTS.md`, `CLAUDE.md`, or `CHANGELOG.md` via `create_pull_request`** until protected-files workaround in place.
- **Do not retry `create_pull_request` more than once** for same content — repeated silent failures are documented (now SEVEN cases: #162, #165, #166, #170, 2026-07-02-blaze, 2026-07-02-payment, 2026-07-04-fix-payment). However, three of those cases (#171, #172, #167/#168) eventually published in subsequent runs.
- **Do not call `assert_raises(ArgumentError)` (unqualified) inside `module MixinBot`** when production raises custom `MixinBot::ArgumentError`.
- **Do not use `WebMock.after_request` for request body capture** — use `to_return do |request|` block.
- **Do not assume `CGI.escape` encodes spaces as `%20`** — encodes as `+`. `URI.encode_www_form_component` encodes as `%20`.
- **Do not assume a `create_pull_request` call published a PR** — always verify the branch exists at start of next run before relying on the PR number.
- **Do not assume `safeoutputs update_issue` / `create_issue` / `add_comment` wrote successfully just because the tool reported "success"** — verify with `issue_read` or `list_issues` if downstream code depends on it. Confirmed failures on #169 in 2026-07-02 15:25 and 2026-07-04 04:35 runs.
- **`write_ws_message` produces signed bytes via `unpack('c*')`** — second gzip-magic byte is `-117`, not `0x8b`.
- **Two envelopes with same payload have different envelope/message UUIDs** — `blaze_send_post` vs `blaze_send_plain_text` content-equivalent but envelope-distinct.
- **`Payment#safe_pay_url` scientific-notation fix applied 2026-07-04** — branch `repo-assist/fix-payment-scientific-notation-2026-07-04`. Now uses `format('%.8f', amount.to_d.to_r).gsub(/\.?0+\z/, '')` mirroring `build_safe_recipient`.
- **`Payment#safe_pay_url` silently ignores `trace:` (without `_id`)** — original test passed this typo and it masked the `SecureRandom.uuid` default.