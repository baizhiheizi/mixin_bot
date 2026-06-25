---
name: repo-assist-memory
description: Persistent state for Repo Assist runs on baizhiheizi/mixin_bot
metadata:
  type: project
---

# Repo Assist Memory — baizhiheizi/mixin_bot

## Current state (as of 2026-06-25 16:30 UTC)

- **Repo activity**: predominantly automated workflows. Last human contributor commit (an-lee): 2026-05-27.
- **CI is GREEN on `main`** (PR #133 + #131 merged in `4a95f97` + `2091e40`; recent run on `main` was `e2825aa`).
- **Open issues**: 19 — 18 automated workflow-tracking + Monthly Activity (#99).
- **Open PRs**: 5 visible (#138 perf encoder, #141 test inscription, #142 test multisig, #145+#146 superseded by `repo-assist/fix-pr145-pr146-2026-06-24`) + 1 awaiting propagation (`repo-assist/test-small-modules-2026-06-25`).
- **Monthly Activity issue**: [issue #99](https://github.com/baizhiheizi/mixin_bot/issues/99) for 2026-06 (active; updated this run).
- **Test coverage progress**: 5 merged + 4 awaiting. Merged: `test_tip.rb` (#117), `test_chain.rb` (#123), `test_output.rb` (#126), `test_legacy_collectible.rb` (#131), rename fix (#133). Awaiting: #141, #142, `repo-assist/fix-pr145-pr146-2026-06-24` (supersedes #145+#146), `repo-assist/test-small-modules-2026-06-25` (this run, 250 lines / 27 assertions covering 6 modules).
- **Ruby 4.0 audit (this run)**: grep-confirmed `legacy_user.rb` was the only file with the broken `oaep_label:` keyword form; fix already in `repo-assist/fix-pr145-pr146-2026-06-24`. `pin.rb` uses `JOSE::PKCS1.rsaes_oaep_decrypt` (not affected). No further audit work needed.

## Backlog cursor

- **Task 2 cursor**: 0 — all open issues reviewed; no comment-worthy items this run.
- **Task 3 cursor**: 0 — no user-reported bugs.
- **Task 4 cursor**: empty — no actionable dependency updates, CI gaps, or build improvements identifiable. Dependabot PR Bundler workflow already handles deps; CI is lean with `bundler-cache: true`.
- **Task 5/9 cursor**: 5 merged + 4 awaiting. Remaining untested modules: `blaze` (144 lines, EventMachine-heavy), `computer_api` (60 lines, delegates to `MixinBot::Computer`). The smallest 6 (`address`, `deposit`, `fiat`, `pin_payload`, `session`, `turn`) are now covered by `test_small_modules.rb`.
- **Task 8 cursor**: PR #138 awaiting. Next opportunity: `bytes.pack('C*')` calls at lines 40-41 of `encoder.rb`. Alternative: extend `bytes.concat` to `nfo.rb` (16 sites) and `invoice.rb` (10 sites).

## Decisions / substitutions this run (2026-06-25, 16:30 UTC)

- Selected tasks: 10, 5, 2. Task 5: created `repo-assist/test-small-modules-2026-06-25` — `test/mixin_bot/api/test_small_modules.rb` (250 lines, 27 assertions) covering 6 small modules. Task 10: forward pass — Ruby 4.0 audit grep. Task 2: no action (no user-reported issues).
- Test file follows `test_network.rb` pattern: `WebMock.reset!` + `MixinApiStubs.register!` in setup, all default-stub endpoints (no new stub routes), `MixinBot.api.send(:private_method, ...)` for `tip_or_legacy_pin_payload`.
- RuboCop run locally blocked by missing `rubocop-rake` plugin; CI will exercise both `rake test` and `rake rubocop` on Ruby 3.2 / 3.3 / 4.0.
- `bundle install` firewall-blocked; syntax check via `ruby -c` passes for the new test file.

## Forward work candidates

- **Test coverage sweep**: continue. Priority order: `address.rb` (one-line String→Array coercion worth pinning), `pin_payload.rb` (private `tip_or_legacy_pin_payload` raises ArgumentError on blank pin, branches on pin length), then `fiat.rb`, `turn.rb`, `session.rb`, `deposit.rb`, `payment.rb`, `code.rb`. Larger: `blaze.rb`, `computer_api.rb`.
- **Performance follow-up**: `bytes.pack('C*')` at lines 40-41 of `encoder.rb`. String buffer refactor would be much larger.
- **2.3.1 release preparation** overdue: `sha3` upgrade from #84 + Lean Squad removal #129 still in `[Unreleased]`. Docs-updater issues (#114, #134, #137) want bullets for 2.3.1.
- **PR creation propagation lag**: keep noting — GitHub MCP API lags behind `create_pull_request` success.
- **Protected-files PR-push workaround** affects four workflows (README/AGENTS/CLAUDE/CHANGELOG). Root cause of #114, #134, #137.

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