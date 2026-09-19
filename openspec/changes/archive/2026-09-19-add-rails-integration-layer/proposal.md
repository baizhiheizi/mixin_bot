# Add Rails integration layer

## Why

Every project built on `mixin_bot` re-implements the same foundation: message routing over Blaze, output polling for inbound payments, an outbound transfer ledger, and Mixin message notifications. The connection-level hard parts are already solved in the gem (`Blaze::Reactor`, the `mixin_blaze` Puma plugin, `POST /messages`), but everything between those primitives and application business logic is still hand-written per project — including the subtle, must-be-correct parts (payment dedup, transfer state management) where a bug has to be fixed N times across N projects.

## What Changes

- Add an optional Rails integration layer to the gem: `require 'mixin_bot/rails'` loads a railtie that registers generators and integration glue. Rails stays a soft dependency; requiring `mixin_bot` without Rails continues to work unchanged.
- Add `MixinBot::Blaze::Router`: a DSL (`on 'text', TextHandler`) that routes decoded Blaze envelopes to handler classes, with a `Message` wrapper (decoded data, conversation helpers) and `Handlers::Base` providing `reply` via `POST /messages`. Handlers and router are threaded with an explicit `api:` client so multiple bots can coexist in one process.
- Add `MixinBot::Outputs::Poller`: a standalone polling-loop process over `/safe/outputs` (covering inbound and outbound transfers) that persists a per-`app_id` cursor, deduplicates via a generated `mixin_outputs` receipts table (unique `output_id`), and enqueues per-output processing jobs to SolidQueue. Processors are predicate classes (`self.matches?(output)` + `#process`) — one file each, no central registry. The output envelope lazily bridges to snapshot data (memo, counterparty, trace) via `create_safe_snapshot_notification`.
- Add an outbound transfer pipeline: a generated `MixinTransfer` model includes a runtime concern managing the state machine (`pending -> broadcast -> confirmed | failed | unknown -> reconciling`), a thin SolidQueue `PerformJob` drives the existing Safe pipeline (`build_utxos -> build -> verify -> sign -> send`), and unknown-outcome transfers are reconciled against snapshots by `trace_id` before any retry.
- Add a `Noticed` delivery channel for Mixin messages, loaded only when `Noticed` is defined.
- Add generators: `mixin_bot:blaze`, `mixin_bot:outputs`, `mixin_bot:transfers`, `mixin_bot:notifications`, and `mixin_bot:install` (orchestrates all of the above). The existing `mixin_bot:authentication` generator is unchanged and included in `install`.

## Capabilities

### New Capabilities

- `blaze-message-router`: Route decoded Blaze envelopes to handler classes via a DSL, with a Message wrapper, reply helpers over `POST /messages`, and per-bot API clients. Includes the `mixin_bot:blaze` generator.
- `outputs-poller`: Standalone output-polling loop with cursor and receipt dedup, snapshot memo bridge, predicate-based processors dispatched through SolidQueue. Includes the `mixin_bot:outputs` generator.
- `outbound-transfers`: MixinTransfer model contract, transfer state machine, SolidQueue execution of the Safe pipeline, and unknown-outcome reconciliation. Includes the `mixin_bot:transfers` generator.
- `mixin-notifications`: `Noticed` delivery channel that sends Mixin messages, opt-in at load time. Includes the `mixin_bot:notifications` generator.
- `rails-integration`: The railtie itself — soft Rails dependency, generator registration, multi-bot configuration surface — and the `mixin_bot:install` orchestrator generator.

### Modified Capabilities

(none — `rails-generators` and `blaze-puma-plugin` requirements are unchanged; the new generators and router are additive)

## Impact

- **New code**: `lib/mixin_bot/rails.rb` (railtie), `lib/mixin_bot/blaze/router.rb`, `lib/mixin_bot/outputs/` (poller, envelope, receipts), `lib/mixin_bot/transfers/` (concern, perform core), `lib/mixin_bot/notifications/` (noticed channel), new generator directories under `lib/generators/mixin_bot/`.
- **Existing code**: none modified behaviorally. `Blaze::Reactor` and the Puma plugin gain an optional router-based handler path; the raw lambda handler contract stays valid.
- **Dependencies**: no new runtime gem dependencies for the core gem. Rails-specific code loads only under Rails; `noticed` integration loads only when `Noticed` is defined. Generators add gems to host apps only where the generated code needs them (e.g. SolidQueue is expected to already be present).
- **Testing**: offline WebMock-based tests for router, poller (injectable clock/sleeper/api, mirroring `Reactor`'s test seams), transfers state machine, and generator output (mirroring the authentication generator's test approach).
