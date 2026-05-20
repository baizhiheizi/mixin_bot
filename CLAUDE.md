# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**MixinBot** is a Ruby gem (v2.0.0) providing a Ruby SDK and CLI for [Mixin Network](https://developers.mixin.one/docs). It mirrors the official [bot-api-go-client](https://github.com/MixinNetwork/bot-api-go-client) Go SDK.

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

### CLI Structure
`lib/mixin_bot/cli.rb` + `lib/mixin_bot/cli/*.rb`:
- `mixinbot call METHOD` — invoke any API method with `-d '{"key":"value"}'` JSON kwargs
- `mixinbot list [FILTER]` — list callable methods (grouped by module)
- `mixinbot schema -o json` — machine-readable schema for all commands
- `mixinbot utils call/list` — invoke `MixinBot::Utils` methods
- Interactive methods (Blaze connect, upload) are excluded from `mixinbot call` — use Ruby API with EventMachine instead

### Configuration
`MixinBot.configure` accepts: `app_id`, `client_secret`, `session_id`, `session_private_key`, `server_public_key`, `spend_key`, `pin`, `api_host`, `blaze_host`. CLI accepts `-k`/`--keystore` for JSON keystore files.

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

- Ruby >= 3.2
- Faraday (HTTP client)
- Thor (CLI framework)
- EventMachine (for Blaze WebSocket)
- Minitest + WebMock (testing, offline by default)
