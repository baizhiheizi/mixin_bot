## 1. Foundation: railtie, entry point, multi-bot registry

- [x] 1.1 Create `lib/mixin_bot/rails.rb` that requires the integration layer only when Rails/Railties is present and raises a clear error naming the missing dependency otherwise; verify with a test that `require 'mixin_bot'` loads no Rails code and that `require 'mixin_bot/rails'` without Rails raises the named error (rails-integration spec: "Opt-in Rails loading")
- [x] 1.2 Implement the railtie (`lib/mixin_bot/rails/railtie.rb`): generator path registration, convention eager-load hooks (`app/mixin/handlers`, `app/mixin/processors`), and the `mixin_bot:poller` rake task skeleton; verify a dummy Rails app boots with the railtie and lists the rake task
- [x] 1.3 Implement `MixinBot.register_bot` / `MixinBot.bot(name)` returning frozen per-name API clients while `MixinBot.api` keeps default-credential behavior; verify with unit tests that two registered bots hold separate configs and that the default singleton is unchanged
- [x] 1.4 Add Rails (and a dummy app harness) to the development/test group only; verify `rake` (offline suite + RuboCop) passes and the gemspec gains no runtime dependency

## 2. Blaze message router

- [x] 2.1 Implement `MixinBot::Blaze::Router` as a callable that plugs into `config.blaze_handler`: DSL `on` matching action and normalized category, first-match-wins dispatch, unmatched envelopes logged and ignored; verify with unit tests covering dispatch, precedence, and the unmatched case (blaze-message-router spec: "Route messages to handlers via a DSL")
- [x] 2.2 Implement the `Message` wrapper (decoded data with lazy JSON parsing, category/action/conversation/message/user ids, raw envelope) and `Handlers::Base#reply` sending via the HTTP message API; verify with WebMock tests that reply issues `POST /messages` with the bot's client and correct category (specs: "Handlers receive a decoded message object", "Handlers can reply over HTTP")
- [x] 2.3 Verify router instances bound to different `api:` clients send replies with their own credentials, and handler exceptions are contained exactly as the reactor contains them (specs: "Routing is bound to a bot API client", reactor error behavior)
- [x] 2.4 Build `rails g mixin_bot:blaze`: initializer with routes block + example handler, `plugin :mixin_blaze` injection into `config/puma.rb` when absent; verify generated files exist, re-run duplicates nothing, and generated-code tests mirror the authentication generator's module (spec: "Blaze generator scaffolds routing")

## 3. Outputs poller

- [x] 3.1 Implement `MixinBot::Outputs::Envelope` (BigDecimal amount, asset id, spent?, transaction hash/index, receipt back-reference) with the lazy snapshot bridge via `create_safe_snapshot_notification`, memoized per output and nil-on-failure with a warning; verify with WebMock tests for first-fetch, memoization, and bridge-failure tolerance (spec: "Output envelope bridges to snapshot data")
- [x] 3.2 Implement the receipts model contract (bot app id + unique output id, snapshot/memo cache columns, `enqueued_at`) and the cursor store keyed by `app_id`; verify migration-free unit tests of record-or-skip semantics and cursor advance rules (specs: "Receipts deduplicate outputs", "Cursor advances per bot and survives restarts")
- [x] 3.3 Implement `MixinBot::Outputs::Poller` loop: page fetch ASC from cursor, transactional receipt insert + predicate evaluation + enqueue + `enqueued_at` mark per output, page-atomic cursor advance, startup sweep of un-enqueued receipts, injectable `sleeper`/`api`/clock, SIGTERM/SIGINT graceful stop; verify with WebMock + injected-sleeper tests covering page processing, mid-page failure re-fetch, re-fetch overlap dedup, and restart-from-cursor (specs: "Standalone polling loop process", "Cursor advances per bot and survives restarts", "Receipts deduplicate outputs")
- [x] 3.4 Implement processor discovery (`app/mixin/processors` eager-load) and `MixinBot::Outputs::ProcessingJob` (ActiveJob base rehydrating the envelope from the receipt); verify tests that matching processors enqueue per match, no-match records only, and queue payloads carry receipt id + processor name only (spec: "Predicate processors dispatch through the job queue")
- [x] 3.5 Wire the `mixin_bot:poller` rake task to boot the app and run the poller for the default or named bot; verify the task starts, polls, and stops on SIGTERM in the dummy app (specs: "Standalone polling loop process", "Poller for a named bot")
- [x] 3.6 Build `rails g mixin_bot:outputs`: receipts + cursor migrations, example processor, poller documentation; verify generated migration runs, re-run duplicates nothing, and the generated example processor processes a stubbed first payment end-to-end in tests (spec: "Outputs generator scaffolds the receipts store and an example processor")

## 4. Outbound transfers

- [x] 4.1 Implement `MixinBot::Transfers::Model` concern: state enum (`pending`/`broadcast`/`confirmed`/`failed`/`reconciling`), trace id uniqueness, audited `transition_to!`, `perform!`/`reconcile!` entry points; verify unit tests of every legal/illegal transition and outcome recording (spec: "Transfer state machine")
- [x] 4.2 Implement `MixinBot::Transfers::Performer` over the existing Safe pipeline with the bound bot's api, mapping definitive errors to `failed` and post-submission network errors to `reconciling`; verify with WebMock tests for the three outcome classes, including transaction hash capture (specs: "Transfer records drive sending", "Transfer state machine")
- [x] 4.3 Implement `MixinBot::Transfers::Reconcile`: snapshot lookup by trace id resolving `reconciling` to `confirmed` or re-sending the same trace id; verify with WebMock tests for both resolutions and that no path double-sends (spec: "Trace id idempotency and reconciliation")
- [x] 4.4 Build `rails g mixin_bot:transfers`: transfers migration (recipient, asset id, amount, memo, unique trace id, state, transaction hash, error), model including the concern, thin `PerformJob`, SolidQueue recurring entry for reconciliation; verify migration + model + job generate, re-run duplicates nothing, and a stubbed round-trip ends `confirmed` with its hash (spec: "Transfers generator scaffolds the ledger")

## 5. Notifications

- [x] 5.1 Implement `MixinBot::Notifications::MixinChannel` (guarded load on `defined?(Noticed)`, recipient + message params from the notification, send via HTTP message API, per-delivery error capture per Noticed's contract); verify with tests under a Noticed double: delivery sends, failure records without raising, and requiring the integration layer without Noticed neither raises nor loads the channel (specs: "Mixin delivery channel for Noticed", "Channel loads only with Noticed")
- [x] 5.2 Build `rails g mixin_bot:notifications`: add `noticed` to the host Gemfile when absent, install the channel, generate an example notification; verify idempotent re-run and a stubbed round-trip delivery (spec: "Notifications generator scaffolds an example")

## 6. Install generator and release

- [x] 6.1 Build `rails g mixin_bot:install` composing authentication, blaze, outputs, transfers, notifications with per-generator skip flags; verify in the dummy app that a full install boots, a selective install (`--skip notifications --skip transfers`) generates only the rest, and double install duplicates nothing (specs: "Install generator composes the others")
- [x] 6.2 Update README (integration layer section: require, install command, per-component quickstart) and CLAUDE.md architecture notes; verify `rake rdoc` builds and docs mention the new entry point
- [x] 6.3 Full verification sweep: `rake` green (offline suite + RuboCop), `rake mixin_bot:api_coverage` unchanged, generator idempotency suite green in the dummy app; confirm gemspec runtime dependencies unchanged before version bump
