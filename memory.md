---
name: repo-assist-memory
description: Persistent state for Repo Assist runs on baizhiheizi/mixin_bot
metadata:
  type: project
---

# Repo Assist Memory — baizhiheizi/mixin_bot

## Current state (as of 2026-07-09 15:58 UTC)

- **CI on `main`** is GREEN at `da25d87` (PR #176 — the safe_pay_url scientific-notation fix, **merged 2026-07-04**).
- **Open issues**: 6 — 0 unlabelled. 4 `[aw]` workflow-failure/no-op/detection trackers (#178, #177, #112, #90) — skip per anti-pattern; #114 (docs version bump PR draft, recommend close); #169 (Monthly Activity).
- **Open PRs**: 0.
- **Test coverage**: comprehensive. Every module under `lib/mixin_bot/api/` has a corresponding test file. 13 test PRs merged this cycle (#117, #123, #126, #131, #141, #142, #148, #152, #156, #167, #168, #171, #172).
- **Performance sites**: exhausted (#138, #158, #159, #163).
- **Bug fixes landed**: PR #176 (safe_pay_url amount scientific notation, the long-running 2026-07-04 branch that survived silent-push).
- **Selected tasks** at run 29030966288: 10, 2, 3.

## Cursors

- **Task 2 cursor**: 0 — #114 commented 2026-06-28 (recommend close). No other user-facing open issues.
- **Task 3 cursor**: 0 — no user-reported bugs in current open issues.
- **Task 4 cursor**: empty — Dependabot-managed, CI clean.
- **Task 5 cursor**: 13 merged test PRs. **Seventh** observed `create_pull_request` silent failure.
- **Task 8 cursor**: All `bytes += X` migrated.

## Critical 2026-07-09 15:58 UTC run

**Selected tasks**: Task 10, Task 2, Task 3. All no-action.

**Task 10 closed out**: The previous forward candidate — the 2026-07-04 `repo-assist/fix-payment-scientific-notation-2026-07-04` branch — **is now PR #176 and merged in `main` at `da25d87`**. This is the third documented case of a silent-push failure that eventually publishes in a subsequent run (joining #171 and #172). The branch + bundle + patch are now redundant; can be cleaned up.

**Task 11**: Posted the consolidated run history as an `add_comment` on Monthly Activity #169 (temporary_id `aw_TJIS4V38`). Refreshed "Suggested Actions" with merged PR #176 in the 2.3.1 release goal. Skipped `update_issue` (consistent with prior silent-failure pattern).

## Critical 2026-07-04 04:35 UTC run

**Selected tasks**: Task 3, Task 8, Task 2. Task 8 fallback (no perf sites). Task 2 no-action. Task 3 produced a real bug fix.

**Confirmed safe-output `create_pull_request` silently failed this run** (seventh documented case):
- Branch `repo-assist/fix-payment-scientific-notation-2026-07-04` (commit `a1436ba`, 2 files: `lib/mixin_bot/api/payment.rb` +3, `test/mixin_bot/api/test_payment.rb` +10/-10).
- Bundle + patch persisted to `/tmp/gh-aw/aw-repo-assist-fix-payment-scientific-notation-2026-07-04.{bundle,patch}` (bundle 1910 B, patch 3701 B / 77 lines).
- **The branch eventually published as PR #176 and was merged 2026-07-04**. Content now in `main` at `da25d87`. The standalone verifier `/tmp/gh-aw/agent/verify_payment_fix.rb` was the canonical correctness proof while the branch waited.

**Fix details**:
- `lib/mixin_bot/api/payment.rb:14-17` — added one line: `amount = format('%.8f', amount.to_d.to_r).gsub(/\.?0+\z/, '')` after `mix_address` is built. Mirrors `MixinBot::Utils::Address#build_safe_recipient`'s existing amount formatting.
- `test/mixin_bot/api/test_payment.rb:64-86` — `test_safe_pay_url_encodes_amount_without_scientific_notation_regression` flipped from `assert_includes '1.0e-08'` (pin the bug) to `refute_includes 'e'` + `assert_equal '0.00000001'` (pin the fix).

## Anti-patterns (verified, 2026-07-09)

- **`MixinBot::API::Payment#safe_pay_url` scientific-notation bug** — **FIXED in main via PR #176 (commit `da25d87`)**. Now uses `format('%.8f', amount.to_d.to_r).gsub(/\.?0+\z/, '')` mirroring `build_safe_recipient`.
- **The original `test_payment.rb` passed `trace:` instead of `trace_id:`** — silently ignored because the method reads `kwargs[:trace_id]`. Test `test_safe_pay_url_does_not_pass_unknown_kwargs_through` pins this regression.
- **`update_issue` on Monthly Activity #169 intermittently silently fails** — verified across runs 28566120129, 28599951608, 28694823573, 29030966288. Recovery pattern: post consolidated run history via `add_comment`. The body's "Suggested Actions" stays stale; the comments are the canonical trail.

## Decisions this run (2026-07-09, 15:58 UTC)

- Selected tasks: 10, 2, 3. All no-action — closeout run.
- Task 10: forward candidate (PR #176) verified merged at `da25d87`. Branch + bundle + patch can be cleaned up.
- Task 11: `add_comment` on #169 with consolidated history including the PR #176 merge celebration. Skipped `update_issue` per persistent anti-pattern.

## Earlier runs (condensed)

- **2026-07-04 04:35 UTC** — Selected: 3, 8, 2. Task 3 produced PR #176 (merged 2026-07-04, da25d87).
- **2026-07-02 15:25 UTC** — Selected: 2, 9, 3. Task 9: payment-test branch (`e6d0956`, 12 tests). **Eventually published as PR #172, merged 2026-07-03.** Task 11: `update_issue` silently failed.
- **2026-07-02 05:35 UTC** — Selected: 4, 10, 9. Task 9: blaze-test branch (`e0919db`, 18 tests). **Eventually published as PR #171, merged 2026-07-03.** Task 11: `update_issue` silently failed.
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

- **2.3.1 release preparation**: `sha3` + Lean Squad removal in `[Unreleased]`; 4 perf PRs (#138, #158, #159, #163) + 5 test PRs (#117, #123, #126, #131, #142, #148, #152, #156, #167, #168, #171, #172) + 1 bug fix (#176) all merged since 2.3.0. Requires protected-files workaround for `CHANGELOG.md` + `VERSION`.
- **Two `UrlScheme` quirks** (see standing anti-patterns): intentional per test file docs (matches Go), but worth a focused note in `CHANGELOG` if maintainers want to track them.
- **Documentation gap**: `lib/mixin_bot/api/blaze.rb` and `lib/mixin_bot/api/message.rb` have minimal rdoc on the websocket-message encoder methods — but the project style is consistent in not having heavy rdoc on these helpers, so this is borderline noise.

## Standing anti-patterns

- Do not comment on `github-actions[bot]`-generated issues.
- Do not duplicate Lean Squad output.
- Do not bump action versions in dormant `lean-ci.yml`.
- Do not bundle CHANGELOG/version bump into docs-only PR.
- **Do not attempt another PR touching `README.md`, `AGENTS.md`, `CLAUDE.md`, or `CHANGELOG.md` via `create_pull_request`** until protected-files workaround in place.
- **Do not retry `create_pull_request` more than once** for same content — repeated silent failures are documented (now SEVEN cases: #162, #165, #166, #170, 2026-07-02-blaze, 2026-07-02-payment, 2026-07-04-fix-payment). **However, THREE of those cases (#171, #172, #176) eventually published in subsequent runs** — so the silent failure is recoverable in 1–5 runs. Always verify whether prior content has published before re-creating.
- **Do not call `assert_raises(ArgumentError)` (unqualified) inside `module MixinBot`** when production raises custom `MixinBot::ArgumentError`.
- **Do not use `WebMock.after_request` for request body capture** — use `to_return do |request|` block.
- **Do not assume `CGI.escape` encodes spaces as `%20`** — encodes as `+`. `URI.encode_www_form_component` encodes as `%20`.
- **Do not assume a `create_pull_request` call published a PR** — always verify the branch exists at start of next run before relying on the PR number. **But also: do not give up if it didn't publish — wait 1–5 runs; it may.**
- **Do not assume `safeoutputs update_issue` / `create_issue` / `add_comment` wrote successfully just because the tool reported "success"** — verify with `issue_read` or `list_issues` if downstream code depends on it. Confirmed failures on #169 in 2026-07-02 05:35, 2026-07-02 15:25, 2026-07-04 04:35, and skipped in 2026-07-09 15:58 runs.
- **`write_ws_message` produces signed bytes via `unpack('c*')`** — second gzip-magic byte is `-117`, not `0x8b`.
- **Two envelopes with same payload have different envelope/message UUIDs** — `blaze_send_post` vs `blaze_send_plain_text` content-equivalent but envelope-distinct.
- **`Payment#safe_pay_url` scientific-notation fix MERGED via PR #176 (commit `da25d87`)** — uses `format('%.8f', amount.to_d.to_r).gsub(/\.?0+\z/, '')` mirroring `build_safe_recipient`.
- **`Payment#safe_pay_url` silently ignores `trace:` (without `_id`)** — original test passed this typo and it masked the `SecureRandom.uuid` default.
- **`scheme_apps` `params: { action: 'x' }` overrides the `action:` kwarg** — intentional, matches Go. Documented in `test/mixin_bot/api/test_url_scheme.rb:198-211`.
- **`scheme_send` double-encodes `data`** — `Base64.strict_encode64` → `URI.encode_www_form_component` → `URI.encode_www_form`. Round-trip is `URI.decode_www_form` → `URI.decode_www_form_component` → `Base64.strict_decode64`. Documented in `test_url_scheme.rb:241-258`.
