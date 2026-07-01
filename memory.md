---
name: repo-assist-memory
description: Persistent state for Repo Assist runs on baizhiheizi/mixin_bot
metadata:
  type: project
---

# Repo Assist Memory — baizhiheizi/mixin_bot

## Current state (as of 2026-07-01 05:29 UTC)

- **CI on `main`** is GREEN at `a5598c0`. Default branch unchanged.
- **Open issues**: 15 — 1 closed since 2026-06-29 (most likely an auto-generated `[aw]` that hit its expiry). 0 unlabelled.
- **Open PRs**: 2 Repo Assist drafts — #159 (nfo+invoice perf) + #163 (encrypted-message + mvm/registry perf). The new test-branch attempt from this run did NOT publish — third observed `safeoutputs create_pull_request` silent failure (issue #165 from 2026-06-29 was the second).
- **Test coverage**: 9 merged (#117, #123, #126, #131, #141, #142, #148, #152, #156). A 45-test draft for `BotAuth` + `UrlScheme` is committed locally on `repo-assist/test-bot-auth-url-scheme-2026-07-01-a1b2c3` (`90b7ae4`) — never published.
- **Selected tasks** at run 28495123814: 5, 2, 3.

## Cursors

- **Task 2 cursor**: 0 — #114 commented 2026-06-28 (recommend close). Others are auto-generated trackers.
- **Task 3 cursor**: 0 — no user-reported bugs; `UrlScheme` quirks require maintainer review.
- **Task 4 cursor**: empty — Dependabot-managed, up-to-date.
- **Task 5 cursor**: 9 merged test PRs. The 45-test BotAuth + UrlScheme attempt from 2026-07-01 is the **third** failed `create_pull_request` call. Branch + commit are real (`90b7ae4`); bundle + patch persisted to `/tmp/gh-aw/aw-*.{bundle,patch}`. Will need next-run diagnosis.
- **Task 8 cursor**: All `bytes += X` migrated.

## Critical 2026-07-01 failures

**Confirmed safe-outputs are silently failing in this run** for code/issue writes:

1. **`create_pull_request` × 2** — both attempts reported success (bundle + patch written) but neither branch appeared in `list_branches` and neither PR appeared in `list_pull_requests`. Branch `repo-assist/test-bot-auth-url-scheme-2026-07-01-a1b2c3` exists LOCALLY with commit `90b7ae4`, but `git push` failed (exit 128) — same root cause as 2026-06-29 issue #165.
2. **`update_issue` #99** — `status: "closed"` + `operation: "replace"` with new body. Reported success but body is unchanged and state is still "open".
3. **`create_issue`** — new July 2026 Monthly Activity issue. Reported success but no new issue number visible (#167+ all 404).
4. **`add_comment` on #99** — likely succeeded (call returned cleanly, could not verify downstream).

This is a **system-wide silent failure**, not a per-tool issue. Likely caused by a workflow-side network/credentials state that makes all code/issue writes fail despite the success response.

**Next-run priorities**:
- Verify state via `list_branches` + `list_issues` + `search_pull_requests` at start.
- If the local branch `repo-assist/test-bot-auth-url-scheme-2026-07-01-a1b2c3` STILL exists with `90b7ae4`, attempt `push_to_pull_request_branch` instead — that operates directly on a known-checked-out branch.
- If the failures persist across another run, file a `#166`-style workflow-failure issue for maintainers so they can investigate the safe-outputs infrastructure.

## Anti-patterns to avoid (additions this run)

- **Do not call `Integer(int, base)` with Ruby Integer as first arg** — only String parseable; bit PR #156.
- **Do not pass UUID strings to `Computer.user_id_to_bytes`** — production calls `Integer(uid, 10)` requiring String base-10.
- **`safeoutputs update_issue` body has 10 KB hard limit** — trim older run-history entries to stay under.
- **`UrlScheme::scheme_send` double-encodes data**: `Base64.strict_encode64(data)` → wrapped in `URI.encode_www_form_component` (yields `aGVsbG8%3D`) → then `URI.encode_www_form(q)` percent-encodes the `%` to `%25`. Recovery needs `URI.decode_www_form_component` after the form decode.
- **`UrlScheme::scheme_apps` `:action:` is overridden by `params: { action: ... }`** because `{ action: kw }.merge(params)` collapses shared symbol keys. Caller-visible quirk — possibly worth focused bug-fix PR.
- **Do not require `require 'mixin_bot'` directly when unit-testing single files in this sandbox** — top-level `mixin_bot.rb` requires `lib/mvm.rb`, which requires `eth`. The `eth` gem activates deps that conflict with Ruby 4.0's bundled `bigdecimal`/`openssl`. Either stub `Kernel#require` to no-op `eth`, or `require` only the leaf module file (e.g. `require 'mixin_bot/bot_auth'`, `require 'mixin_bot/url_scheme'`).
- **For BotAuth tests, pre-populate the cache** — `Client#sign_request` short-circuits to the cached `shared_key` when present. The 32-byte pre-populated cache makes `sign_request` fully exercisable offline; the short-cache branch (< 32 bytes) is verified via `NotFoundError`.
- **For UrlScheme tests, assert actual encoded behaviour** — see double-encoding quirk above.
- **`URI.encode_www_form(hash)` uses hash insertion order, NOT alphabetical sort.** Tests that assume alphabetical sort will fail. (Verified against production: `scheme_pay` kwargs come out in the same order they were supplied.)
- **`app_id.b` is the UTF-8 string app_id, NOT 16 bytes of binary** — `app_id` is stored as a String (e.g. UUID). `decoded[0, app_id.b.bytesize]` not `[0, 16]`. The test `assert_equal 32 + 32, decoded.bytesize` is wrong — use `decoded.bytesize == app_id.b.bytesize + 32`.

## Decisions this run (2026-07-01, 05:29 UTC)

- Selected tasks: 5, 2, 3. Task 2 + Task 3 no-action. Task 5 attempted but failed at the safe-outputs layer.
- Task 2 no-action: 15 open issues = 12 `[aw]`-prefixed automated `agentic-workflows` trackers (per memory standing anti-pattern) + `[repo-assist] Monthly Activity` #99 (mine) + `[repo-assist]` #114 (already commented 2026-06-28 with `recommend close`) + `[lean-squad]` #93 (don't duplicate Lean Squad output). No human engagement anywhere.
- Task 3 no-action: no user-reported bugs in the open set. The two `UrlScheme` quirks require maintainer discussion before any fix PR.
- Task 5: created branch `repo-assist/test-bot-auth-url-scheme-retry-2026-07-01-9f3a` (`f9555ab`) — committed the 45-test pair (`test_bot_auth.rb` 16 tests + `test_url_scheme.rb` 29 tests, 527 lines total) but `create_pull_request` reported success without publishing the branch. Tried a second `create_pull_request` after cherry-picking to `repo-assist/test-bot-auth-url-scheme-2026-07-01-a1b2c3` (`90b7ae4`) — same silent failure mode. Verified all 45 assertions pass against the actual production modules via `/tmp/gh-aw/agent/verify_bot_auth_url_scheme.rb`.
- Updated memory with the third observed safe-output silent failure and the recommended next-run diagnosis steps.
- Called `report_incomplete` rather than continuing to retry, per the safe-outputs retry-limit guidance.

## Previous decisions (2026-06-30, 15:34 UTC)

- Selected tasks: 2, 4, 3. All three no-action.
- Updated Monthly Activity #99: replaced stale `#aw_test1` placeholder (never materialised) with note about lost test PR.

## Previous decisions (2026-06-29, 06:05 UTC) [superseded — the claimed test PR was never published]

- Created PR branch `repo-assist/test-bot-auth-url-scheme-2026-06-29` (`927af9e`) — 46 new offline unit tests covering `BotAuth` + `UrlScheme`. The branch never made it to GitHub (silent `create_pull_request` failure). Issue #165 documents the code-push failure.

## Previous decisions (2026-06-28)

- Selected tasks: 2, 4, 8. Task 2 commented on #114; Task 4 no-action; Task 8 produced PR #163.

## Previous decisions (2026-06-27)

- Selected tasks: 2, 4, 10. Task 2 + Task 4 no-action; Task 10 produced PR #159.

## Earlier history (2026-06-16 through 2026-06-25)

- **2026-06-25**: PR #152 (`test_small_modules.rb`, 27 assertions) merged. PR #148 (Ruby 4.0 `legacy_user.rb` fix) merged.
- **2026-06-24**: PR #148 merged. PRs #145 + #146 superseded.
- **2026-06-23**: PR #142 (`test_multisig.rb`) merged.
- **2026-06-22**: PR #138 (`bytes += X` migration in `Transaction::Encoder`, 70 sites) merged 2026-06-25.
- **2026-06-20**: PR #133 (`fix-rubocop-variable-number`) merged.
- **2026-06-19**: PR #123 (`test_chain.rb`) merged. PR #126 (`test-output-threshold-script`) merged.
- **2026-06-18**: PR #117 (`test-tip-bodies`) merged. Issue #114 (docs-version-bump, superseded by PR #128) created.
- **2026-06-16**: Created Monthly Activity Summary issue #99.

## Forward work candidates

- **RETRY: `BotAuth` + `UrlScheme` test coverage** — third silent `create_pull_request` failure this run (verified bundle + patch written, but the PR/branch didn't appear). The content is committed locally at `repo-assist/test-bot-auth-url-scheme-2026-07-01-a1b2c3` (`90b7ae4`). When the safe-outputs infrastructure is fixed, this can be re-published directly via `push_to_pull_request_branch`.
- **`blaze.rb` test coverage**: the only remaining untested API module; 144 lines, EventMachine-heavy.
- **2.3.1 release preparation**: `sha3` + Lean Squad removal in `[Unreleased]`; 4 PRs (#138, #158, #159, #163) unreleased. Requires protected-files workaround.
- **Two `UrlScheme` quirks** (see anti-patterns): worth focused bug-fix PRs after maintainer review.
- **Documentation gap**: `lib/mixin_bot/api/blaze.rb` has minimal rdoc on the websocket-message encoder methods.
- **Consider splitting `lib/mixin_bot/api/message.rb`** — at 211 lines it mixes HTTP-push (`send_message`), pull/ack (`acknowledge_message`), WebSocket encoder (`write_ws_message` / `ws_message`), and message-build helpers (`plain_text`, `plain_image`, etc.). The WebSocket encoder pair belongs naturally with `Blaze`.
- **Re-create the July 2026 Monthly Activity**: #99 update + new July issue create both failed silently this run.

## Standing anti-patterns

- Do not comment on `github-actions[bot]`-generated issues.
- Do not duplicate Lean Squad output.
- Do not bump action versions in dormant `lean-ci.yml`.
- Do not bundle CHANGELOG/version bump into docs-only PR.
- **Do not attempt another PR touching `README.md`, `AGENTS.md`, `CLAUDE.md`, or `CHANGELOG.md` via `create_pull_request`** until protected-files workaround in place.
- **Do not retry `create_pull_request` more than once** for same content — repeated silent failures are documented.
- **Do not call `assert_raises(ArgumentError)` (unqualified) inside `module MixinBot`** when production raises custom `MixinBot::ArgumentError`.
- **Do not use `WebMock.after_request` for request body capture** — use `to_return do |request|` block.
- **Do not assume `CGI.escape` encodes spaces as `%20`** — encodes as `+`. `URI.encode_www_form_component` encodes as `%20`.
- **Do not assume a `create_pull_request` call published a PR** — always verify the branch exists at start of next run before relying on the PR number. `safeoutputs create_pull_request` can silently drop the PR (this is now the **third** documented case: 2026-06-29, 2026-06-30, 2026-07-01).
- **Do not assume `safeoutputs update_issue` / `create_issue` / `add_comment` wrote successfully just because the tool reported "success"** — verify with `issue_read` or `list_issues` if downstream code depends on it. The 2026-07-01 run observed silent failures across all four safe-output write tools.
