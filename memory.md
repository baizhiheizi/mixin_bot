---
name: repo-assist-memory
description: Persistent state for Repo Assist runs on baizhiheizi/mixin_bot
metadata:
  type: project
---

# Repo Assist Memory — baizhiheizi/mixin_bot

## Current state (as of 2026-06-28 14:45 UTC)

- **Repo activity**: predominantly automated workflows. Last human contributor commit (an-lee): 2026-06-25.
- **CI is GREEN on `main`** (HEAD `a5598c0` — `perf: cache bytes.pack in encoder to avoid duplicate allocation (#158)`).
- **Open issues**: 19 — 18 automated workflow-tracking + Monthly Activity (#99). 0 unlabelled.
- **Open PRs**: 2 Repo Assist drafts — #159 (`perf-nfo-invoice-concat-2026-06-27`) + new PR (`perf-encrypted-message-and-registry-concat-2026-06-28`, number not yet visible — propagation lag).
- **Recent merges by an-lee**: 2026-06-25 batch (#138, #141, #142, #148) + 2026-06-26 (#152, #154, #156) + 2026-06-27 (#158).
- **Monthly Activity issue**: [issue #99](https://github.com/baizhiheizi/mixin_bot/issues/99) for 2026-06. Updated this run with the encrypted-message PR placeholder and a `Check comment` for #114.
- **Test coverage progress**: 9 merged (#117, #123, #126, #131, #141, #142, #148, #152, #156). `blaze.rb` remains untested (EventMachine-heavy; deferred).
- **Ruby 4.0 audit (resolved)**: `legacy_user.rb` fixed in PR #148 (merged).
- **Performance sweep status**: PR #138 (transaction `bytes.concat`, 2.7×) merged. PR #158 (`bytes.pack('C*')` cache) merged. PR #159 (nfo + invoice concat) draft. New PR (`bf498ea`, encrypted-message + mvm/registry concat) draft. **All currently-known `bytes += X` O(n²) sites migrated.**

## Backlog cursor

- **Task 2 cursor**: 0 — #114 commented this run (recommend close). Other open issues are auto-generated workflow trackers (per anti-pattern, no engagement).
- **Task 3 cursor**: 0 — no user-reported bugs.
- **Task 4 cursor**: empty — Dependabot-managed and up-to-date; no open Dependabot PRs.
- **Task 5 cursor**: 9 merged. Only `blaze.rb` remains untested.
- **Task 8 cursor**: PR #138 + #158 + #159 + new PR (`bf498ea`) merged/draft. **No further high-leverage perf sites identified** — the `bytes += X` pattern has been eliminated across all known encoders.

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

- **Test coverage sweep**: 10 merged. `blaze.rb` deferred (EventMachine). The coverage gap is now small.
- **Performance follow-up**: `lib/mixin_bot/api/encrypted_message.rb` (6 sites) + `lib/mvm/registry.rb` (3 sites) for the same `bytes += X` pattern. Smaller buffers, lower value. The dominant encoder cost (`bytes.pack('C*')` in `utils/encoder.rb`) is now cached via #158.
- **2.3.1 release preparation** overdue: `sha3` upgrade from #84 + Lean Squad removal #129 still in `[Unreleased]`. #114 (protected-files docs bump) was resolved by manual PR #128. CHANGELOG would need a `2.3.1` section but that requires touching a protected file.
- **Protected-files PR-push workaround** affects four workflows (README/AGENTS/CLAUDE/CHANGELOG). Root cause of #114 (still open — recommend close now that #128 landed).
- **PR creation propagation lag**: GitHub MCP API can lag behind `create_pull_request` success for ~1 run. This run's PR (`perf-nfo-invoice-concat-2026-06-27`) may not be visible until next run.

## Decisions / substitutions this run (2026-06-27, 14:25 UTC)

- Selected tasks: 2, 4, 10. Tasks 2 + 4 were no-action (all 17 open issues are auto-generated `agentic-workflows` trackers; Dependabot-managed and up-to-date with no open PRs). Task 10 produced a focused performance PR.
- Created PR `repo-assist/perf-nfo-invoice-concat-2026-06-27` (`14415bd`) — 30 `bytes += X`→`bytes.concat(X)` / `bytes.push(literal)` / `bytes << literal` conversions across `lib/mixin_bot/nfo.rb` (19 sites) and `lib/mixin_bot/invoice.rb` (11 sites). Follows the same pattern as #138; byte-for-byte equivalent; verified by replaying the exact encode patterns in a standalone Ruby script. **Visible as PR #159.**

## Decisions / substitutions this run (2026-06-28, 14:45 UTC)

- Selected tasks: 2, 4, 8. Task 2 produced a single comment on #114 (verifying PR #128 already landed the docs bump); Task 4 was no-action (Dependabot-managed, no open Dependabot PRs); Task 8 produced a final perf PR that closes out the `bytes += X` migration across the codebase.
- Created PR `repo-assist/perf-encrypted-message-and-registry-concat-2026-06-28` (`bf498ea`) — 9 `bytes += X`→`bytes.concat(X)` conversions across `lib/mixin_bot/api/encrypted_message.rb` (6 sites in `encrypt_message`) and `lib/mvm/registry.rb` (3 sites in `contract_from_multisig`). Same pattern as #138 / #159; byte-for-byte equivalent; verified by standalone Ruby equivalence script across 6 input combinations. Microbench (Ruby 4.0.5, 100,000 iters): `EncryptedMessage#encrypt_message` 0.571s→0.509s (**1.12×** — scales with session count); `MVM::Registry#contract_from_multisig` 0.230s→0.237s (neutral at ~70 B buffer — included for consistency only, removes O(n²) footgun). Number not yet visible in MCP API (propagation lag).
- **Performance sweep status**: With #138, #158, #159, and this run's PR, all currently-known `bytes += X` O(n²) sites in encoders have been migrated to `Array#concat` / `Array#<<`. **No further high-leverage perf sites identified.** The dominant remaining encoder cost (`bytes.pack('C*')` cache in `utils/encoder.rb`) is already cached via #158.
- Open PRs: 2 Repo Assist drafts (#159 + #aw_enc_msg). PR #159 awaiting first-time `pull_request` workflow approval for `repo-assist/*` branches.
- Commented on #114 (`aw_A6Ayf9Jo`) — verified all four target files (`README.md`, `CLAUDE.md`, `AGENTS.md`, `llms.txt`) are at 2.3.0, confirming #128's work; recommend close.
- #114 should be closed: PR #128 (merged 2026-06-20) already landed the docs version bump that #114 proposed. Will be added to Suggested Actions in the Monthly Activity update.

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
