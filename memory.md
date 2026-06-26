---
name: repo-assist-memory
description: Persistent state for Repo Assist runs on baizhiheizi/mixin_bot
metadata:
  type: project
---

# Repo Assist Memory — baizhiheizi/mixin_bot

## Current state (as of 2026-06-26 04:51 UTC)

- **Repo activity**: predominantly automated workflows. Last human contributor commit (an-lee): 2026-06-25.
- **CI is GREEN on `main`** (HEAD `e2825aa`).
- **Open issues**: 17 — 16 automated workflow-tracking + Monthly Activity (#99).
- **Open PRs**: 2 — #152 (small-modules test draft), #154 (Dependabot github-actions group).
- **Recent merges by an-lee on 2026-06-25** (#138, #141, #142, #148 in 90s — all Repo Assist drafts).
- **Recent closes (not merged) on 2026-06-25**: #145 (superseded), #146 (superseded), #147 (superseded — re-cut as #148 and merged).
- **Recent closes (issues, not_planned)**: #134, #137 (docs-updater auto-generated).
- **Monthly Activity issue**: [issue #99](https://github.com/baizhiheizi/mixin_bot/issues/99) for 2026-06 (active; updated this run).
- **Test coverage progress**: 9 merged + 1 awaiting. Merged: `test_tip.rb` (#117), `test_chain.rb` (#123), `test_output.rb` (#126), `test_legacy_collectible.rb` (#131), rename fix (#133), `test_inscription.rb` (#141), `test_multisig.rb` (#142), `test_network.rb`+`test_legacy_user.rb`+`legacy_user.rb` Ruby-4.0 fix (#148), `lib/mixin_bot/transaction/encoder.rb` `bytes.concat` (#138). Awaiting: #152 (6 modules, 27 assertions).
- **Ruby 4.0 audit (resolved)**: `legacy_user.rb` fixed in PR #148 (merged). Grep confirmed only that file had the broken OpenSSL keyword form.

## Backlog cursor

- **Task 2 cursor**: 0 — all open issues reviewed; no comment-worthy items this run.
- **Task 3 cursor**: 0 — no user-reported bugs.
- **Task 4 cursor**: empty — no actionable dependency updates, CI gaps, or build improvements identifiable. Dependabot PR #154 now opened (4 github-actions updates incl. major `actions/cache` v6.0.0 ESM migration); auto-managed.
- **Task 5/9 cursor**: 9 merged + 1 awaiting. Remaining untested modules: `blaze.rb` (144 lines, EventMachine-heavy), `computer_api.rb` (60 lines, delegates to `MixinBot::Computer`). `legacy_user.rb` is now also covered via #146 + #148.
- **Task 8 cursor**: PR #138 merged. Next opportunity: `bytes.pack('C*')` at lines 40-41 of `encoder.rb`. `nfo.rb` (16 sites) and `invoice.rb` (10 sites) have the same `bytes += X` pattern.

## Decisions / substitutions this run (2026-06-26, 04:51 UTC)

- Selected tasks: 2, 1, 3. All three no-action: Task 1 (0 unlabelled), Task 2 (17 open issues all `agentic-workflows` trackers — per anti-pattern, no engagement), Task 3 (no `bug`/`help wanted`/`good first issue` labels).
- Updated Suggested Actions in #99: removed merged PRs #138, #141, #142; removed superseded/closed PRs #145, #146, #147; removed closed issues #134, #137; updated small-modules PR entry to reference #152 (now visible); added Dependabot PR #154.
- Memory updated: PR #148 outcome (re-cut of `fix-pr145-pr146-2026-06-24` branch with `-e756f51217a2fffe` suffix; original `-f9b54f10d1beb82d` suffix closed). `legacy_user.rb` Ruby 4.0 OpenSSL fix is now in `main`.

## Forward work candidates

- **Test coverage sweep**: continue. Priority order: `blaze.rb` (EventMachine-heavy, may need test-helper refactor), `computer_api.rb` (delegates to `MixinBot::Computer`). Smaller candidates already exhausted.
- **Performance follow-up**: `bytes.pack('C*')` at lines 40-41 of `encoder.rb`. String buffer refactor would be much larger and changes return types.
- **2.3.1 release preparation** overdue: `sha3` upgrade from #84 + Lean Squad removal #129 still in `[Unreleased]`. #134 + #137 docs-updater issues now closed.
- **Protected-files PR-push workaround** affects four workflows (README/AGENTS/CLAUDE/CHANGELOG). Root cause of #114 (still open).
- **Dependabot PR #154**: 4 github-actions updates including major `actions/cache` v6.0.0. Auto-managed; no repo-assist action.
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