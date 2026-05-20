# AGENTS.md — MixinBot

Guidance for coding agents working in this repository. For curated documentation links, start with [llms.txt](llms.txt).

## Project identity

**MixinBot** is a Ruby gem (v2.0.0) providing:

- **`MixinBot::API`** — Mixin Network REST SDK (Safe UTXO, messaging, assets, inscriptions, …)
- **`mixinbot`** — Thor CLI for API exploration and operations
- **`MVM`** — optional Mixin Virtual Machine helpers (`lib/mvm/`)

Parity target: [bot-api-go-client](https://github.com/MixinNetwork/bot-api-go-client) (Go SDK). See [API_COVERAGE.md](API_COVERAGE.md).

## Repository layout

```
lib/mixin_bot/
  api.rb + api/*.rb     # One module per API domain (Transfer, Message, Blaze, …)
  client.rb             # Faraday HTTP client → ApiEnvelope
  cli.rb + cli/*.rb     # mixinbot CLI (Thor)
  configuration.rb      # Credentials and hosts
  transaction/          # Raw transaction encode/decode
  utils.rb              # Crypto and encoding helpers
lib/mvm/                # Bridge, NFT, Registry, Scan
bin/mixinbot            # CLI entrypoint
test/                   # Minitest + WebMock (offline by default)
docs/agent/             # LLM-oriented CLI and cookbook docs
```

## Conventions

- **Ruby** >= 3.2 (CI: 3.2, 3.3, 4.0)
- **HTTP responses**: `MixinBot::Models::ApiEnvelope` — use `res['data']` or delegated keys
- **Safe transfers**: require `spend_key`; prefer `create_safe_transfer` / `create_transfer` (Safe pipeline)
- **Legacy APIs**: `create_legacy_transfer`, `POST /transfers` — deprecated, warn once
- **Tests**: offline WebMock stubs by default; `LIVE=1 rake test` for integration
- **Lint**: RuboCop via `rake` (tests + rubocop)

## CLI boundaries

Interactive API methods are **excluded** from `mixinbot call` (see `CLIHelpers::INTERACTIVE_API_METHODS` in `lib/mixin_bot/cli/base.rb`):

- `start_blaze_connect`, `blaze`, `upload_attachment`

Use the Ruby API + EventMachine for Blaze (see `examples/blaze.rb`).

Agent-friendly CLI features (clispec-style):

- `mixinbot schema -o json` — machine-readable command schema
- `--output json|yaml|pretty` — structured stdout; auto JSON when piped
- `mixinbot list --limit N --offset N -o json` — bounded method registry

See [docs/agent/cli.md](docs/agent/cli.md).

## Workflows

```bash
bundle install
rake test                              # offline suite
rake mixin_bot:api_coverage            # Go SDK parity check
rake rdoc                              # generate doc/
mixinbot schema -o json                # CLI introspection
mixinbot list transfer -o json --limit 10
```

## Error types

Custom errors in `lib/mixin_bot/errors.rb`: `ResponseError`, `UnauthorizedError`, `InsufficientBalanceError`, `UtxoInsufficientError`, `PinError`, `NotFoundError`, etc.

CLI maps these to structured error kinds (`auth`, `api_error`, `not_found`, …) when `--output json`.

## What not to do

- Do not commit secrets (`test/config.yml`, keystore files with real keys)
- Do not use legacy transfer APIs in new code
- Do not expect Blaze WebSocket flows to work via CLI
