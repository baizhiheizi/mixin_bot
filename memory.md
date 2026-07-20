---
name: repo-assist-memory
description: Persistent state for Repo Assist runs on baizhiheizi/mixin_bot
metadata:
  type: project
---

# Repo Assist Memory — baizhiheizi/mixin_bot

## Current state (as of 2026-07-20)

- **CI on `main`** GREEN at `d9e7ea1` (Merge branch 'main' of https://github.com/baizhiheizi/mixin_bot). Latest commit `8576a0a` "bump v2.4.0" — maintainer landed the protected-files version bump manually (AGENTS.md still references `v2.3.0`; can only be fixed via maintainer workaround).
- **Version**: `lib/mixin_bot/version.rb` → `VERSION = '2.4.0'`; CHANGELOG.md `## [2.4.0] - 2026-07-20` includes Blaze User-Agent (#183-area b63b680), sha3 2.x upgrade, safe_pay_url scientific-notation fix (#176), and 2 perf PRs (#158, #159 area). **The "2.3.1 release" pending action is now stale — it shipped as 2.4.0.**
- **Open issues**: 7 — 0 unlabelled. 4 `[aw]` workflow trackers (#190 Repo Assist failed, #189 Documentation Updater failed, #188 Repo Assist failed, #187 Agentic Wiki Writer failed), 2 `[aw]` aggregator issues (#112 No-Op, #90 Detection), and #169 (Monthly Activity). All workflow-tracker issues are auto-generated; skip per anti-pattern.
- **Open PRs**: 0. 0 Dependabot alerts. 0 code-scanning analyses.
- **Issue #114 closed** 2026-07-10 05:57 UTC by `@an-lee` (`completed`).
- **Test coverage**: comprehensive — every module under `lib/mixin_bot/api/` has a test file (single-method modules via `test_small_modules.rb`). 13 test PRs this cycle (#117, #123, #126, #131, #141, #142, #148, #152, #156, #167, #168, #171, #172).
- **Performance sites**: exhausted (#138, #158, #159, #163).
- **Bug fixes landed**: PR #176 (safe_pay_url scientific notation).
- **Selected tasks** at run 29753015350: 3, 5, 2. All no-action.

## Cursors

- **Task 2**: 0 — #114 (last user-facing issue) closed by maintainer. No other user-facing open issues.
- **Task 3**: 0 — no user-reported bugs.
- **Task 4**: empty — Dependabot-managed, CI clean.
- **Task 5**: rdoc density is uniform-zero across `lib/mixin_bot/api/*.rb` (10/41 modules). Borderline noise.
- **Task 8**: `bytes += X` all migrated. `bytes.pack('C*')` cached in `transaction/encoder.rb:36` and `lib/mixin_bot/nfo.rb:98-100` reuses `@raw`.

## Recent runs

- **2026-07-20** (run 29753015350) — Selected: 3, 5, 2. All no-action. Task 3 no user-reported bugs; Task 5 no clearly beneficial improvement (test coverage comprehensive, perf exhausted, AGENTS.md version drift is protected file); Task 2 no user-facing issues. **Detected state delta**: 2.4.0 released (2.3.1 suggestion now stale); 4 new Dependabot PRs merged (#183 #184 #185 #186); 4 new `[aw]` workflow-failure issues opened (#190 #189 #188 #187). Task 11: `add_comment` on #169 — refreshed Suggested Actions to remove stale 2.3.1 goal. CI green at `d9e7ea1`.
- **2026-07-16** (run 29508234630) — Selected: 1, 4, 2. All no-action. Task 1 fallback to Task 2 (0 unlabelled); Task 2 no user-facing issues; Task 4 Dependabot-managed, 0 open PRs, 0 alerts. Task 11: `add_comment` on #169 (`aw_p9IMIr6C`) — refreshed Suggested Actions to remove closed-#114. CI green at `1f4c967`.
- **2026-07-14** (run 29341110852) — Selected: 8, 10, 3. All no-action. Reconfirmed perf exhaustion via grep; forward candidates still blocked (CHANGELOG protected, UrlScheme quirks intentional); no fixable user-reported issues. Task 11: `add_comment` on #169 (`aw_1vbUEQX4`). Detected: #114 closed by maintainer.
- **2026-07-11** (run 29155709210) — Selected: 5, 3, 4. All no-action. rdoc gap borderline.
- **2026-07-09** (run 29030966288) — Selected: 10, 2, 3. All no-action. Confirmed PR #176 merged.
- **2026-07-04** (run 28694823573) — Selected: 3, 8, 2. Task 3 produced PR #176 (scientist→fix payment scientific notation).
- **2026-07-02 15:25** (run 28599951608) — Task 9: payment-test branch (e6d0956) → published as PR #172, merged 2026-07-03. Sixth silent failure recovered.
- **2026-07-02 05:35** (run 28566120129) — Task 9: blaze-test branch (e0919db) → published as PR #171, merged 2026-07-03. Fifth silent failure recovered.
- **2026-07-01 05:29** (run 28495123814) — Task 5: 45 tests (BotAuth + UrlScheme) → published as PRs #167 + #168, merged.
- **2026-06-28** — Selected: 2, 4, 8. Task 2 commented on #114; Task 8 produced PR #163 (perf).
- **2026-06-27** — Selected: 2, 4, 10. Task 10 produced PR #159 (perf).
- **2026-06-25** — PR #152 (test_small_modules.rb, 27 assertions) merged. PR #148 merged.
- **2026-06-22** — PR #138 (`bytes += X` migration, 70 sites) merged 2026-06-25.
- **2026-06-16** — Created Monthly Activity #99.

## Forward work candidates

- **2.3.1 release prep**: `sha3` (#84) in `[Unreleased]`; 4 perf + 13 test + 1 fix PRs merged since 2.3.0. Requires protected-files workaround for `CHANGELOG.md` + `VERSION`.
- **Stale branch cleanup** (optional): `repo-assist/{fix-pr145-pr146,test-legacy-user,test-network}-2026-06-24-*` likely merged into `main` via #167/#168 area.
- **UrlScheme quirks**: `params: {action:}` overrides + double-encoded `data` are intentional (matches Go, pinned in `test_url_scheme.rb`).

## Anti-patterns

- **`MixinBot::API::Payment#safe_pay_url` scientific-notation bug** — FIXED in main via PR #176 (`da25d87`): `format('%.8f', amount.to_d.to_r).gsub(/\.?0+\z/, '')` mirroring `build_safe_recipient`.
- **Test `trace:`-vs-`trace_id:` typo** — pinned by `test_safe_pay_url_does_not_pass_unknown_kwargs_through`. Method reads `kwargs[:trace_id]`; `trace:` silently ignored.
- **`update_issue` on #169 intermittently silently fails** — verified runs 28566120129, 28599951608, 28694823573, 29030966288, 29155709210. Recovery: post consolidated run history via `add_comment`.
- **rdoc density uniformly near-zero** across `lib/mixin_bot/api/*.rb` — `blaze.rb` (0/144), `auth.rb` (0/105), `tip.rb` (0/116), `legacy_collectible.rb` (0/139). Targeting only `blaze.rb`/`message.rb` would be inconsistent.
- **`bundle install` fails in repo-assist sandbox** with HTTP 403 from rubygems.org (verified at run 29155709210). No local `rake test`; rely on CI.
- **Protected-files wall** — `update_issue`/`create_pull_request` rejected for AGENTS.md, CLAUDE.md, README.md, CHANGELOG.md, lib/mixin_bot/version.rb (and likely others). Maintainer workaround only. Verified when issue #114's intended-PR was blocked.
- **`create_pull_request` silent failures** — SEVEN+ documented cases. THREE eventually published (PRs #171, #172, #176) in subsequent runs. Pattern: silent failure is recoverable in 1–5 runs; always check if prior content has published before re-creating. Do not retry more than once for same content.
- **`safeoutputs` write verification** — does NOT always mean publish. Confirm with `issue_read`/`list_pull_requests` if downstream code depends on it.

## Standing anti-patterns (do-not)

- Do not comment on `github-actions[bot]`-generated issues.
- Do not duplicate Lean Squad output.
- Do not bump action versions in dormant `lean-ci.yml`.
- Do not bundle CHANGELOG/version bump into docs-only PR.
- Do not attempt another PR touching AGENTS.md/CLAUDE.md/README.md/CHANGELOG.md via `create_pull_request` until protected-files workaround.
- Do not retry `create_pull_request` more than once for same content; if failed, wait 1–5 runs and verify.
- Do not call `assert_raises(ArgumentError)` unqualified inside `module MixinBot` — production raises `MixinBot::ArgumentError`.
- Do not use `WebMock.after_request` for request body capture — use `to_return do |request|` block.
- Do not assume `CGI.escape` encodes spaces as `%20` (it's `+`). `URI.encode_www_form_component` encodes as `%20`.
- Do not give up on silent-push branches — they may publish 1–5 runs later.
- Do not assume safeoutputs update_issue / create_issue / add_comment wrote successfully just because tool reported "success" — verify with `issue_read` if downstream depends on it.
- `write_ws_message` produces signed bytes via `unpack('c*')` — second gzip-magic byte is `-117`, not `0x8b`.
- Two envelopes with same payload have different envelope/message UUIDs (`blaze_send_post` vs `blaze_send_plain_text`).
- `scheme_apps` `params: { action: }` overrides the `action:` kwarg — intentional, matches Go. Pinned in `test_url_scheme.rb:198-211`.
- `scheme_send` double-encodes `data`: `Base64.strict_encode64` → `URI.encode_www_form_component` → `URI.encode_www_form`. Round-trip via `URI.decode_www_form` → `URI.decode_www_form_component` → `Base64.strict_decode64`. Pinned in `test_url_scheme.rb:241-258`.
