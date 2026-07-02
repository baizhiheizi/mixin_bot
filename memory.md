---
name: repo-assist-memory
description: Persistent state for Repo Assist runs on baizhiheizi/mixin_bot
metadata:
  type: project
---

# Repo Assist Memory — baizhiheizi/mixin_bot

## Current state (as of 2026-07-02 05:35 UTC)

- **CI on `main`** is GREEN at `e7395ce`. Default branch unchanged.
- **Open issues**: 13 — 0 unlabelled. Most are `[aw]` workflow-failure trackers (expires-2026-07-08).
- **Open PRs**: 0.
- **Test coverage**: 11 merged (#117, #123, #126, #131, #141, #142, #148, #152, #156, #167, #168). `blaze.rb` (144 lines) test branch ready locally but PR push failed again this run.
- **Selected tasks** at run 28566120129: 4, 10, 9.

## Cursors

- **Task 2 cursor**: 0 — #114 commented 2026-06-28 (recommend close). All others are auto-generated trackers.
- **Task 3 cursor**: 0 — no user-reported bugs; `UrlScheme` quirks require maintainer review.
- **Task 4 cursor**: empty — Dependabot-managed, CI clean.
- **Task 5 cursor**: 9 merged test PRs. Blaze test attempt (2026-07-02) — **fourth** observed `create_pull_request` silent failure.
- **Task 8 cursor**: All `bytes += X` migrated.

## Critical 2026-07-02 failure (and the historical pattern)

**Confirmed safe-output `create_pull_request` silently failed this run** (consistent with the four prior documented cases in 2026-06-29 #165, 2026-06-30 #166, 2026-07-01 #170, and 2026-06-28 #162):

- Created branch `repo-assist/test-blaze-2026-07-02-3f8a` (commit `e0919db`, 1 file, 413 lines = `test_blaze.rb` with 18 offline tests for the seven `blaze_send_*` helpers + 3 wire-format invariants).
- `create_pull_request` reported success with bundle (4457 bytes) + patch (16169 bytes) persisted to `/tmp/gh-aw/aw-repo-assist-test-blaze-2026-07-02-3f8a.{bundle,patch}`.
- Branch does NOT appear in `list_branches` (only 13 remote branches listed, my new one is missing).
- PR does NOT appear in `list_pull_requests` (state=open) or `search_pull_requests`.
- Local commit + branch persist on disk; `git rev-parse HEAD` returns `e0919dbc4f24184431078d68519be251bbd05460`.
- Per the standing anti-pattern (don't retry `create_pull_request` more than once for same content), did NOT retry. Called `report_incomplete`.

**The June 2026 test PRs (#167, #168) eventually published after 2-3 silent failures each**, so the content eventually lands — but only when the workflow infrastructure permits. Maintainer review of issues #165, #166, #170, #162 may help diagnose the underlying `git push exit 128` cause.

## Verified-blaze-tests info (for next-run retry)

- Test file: `test/mixin_bot/api/test_blaze.rb` (18 tests, 413 lines)
- Standalone verifier: `/tmp/gh-aw/agent/verify_blaze.rb` — replays every assertion, **58/58 pass** against the installed `mixin_bot (2.3.0)`.
- Branch + bundle + patch all real and persisted.
- Can be re-published via `push_to_pull_request_branch` once a PR number is known, or `create_pull_request` re-attempted with same content in a future run.

## Anti-patterns to avoid (additions this run)

- **`write_ws_message` produces SIGNED 8-bit bytes via `unpack('c*')`** — second byte of gzip magic is `-117` (signed) not `0x8b` (unsigned). Tests must assert `bytes.all? { |b| b.between?(-128, 127) }`, not `0..255`.
- **Two envelopes with the same content but different calls have DIFFERENT envelope + message UUIDs** — `blaze_send_post` is payload-equivalent to `blaze_send_plain_text`, not whole-envelope equal. Compare `params['category']` / `params['data_base64']` / `params['conversation_id']` / `params['recipient_id']`, not full JSON.
- **`MixinBot::API::Blaze#blaze_send_*` only depend on `MixinBot::API::Message#write_ws_message`** — testable offline by stubbing the socket with `FakeSocket` that records `.send(bytes)`.
- **`MixinBot.api.ws_message(bytes)` is the inverse of `write_ws_message`** — gzip-decode the captured bytes back to JSON for assertions.
- **Do NOT retry `create_pull_request` more than once for same content** — repeated silent failures are documented (now FIVE times: #162, #165, #166, #170, this run).

## Decisions this run (2026-07-02, 05:35 UTC)

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

- **RETRY: `Blaze` test coverage** — fourth silent `create_pull_request` failure this run. The content is committed locally at `repo-assist/test-blaze-2026-07-02-3f8a` (`e0919db`), bundle + patch persisted. 18 tests, 58 assertions all pass offline.
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
- **Do not retry `create_pull_request` more than once** for same content — repeated silent failures are documented (now FIVE cases: #162, #165, #166, #170, 2026-07-02).
- **Do not call `assert_raises(ArgumentError)` (unqualified) inside `module MixinBot`** when production raises custom `MixinBot::ArgumentError`.
- **Do not use `WebMock.after_request` for request body capture** — use `to_return do |request|` block.
- **Do not assume `CGI.escape` encodes spaces as `%20`** — encodes as `+`. `URI.encode_www_form_component` encodes as `%20`.
- **Do not assume a `create_pull_request` call published a PR** — always verify the branch exists at start of next run before relying on the PR number. `safeoutputs create_pull_request` can silently drop the PR (this is now the **fifth** documented case).
- **Do not assume `safeoutputs update_issue` / `create_issue` / `add_comment` wrote successfully just because the tool reported "success"** — verify with `issue_read` or `list_issues` if downstream code depends on it.
- **`write_ws_message` produces signed bytes via `unpack('c*')`** — second gzip-magic byte is `-117`, not `0x8b`.
- **Two envelopes with same payload have different envelope/message UUIDs** — `blaze_send_post` vs `blaze_send_plain_text` content-equivalent but envelope-distinct.