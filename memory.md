---
name: repo-assist-memory
description: Persistent state for Repo Assist runs on baizhiheizi/mixin_bot
metadata:
  type: project
---

# Repo Assist Memory — baizhiheizi/mixin_bot

## Current state (as of 2026-06-29 06:05 UTC)

- **CI is GREEN on `main`** (HEAD `a5598c0` — `perf: cache bytes.pack in encoder to avoid duplicate allocation (#158)`).
- **Open issues**: 19 — all automated workflow trackers + Monthly Activity (#99). 0 unlabelled.
- **Open PRs**: 3 Repo Assist drafts — #159 (nfo+invoice perf), #163 (encrypted-message + mvm/registry perf), and a new test PR (number not yet visible — propagation lag).
- **Test coverage progress**: 9 merged (#117, #123, #126, #131, #141, #142, #148, #152, #156). Draft +46 tests for `BotAuth` + `UrlScheme` this run. `blaze.rb` remains untested.
- **Ruby 4.0 audit (resolved)**: `legacy_user.rb` fixed in PR #148.
- **Performance sweep**: PR #138 + #158 + #159 + #163 merged/draft. **All `bytes += X` sites migrated.**

## Cursors

- **Task 2 cursor**: 0 — #114 commented 2026-06-28 (recommend close). Others are auto-generated trackers.
- **Task 3 cursor**: 0 — no user-reported bugs.
- **Task 4 cursor**: empty — Dependabot-managed, up-to-date.
- **Task 5 cursor**: 9 merged test PRs; +1 draft this run (+46 tests).
- **Task 8 cursor**: All `bytes += X` migrated.

## Anti-patterns to avoid (additions this run)

- **Do not call `Integer(int, base)` with Ruby Integer as first arg** — only String parseable; bit PR #156.
- **Do not pass UUID strings to `Computer.user_id_to_bytes`** — production calls `Integer(uid, 10)` requiring String base-10.
- **`safeoutputs update_issue` body has 10 KB hard limit** — trim older run-history entries to stay under. Body for #99 is now ~8.4 KB.
- **`UrlScheme::scheme_send` double-encodes data**: `Base64.strict_encode64(data)` → wrapped in `URI.encode_www_form_component` (yields `aGVsbG8%3D`) → then `URI.encode_www_form(q)` percent-encodes the `%` to `%25`. Recovery needs `URI.decode_www_form_component` after the form decode.
- **`UrlScheme::scheme_apps` `:action:` is overridden by `params: { action: ... }`** because `{ action: kw }.merge(params)` collapses shared symbol keys. Caller-visible quirk — possibly worth focused bug-fix PR.
- **Do not require `require 'mixin_bot'` directly when unit-testing single files in this sandbox** — top-level `mixin_bot.rb` requires `lib/mvm.rb`, which requires `eth`. The `eth` gem activates deps that conflict with Ruby 4.0's bundled `bigdecimal`/`openssl`. Either stub `Kernel#require` to no-op `eth`, or `require` only the leaf module file (e.g. `require 'mixin_bot/bot_auth'`, `require 'mixin_bot/url_scheme'`).
- **For BotAuth tests, pre-populate the cache** — `Client#sign_request` short-circuits to the cached `shared_key` when present. The 32-byte pre-populated cache makes `sign_request` fully exercisable offline; the short-cache branch (< 32 bytes) is verified via `NotFoundError`.
- **For UrlScheme tests, assert actual encoded behaviour** — see double-encoding quirk above.

## Decisions this run (2026-06-29, 06:05 UTC)

- Selected tasks: 2, 4, 5. Task 2 + Task 4 no-action (auto-trackers; Dependabot managed). Task 5 produced focused test PR.
- Created PR `repo-assist/test-bot-auth-url-scheme-2026-06-29` (`927af9e`) — `test_bot_auth.rb` (21 tests) + `test_url_scheme.rb` (25 tests) = **46 new offline unit tests covering `BotAuth` + `UrlScheme`**. Follows the `test_chain.rb` / `test_small_modules.rb` pattern. Two subtle production quirks pinned down.
- Standalone Ruby verification (with the `eth` require stubbed): every assertion in both test files re-ran against the actual production modules. `MapCache` round-trips correctly; `sign_request` produces a signature whose Base64-urlsafe-decode prefix is `app_id.b` and tail is `HMAC-SHA256(shared_key, "<ts><method><uri><body>")`. `UrlScheme.scheme_*` builders produce URLs whose `URI.decode_www_form(query)` form recovers expected key/values. `scheme_send` data round-trip requires one `URI.decode_www_form_component` after the form decode. `scheme_apps` action precedence matches `Hash#merge` semantics.
- Open PRs: 3 Repo Assist drafts (#159, #163, in-flight test PR). #159 + #163 awaiting first-time `pull_request` workflow approval for `repo-assist/*` branches.
- Test coverage sweep: 9 merged + 1 in-flight (+46 tests). `blaze.rb` deferred.
- Updated Monthly Activity (#99): replaced `#aw_enc_msg` placeholder with concrete #163 (now visible); added new test PR placeholder (`#aw_test1`); kept #114 → recommend close; kept the 2.3.1 release goal. Trimmed older run-history entries to stay under the 10 KB `update_issue` limit.

## Previous decisions (2026-06-28)

- Selected tasks: 2, 4, 8. Task 2 commented on #114; Task 4 no-action; Task 8 produced PR #163 (`bf498ea`) — 9 `bytes += X`→`bytes.concat(X)` across `encrypted_message.rb` + `mvm/registry.rb`. 1.12× speedup for `encrypt_message`, neutral for `contract_from_multisig`. **Performance sweep complete.**

## Previous decisions (2026-06-27)

- Selected tasks: 2, 4, 10. Task 2 + Task 4 no-action; Task 10 produced PR #159 (`14415bd`) — 30 mechanical `bytes += X`→`bytes.concat/push/<<` in `nfo.rb` + `invoice.rb`. ~1.1× speedup.

## Previous decisions (2026-06-26)

- Selected tasks: 9, 3, 2. Task 9 produced PR #156 (`test_computer_api.rb`, 18 assertions) — **merged 2026-06-27**. Tasks 2 + 3 no-action.

## Earlier history (2026-06-16 through 2026-06-25)

- **2026-06-25**: Task 5 produced PR #152 (`test_small_modules.rb`, 27 assertions) — **merged**. Task 10 forward-pass: PR #148 (Ruby 4.0 `legacy_user.rb` fix) **merged**.
- **2026-06-24**: Task 6 produced PR #148 — **merged**. Tasks 9 + 5 produced #145 + #146 (both superseded by #148).
- **2026-06-23**: Task 9 produced PR #142 (`test_multisig.rb`) — **merged**. Task 8 produced PR #141 (`test_inscription.rb`) — **merged**.
- **2026-06-22**: Task 8 produced PR #138 (`bytes += X` migration in `Transaction::Encoder`, 70 sites) — **merged 2026-06-25**.
- **2026-06-20**: Task 3 produced PR #133 (`fix-rubocop-variable-number`) — **merged**.
- **2026-06-19**: Task 5 produced PR #123 (`test_chain.rb`) — **merged**. Task 10 produced PR #126 (`test-output-threshold-script`) — **merged**.
- **2026-06-18**: Task 9 produced PR #117 (`test-tip-bodies`) — **merged**. Task 5 created issue #114 (docs-version-bump, since superseded by manual PR #128).
- **2026-06-16**: Created Monthly Activity Summary issue #99.

## Forward work candidates

- **`blaze.rb` test coverage**: the only remaining untested API module; 144 lines, EventMachine-heavy.
- **2.3.1 release preparation**: `sha3` + Lean Squad removal in `[Unreleased]`; 5 PRs (#138, #158, #159, #163, in-flight test PR) unreleased. Requires protected-files workaround.
- **Two `UrlScheme` quirks noted in the new test PR** (see anti-patterns): worth focused bug-fix PRs after maintainer review.
- **Documentation gap**: `lib/mixin_bot/api/blaze.rb` has minimal rdoc on the websocket-message encoder methods.
- **Consider splitting `lib/mixin_bot/api/message.rb`** — at 211 lines it mixes HTTP-push (`send_message`), pull/ack (`acknowledge_message`), WebSocket encoder (`write_ws_message` / `ws_message`), and message-build helpers (`plain_text`, `plain_image`, etc.). The WebSocket encoder pair belongs naturally with `Blaze`.

## Standing anti-patterns

- Do not comment on `github-actions[bot]`-generated issues.
- Do not duplicate Lean Squad output (#129 removed it).
- Do not bump action versions in dormant `lean-ci.yml`.
- Do not bundle CHANGELOG/version bump into docs-only PR.
- **Do not attempt another PR touching `README.md`, `AGENTS.md`, `CLAUDE.md`, or `CHANGELOG.md` via `create_pull_request`** until protected-files workaround in place.
- **Do not retry `create_pull_request` more than once for same content** — API can lag; double-creation is harder to clean up.
- **Do not call `assert_raises(ArgumentError)` (unqualified) inside `module MixinBot`** when production raises custom `MixinBot::ArgumentError`.
- **Do not use `WebMock.after_request` for request body capture** — class-level hook persists across tests. Use `to_return do |request|` block.
- **Do not assume `CGI.escape` encodes spaces as `%20`** — encodes as `+`. `URI.encode_www_form_component` encodes as `%20`.
- **Do not use `MixinBot.api.method(:x) == MixinBot.api.method(:y)` for alias equivalence** — cleaner pattern is calling both and asserting results match.
- **Do not use `WebMock.reset!` without `MixinApiStubs.register!` afterward**.
- **Do not push the same content under two branch suffixes for the same fix** — close the previous branch first.
- **For computer_api delegation tests, use the ComputerApi → MixinBot::Computer wiring pattern**.
