---
name: repo-assist-memory
description: Persistent state for Repo Assist runs on baizhiheizi/mixin_bot
metadata:
  type: project
---

# Repo Assist Memory — baizhiheizi/mixin_bot

## Current state (as of 2026-06-27 04:52 UTC)

- **Repo activity**: predominantly automated workflows. Last human contributor commit (an-lee): 2026-06-25.
- **CI is GREEN on `main`** (HEAD `1e43d36`).
- **Open issues**: 17 — 16 automated workflow-tracking + Monthly Activity (#99). 0 unlabelled.
- **Open PRs**: 2 Repo Assist drafts — #156 (computer_api tests, CI fix pushed this run) + perf-encoder-pack-cache PR (number not yet visible — propagation lag).
- **Recent merges by an-lee on 2026-06-25** (#138, #141, #142, #148 in 90s — all Repo Assist drafts).
- **Monthly Activity issue**: [issue #99](https://github.com/baizhiheizi/mixin_bot/issues/99) for 2026-06. Body could NOT be updated this run (10 KB safe-output limit + 1/1 update_issue quota exhausted by prior errored call). Run history added as comment (`temporary_id: aw_YvLmcFmC`). Next run should rebuild the body trimmed.
- **Test coverage progress**: 9 merged + 1 awaiting (#156, CI fix pushed this run). Only `blaze.rb` remains untested.
- **Ruby 4.0 audit (resolved)**: `legacy_user.rb` fixed in PR #148 (merged). Grep confirmed only that file had the broken OpenSSL keyword form.
- **Performance sweep status**: PR #138 (`bytes.concat` migration) merged. This run added a focused 1-line `bytes.pack('C*')` cache PR. The broader encoder/decoder String-buffer refactor still on hold.

## Backlog cursor

- **Task 2 cursor**: 0 — all open issues reviewed; no comment-worthy items this run.
- **Task 3 cursor**: 0 — no user-reported bugs.
- **Task 4 cursor**: empty — no actionable dependency updates, CI gaps, or build improvements identifiable. Dependabot-managed and up-to-date.
- **Task 5 cursor**: 9 merged + 1 awaiting (this run pushed PR #156 fix). Only `blaze.rb` (144 lines, EventMachine-heavy) remains untested in `lib/mixin_bot/api/`. Defer.
- **Task 8 cursor**: PR #138 merged. PR for `bytes.pack('C*')` cache opened this run (#aw_pack1). Next opportunity: `nfo.rb` (16 sites) and `invoice.rb` (10 sites) `bytes += X` patterns.

## Anti-patterns to avoid (additions this run)

- **Do not call `Integer(int, base)` with a Ruby Integer as the first arg** — only accepts String when base is given; raises `"base specified for non string value"`. Either omit the base for Integer input or coerce to String first. This bit PR #156's computer_user_id_to_bytes tests.
- **Do not pass UUID strings (e.g. `'7ed9292d-...-0186'`) to `Computer.user_id_to_bytes`** — production calls `Integer(uid, 10)` which requires String parseable as base-10. UUIDs aren't. Tests must use integer-ID strings like `'1'`.
- **`safeoutputs update_issue` body has 10 KB hard limit and 1-call-per-run quota** — the prior errored call counts against the quota. To avoid losing the run-history update entirely, post a comment as a fallback (issue #99 used this pattern this run). The next run should rebuild the body with trimmed older entries to stay under 10 KB.
- **Do not push a PR-touching fix to a branch that wasn't re-cut under the current run** — `push_to_pull_request_branch` works for any tracked PR's branch (verified this run with PR #156). No new branch needed; commits land on the existing `repo-assist/test-computer-api-2026-06-26-59c71141f22e9f0c` branch.

## Decisions / substitutions this run (2026-06-26, 15:33 UTC)

- Selected tasks: 9, 3, 2. Task 9 produced a new test PR. Tasks 2 and 3 were no-action (all open issues are auto-generated workflow trackers; no bug/help wanted labels).
- Created PR `repo-assist/test-computer-api-2026-06-26` (`f7160d7`) — 18 tests for `ComputerApi` (7 HTTP delegations stubbed against `computer.mixin.one`, plus 5 pure helper structural tests + 6 edge cases). Number not yet visible in MCP API (propagation lag, see anti-pattern).
- Updated Suggested Actions in #99: removed merged PRs #152, #154; added new test PR placeholder (`#aw_computer1`); test coverage sweep now 9 merged + 1 awaiting.

## Forward work candidates

- **Test coverage sweep**: 9 merged + 1 awaiting. `blaze.rb` deferred (EventMachine).
- **Performance follow-up**: `bytes.pack('C*')` at lines 40-41 of `encoder.rb`. String buffer refactor would be much larger and changes return types.
- **2.3.1 release preparation** overdue: `sha3` upgrade from #84 + Lean Squad removal #129 still in `[Unreleased]`. #134 + #137 docs-updater issues now closed.
- **Protected-files PR-push workaround** affects four workflows (README/AGENTS/CLAUDE/CHANGELOG). Root cause of #114 (still open).
- **PR creation propagation lag**: GitHub MCP API can lag behind `create_pull_request` success for ~1 run.

## Anti-patterns to avoid

- Do not comment on `github-actions[bot]`-generated issues.
- Do not duplicate Lean Squad output (#129 removed).
- Do not close auto-managed issues like #90.
- Do not bump action versions in dormant `lean-ci.yml` (#129 removed it).
- Do not re-propose duplicate-PR investigation (#95/#96 closed/merged).
- Do not bundle CHANGELOG/version bump into docs-only PR.
- **Do not attempt another PR touching `README.md`, `AGENTS.md`, `CLAUDE.md`, or `CHANGELOG.md` via `create_pull_request`** until protected-files workaround in place.
- **Do not retry `create_pull_request` more than once for same content** — API can lag; double-creation is harder to clean up.
- Do not add "Lean Squad Tier 3" goal to #99 — gone in #129. Use 2.3.1 release-prep instead.
- **Do not call `assert_raises(ArgumentError)` (unqualified) in tests inside `module MixinBot`** when production raises custom `MixinBot::ArgumentError` — Ruby resolves unqualified to custom class. Use `MixinBot::ArgumentError` explicitly for custom, `::ArgumentError` for bare Ruby.
- **Do not introduce `bytes <<` String-buffer optimization to `encoder.rb` as sweeping refactor** — changes return types of helpers and `encode_uint16/32/64`. If pursuing, focused separate benchmarked PR.
- **Do not use `WebMock.after_request` for request body capture** — class-level hook persists across tests. Use `to_return do |request|` block for per-stub local capture.
- **Do not assume `CGI.escape` encodes spaces as `%20`** — encodes as `+` (form-encoding). `URI.encode_www_form_component` encodes as `%20`.
- **Do not use `MixinBot.api.method(:x) == MixinBot.api.method(:y)` for alias equivalence** — cleaner pattern is calling both and asserting results match (`test_chain.rb` style).
- **Do not use `WebMock.reset!` without `MixinApiStubs.register!` afterward** — resets clear all stubs including the `any`-matcher fallback.
- **Do not push the same content under two branch suffixes for the same fix** — if a re-cut is needed, close the previous PR first. (`fix-pr145-pr146-2026-06-24` had two branches — `-f9b54f10d1beb82d` and `-e756f51217a2fffe` — both opened; the first was closed when the second merged.)
- **For computer_api delegation tests, use the ComputerApi → MixinBot::Computer wiring pattern** — the module is a thin pass-through, so asserting `MixinBot.api.foo == MixinBot::Computer.foo` is a stronger test than asserting request shape alone. Use WebMock to stub `https://computer.mixin.one/<path>` (no fallback stub exists in `MixinApiStubs`).
