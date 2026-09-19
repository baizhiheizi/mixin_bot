# Design — Rails integration layer

## Context

The gem already contains the connection-level hard parts: `MixinBot::Blaze::Reactor` (supervised fiber-based receive loop with backoff, keepalive, ack policies, serial dispatch), the `mixin_blaze` Puma plugin (fork/async hosting, SolidQueue-plugin pattern), and the `POST /messages` HTTP write path. The `mixin_bot:authentication` generator established the generator-side pattern (Rails 8 "generate code you own"). What is missing is everything between those primitives and application business logic.

The core architectural rule for this change (agreed during exploration):

> **Subtle code lives in the runtime** (idempotency, dedup, reconciliation, dispatch, connection lifecycle) — fix once, every project benefits. **Boring-but-app-shaped code is generated** (models, migrations, controllers, example handlers) — apps own and edit it. **Business decisions never enter the gem** — they live in application subclasses.

## Goals / Non-Goals

**Goals:**

- A new Mixin Rails project reaches "first message handled, first payment processed, first transfer sent" with `rails g mixin_bot:install` plus credentials.
- Runtime components testable offline with the existing WebMock + injectable-seam approach (mirror `Reactor`'s `sleeper`/`connection_factory` pattern).
- Multiple bots per application from day one via explicit API-client threading.

**Non-Goals:**

- No changes to `Reactor`, the Puma plugin contract, or the existing `blaze_handler` lambda path (router composes on top; the lambda stays the low-level contract).
- No new runtime gem dependencies for the gem itself (Rails and Noticed stay soft).
- No snapshot-polling alternative to output polling; no webhooks.
- No admin UI, no ledger reconciliation across bots, no MTG/multisig payment processing beyond what the existing pipeline supports.

## Decisions

### D1 — One optional entry point, railtie-based

`lib/mixin_bot/rails.rb` requires the railtie only under Rails; `require 'mixin_bot'` never touches it. The railtie registers the `mixin_bot:poller` rake task; generators stay under `lib/generators/` (Rails discovers them from gems already; the authentication generator proves this). The railtie class is `MixinBot::Railtie`, not `MixinBot::Rails` — a `MixinBot::Rails` constant lexically shadows `::Rails` for code inside `module MixinBot` (found the hard way: `CacheStoreAdapter`'s `Rails.cache` lookup broke); gem code now references `::Rails` outright and the integration avoids the colliding name. Convention directories (`app/mixin/handlers`, `app/mixin/processors`) need no railtie registration: Rails' default path inference already treats every `app/*` directory as a Zeitwerk root (namespace `Mixin`); eager loading is the poller process's job.

*Alternative*: separate `mixin_bot-rails` gem — rejected: solo maintainer, two release trains for every change; the Puma plugin already crossed into server-integration territory.

### D2 — Multi-bot registry, default bot preserved

`MixinBot.register_bot(name, **keystore)` returns a `MixinBot::API` bound to its own frozen `Configuration` (the API instance itself is not frozen: lazy `@session_store` memoization in the encrypted-message path would break). `MixinBot.bot(:name)` retrieves; `MixinBot.api` (existing singleton, default credentials) remains the default everywhere. Every integration component takes `bot:`/`api:` and defaults to `MixinBot.api`. This threads through router, poller, transfers, and notifications without touching SDK internals — `Reactor` already accepts `api:`.

### D3 — Router: thin dispatch over the existing handler contract

`MixinBot::Blaze::Router` is a callable (`#call(raw)`) so it plugs directly into `config.blaze_handler` / the Puma plugin with zero plugin changes. Internals:

- Routes match on **action** (e.g. `CREATE_MESSAGE`) and **message category** (`on 'text'` normalizes to `PLAIN_TEXT`; raw categories also accepted). First match wins; unmatched → debug log, no raise.
- `on` accepts any object responding to `#call` or a class name; classes are instantiated per message (stateless handlers, `Handlers::Base` subclass or plain object).
- `Message` wraps the envelope: decoded `data` (base64 → string, JSON-parsed lazily for structured categories), `category`, `action`, `conversation_id`, `message_id`, `user_id`, `raw`. `Handlers::Base` adds `reply(text, category: 'PLAIN_TEXT')` → `api.send_text_message` (HTTP, no socket).
- Multi-bot Puma hosting: the plugin gains an optional bot list (`mixin_blaze_bots :default, :shop`); one forked child runs N reactors in N threads. Phase-2 of the tasks; single-bot via `config.blaze_handler = router` works from day one.

### D4 — Poller: standalone rake task, page-atomic cursor, receipts with enqueue sweep

`bin/rails mixin_bot:poller [BOT_NAME]` boots the app and runs the loop (configurable interval, default 5s; page size 500 matching the API). Per fetch cycle:

```
fetch page (order ASC, offset = cursor)
  for each output:
    INSERT receipt (app_id, output_id) UNIQUE      <- dedup gate, inside txn
      on unique violation -> skip (already seen)
    evaluate processor predicates -> enqueue matching jobs
    mark receipt.enqueued_at
advance cursor to page's last output timestamp (only after full page processed)
```

- **Receipt store**: generated `mixin_outputs` table — `bot_app_id`, `output_id` (unique index on the pair), `transaction_hash`, `output_index`, `asset_id`, `amount`, `state`, `snapshot_id`, `memo` (caching the bridge result), `enqueued_at`, timestamps. The receipts double as an output ledger apps can join against.
- **Crash window** (receipt committed, enqueue not run): each loop start sweeps receipts with `enqueued_at IS NULL` older than one interval and re-enqueues. At-least-once enqueue; processors document they should be idempotent by `output_id` for full safety.
- **Cursor**: `mixin_poller_cursors` row per `app_id`; advance only after the whole page is recorded; mid-page failure re-fetches the page and receipts absorb the overlap.
- **Envelope**: `MixinBot::Outputs::Envelope` PORO — `amount` (BigDecimal), `asset_id`, `spent?`, `transaction_hash`, `output_index`, `memo`, `opponent_id`, `trace_id`, `receipt`. Memo/opponent/trace resolve lazily via `create_safe_snapshot_notification(transaction_hash:, output_index:, receiver_id: app_id)` (the existing SDK bridge), memoized, at most once per output, cached onto the receipt on first resolution. Bridge failure → nil fields + warn log, processing proceeds.
- **Processors**: convention directory `app/mixin/processors/`, eager-loaded by the railtie. Class-level `matches?(envelope)` + instance `#process(envelope)`; all matches enqueue (independent side effects), none match → record only. Dispatch enqueues `MixinBot::Outputs::ProcessingJob` (runtime-provided ActiveJob base; generated nil, referenced) with `[processor_name, receipt_id]` — jobs rehydrate the envelope from the receipt, so queue payloads stay small and memo caching survives job retries.

*Alternative considered*: SolidQueue recurring job instead of a standalone loop — rejected: the user's projects run the poller as its own supervised process; a loop also gives tighter polling than recurring-task granularity. Jobs still land in SolidQueue for actual processing.

### D5 — Transfers: generated model + runtime concern, trace-driven idempotency

- Generated `MixinTransfer < ApplicationRecord` includes `MixinBot::Transfers::Model`: state enum (`pending`, `broadcast`, `confirmed`, `failed`, `reconciling`), `trace_id` uniqueness validation, `transition_to!` (with `previous_state`, `transitioned_at` audit columns), and `perform!`/`reconcile!` entry points. Plain enum + validations, no state-machine gem.
- Runtime `MixinBot::Transfers::Performer` executes the existing Safe pipeline (`build_utxos` → `build_safe_transaction` → `verify_raw_transaction` → `sign_safe_transaction` → `send_safe_transaction`) with the bound bot's `api`, mapping outcomes:
  - definitive `ResponseError` (insufficient funds, bad request) → `failed` + error text; never retried by the job.
  - network/timeout errors **after** the send request was issued → `reconciling` (the indeterminate case).
  - success → `broadcast` + transaction hash; confirmation arrives via the outputs poller seeing the spend (or the send response's snapshot when present) → `confirmed`.
- Generated `MixinTransfers::PerformJob` is a thin ActiveJob wrapper around `record.perform!`; ActiveJob retry policy is safe because the trace id is fixed per record — network-side dedup absorbs duplicate sends.
- `MixinBot::Transfers::Reconcile` resolves `reconciling` records: query snapshot by `trace_id`; present → `confirmed` from the snapshot; absent → re-send same trace id (safe: absence proves no spend landed). Exposed as a recurring-task-ready callable; the generator emits a SolidQueue recurring entry.

### D6 — Noticed channel as a thin adapter

`MixinBot::Notifications::MixinChannel` wraps `Noticed`'s channel API (v2 `Noticed::Channel` shape): notification class supplies recipient id and message params; the channel sends via `api.send_message`. Loaded via `require` guarded by `defined?(Noticed)`. Channel code stays under ~50 lines — Noticed's API surface is the churn risk; isolation is the mitigation.

### D7 — Testing strategy

All offline: router/poller/transfer tests use WebMock stubs mirroring `test/support/mixin_api_stubs.rb` and injectable seams (poller takes `sleeper:`, `api:`; clock injection for cursor math). Poller tests never sleep. Generator tests assert file output and idempotency, mirroring the authentication generator's test module. Rails-dependent tests run against a minimal dummy app or plain railts-less harness consistent with how the authentication generator is tested today.

## Risks / Trade-offs

- [Noticed 2.x API churn breaks the channel] → keep the adapter minimal; pin nothing, feature-detect at load.
- [Snapshot bridge costs one POST per new output] → memoized per output and cached on the receipt; batch fetch is a future optimization if volume demands.
- [At-least-once enqueue means rare duplicate processor runs] → documented; receipts give processors a natural idempotency key.
- [One poller process is a single point of latency/failure] → process manager restarts it (same posture as the standalone Blaze processes it replaces); cursor makes restarts cheap.
- [Generated code drifts from runtime improvements] → accepted by design (apps own generated code); the litmus test keeps subtle logic on the runtime side of the line.
- [Timestamp-cursor skew on the outputs API] → receipts dedup absorbs re-reads; page-atomic cursor advance prevents gaps.

## Migration Plan

Purely additive; no existing behavior changes, no gemspec dependency changes. Land in task order (router → poller → transfers → notifications → install), each independently shippable behind `require 'mixin_bot/rails'`. Rollback for a host app = remove the require and generated files; the SDK is untouched. Ship as a minor version bump.

## Open Questions

Resolved during implementation:
- Convention directory names: `app/mixin/handlers` + `app/mixin/processors` (as assumed; Zeitwerk namespaces `Mixin::Handlers` / `Mixin::Processors`).
- Poller entry point: the `mixin_bot:poller` rake task only (no binstub); interval tunable via `MIXIN_BOT_POLL_INTERVAL` for tests and tight loops.
- Reconciler recurring entry: owned by the transfers generator (as assumed), emitted into `config/recurring.yml` when absent.
- Install skip-flag spelling: Rails-idiomatic `--skip-<component>` booleans plus grouped `--skip notifications,transfers` (Thor cannot repeat array flags; spec example updated to match).
