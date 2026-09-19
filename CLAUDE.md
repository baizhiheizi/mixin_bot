# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**MixinBot** is a Ruby gem (v3.0.0) providing a Ruby SDK and CLI for [Mixin Network](https://developers.mixin.one/docs). It mirrors the official [bot-api-go-client](https://github.com/MixinNetwork/bot-api-go-client) Go SDK and [bot-api-nodejs-client](https://github.com/MixinNetwork/bot-api-nodejs-client) Node SDK.

Key components:
- **`MixinBot::API`** — REST SDK for Safe UTXO transfers, messaging, assets, inscriptions, etc.
- **`mixinbot` CLI** — Thor-based CLI for API exploration and operations
- **`MVM`** — optional Mixin Virtual Machine helpers (`lib/mvm/`)

## Common Commands

```bash
bundle install              # Install dependencies
rake                        # Default: run tests + RuboCop (default task)
rake test                   # Offline test suite (WebMock stubs)
rake test_live             # Or: LIVE=1 rake test — live API tests (requires test/config.yml)
rake mixin_bot:api_coverage # Check Go SDK parity
rake rdoc                   # Generate doc/ (RDoc HTML docs)
rake build                  # Build .gem package
rake publish                # Build & push to RubyGems

# Single test file
ruby -Itest -Ilib test/mixin_bot/some_test.rb

# Run a specific test
ruby -Itest -Ilib -e "require 'test_helper'; require 'test/mixin_bot/api_test'"
```

## Architecture

### API Module Composition
`MixinBot::API` (`lib/mixin_bot/api.rb`) composes ~30 domain modules from `lib/mixin_bot/api/`:
- `Me`, `User`, `Session`, `Asset`, `NetworkAsset`, `Transfer`, `Transaction`, `Output`, `Snapshot`, `Payment`, `Multisig`, `Message`, `Blaze`, `Pin`, `Auth`, `App`, `Code`, `Rpc`, `ComputerApi`, etc.
- Each module has `safe_*` (Safe UTXO API) and `legacy_*` (deprecated) variants where applicable
- `Transfer`/`Transaction` modules expose multi-step Safe pipeline: `build_utxos` → `build_safe_transaction` → `verify_raw_transaction` → `sign_safe_transaction` → `send_safe_transaction`

### HTTP Client
`MixinBot::Client` (`lib/mixin_bot/client.rb`) — Faraday-based. Returns `MixinBot::Models::ApiEnvelope`. Use `res['data']` for envelope data or `res['key']` for delegated lookup.

### Rails Integration Layer (opt-in)
`require 'mixin_bot/rails'` (`lib/mixin_bot/rails.rb`) — loads the integration layer; `require 'mixin_bot'` never touches Rails. The railtie constant is `MixinBot::Railtie` (NOT `MixinBot::Rails`, which would lexically shadow `::Rails` inside `module MixinBot` — always reference `::Rails` in gem code under `MixinBot`). Components:
- **Multi-bot registry** (`lib/mixin_bot/registry.rb`): `MixinBot.register_bot(name, **creds)` (freezes the bot's config) / `MixinBot.bot(name)` / `MixinBot.bot_by_app_id(app_id)`
- **Blaze router** (`lib/mixin_bot/blaze/router.rb`): callable plugging into `config.blaze_handler`; DSL `on 'text', Handler`; handlers in app's `app/mixin/handlers` (`Mixin::Handlers::*`) subclass `Router::Base` and `reply` via HTTP `POST /messages`
- **Outputs poller** (`lib/mixin_bot/outputs/`): standalone `mixin_bot:poller` rake task; per-`app_id` cursor + receipt dedup (`MemoryReceiptStore` in gem, `ReceiptModel` concern for generated `MixinOutput` AR model); processors in `app/mixin/processors` (`Mixin::Processors::*` < `Outputs::Processor`, `matches?` + `process`); `Envelope` bridges memo/opponent/trace lazily via `create_safe_snapshot_notification`
- **Transfers** (`lib/mixin_bot/transfers/`): `Transfers::Model` concern (state machine `pending/broadcast/confirmed/failed/reconciling`, unique `trace_id`), `Performer` (Safe pipeline; APIError → failed, network error → reconciling), `Reconcile` (snapshot-by-trace confirms or re-sends)
- **Noticed channel** (`lib/mixin_bot/notifications/mixin_channel.rb`): loads only when `Noticed` is defined; notification classes define `mixin_recipient` + `mixin_message`
- **Generators** (`lib/generators/mixin_bot/`): `authentication`, `blaze`, `outputs`, `transfers`, `notifications`, and `install` (composes all with `--skip-<component>` flags)

Dev-only Gemfile deps for the Rails test harness: `railties`, `activejob`, `puma`. Integration runtime files live under `lib/mixin_bot/{blaze/router,outputs,transfers,notifications,rails}` and load only through `mixin_bot/rails`.

### CLI Structure
`lib/mixin_bot/cli.rb` + `lib/mixin_bot/cli/*.rb`:
- `mixinbot call METHOD` — invoke any API method with `-d '{"key":"value"}'` JSON kwargs
- `mixinbot list [FILTER]` — list callable methods (grouped by module)
- `mixinbot schema -o json` — machine-readable schema for all commands
- `mixinbot utils call/list` — invoke `MixinBot::Utils` methods
- Interactive methods (Blaze connect, upload) are excluded from `mixinbot call` — use Ruby API with EventMachine instead

### Configuration
`MixinBot.configure` accepts: `app_id`, `client_secret`, `session_id`, `session_private_key`, `server_public_key`, `spend_key`, `pin`, `api_host`, `blaze_host`, `http_timeout` (seconds; opt-in). CLI accepts `-k`/`--keystore` for JSON keystore files.

### OpenSpec Workflow
This repo uses [OpenSpec](https://github.com/nicholasdille/openspec) for structured changes:
- `opsx propose` — create a change proposal
- `opsx apply` — implement a change
- `opsx archive` — archive a completed change
- `opsx explore` — explore ideas before proposing

Skills at `.claude/skills/openspec-*/` and commands at `.claude/commands/opsx/` enable this workflow.

## Safe vs Legacy APIs

- **Safe API** (`create_safe_transfer`, `build_safe_transaction`, etc.) — preferred, requires `spend_key`
- **Legacy API** (`create_legacy_transfer`, `POST /transfers`) — deprecated, warns once

## Error Handling

Custom errors in `lib/mixin_bot/errors.rb`: `ResponseError`, `UnauthorizedError`, `InsufficientBalanceError`, `UtxoInsufficientError`, `PinError`, `NotFoundError`, etc. CLI maps these to structured kinds (`auth`, `api_error`, `not_found`) with `--output json`.

## Dependencies

- Ruby >= 4.0
- Faraday (HTTP client)
- Thor (CLI framework)
- EventMachine (for Blaze WebSocket)
- Minitest + WebMock (testing, offline by default)
