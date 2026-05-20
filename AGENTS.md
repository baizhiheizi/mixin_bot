# AGENTS.md — MixinBot

Ruby gem (v2.0.0): Mixin Network REST SDK + `mixinbot` CLI. Parity target: [bot-api-go-client](https://github.com/MixinNetwork/bot-api-go-client).

## Commands

```bash
bundle install
rake                    # default: test + rubocop (in that order)
rake test               # offline suite only
rake test_live          # LIVE=1 rake test (requires test/config.yml)
rake mixin_bot:api_coverage  # check API_COVERAGE.md has no missing entries
rake build              # build .gem
rake rdoc               # generate doc/
```

**Single test**: `ruby -Itest -Ilib test/mixin_bot/some_test.rb`

## Repository layout

```
lib/mixin_bot/
  api.rb + api/*.rb     # One module per API domain (Transfer, Message, Blaze, …)
  client.rb             # Faraday HTTP client → ApiEnvelope
  cli.rb + cli/*.rb     # mixinbot CLI (Thor)
  configuration.rb      # Credentials and hosts
  transaction/          # Raw transaction encode/decode
  utils.rb              # Crypto and encoding helpers
lib/mvm/                # MVM helpers (excluded from default rake test)
bin/mixinbot            # CLI entrypoint
test/                   # Minitest + WebMock (offline by default)
docs/agent/             # LLM-oriented CLI and cookbook docs
```

## CI and release

- **CI** (`.github/workflows/ci.yml`): `pull_request` and `push` to `main` — `rake test` on Ruby 3.2/3.3/4.0, `rake rubocop` (3.3), `rake mixin_bot:api_coverage`.
- **Release** (`.github/workflows/release.yml`): push tag `v*` (must match `MixinBot::VERSION`, e.g. tag `v2.0.0` for `VERSION = '2.0.0'`) → `rake build` → RubyGems via [trusted publishing](https://guides.rubygems.org/trusted-publishing/) (OIDC; workflow `release.yml`, no repo secret) → GitHub Release (notes from `CHANGELOG.md`, `.gem` attached).
- **Dependabot** (`.github/dependabot.yml`): weekly Bundler and GitHub Actions updates; Dependabot PRs use the same CI workflow.

## Conventions

- **Ruby** >= 3.2 (CI: 3.2, 3.3, 4.0)
- **HTTP responses**: `MixinBot::Models::ApiEnvelope` — use `res['data']` or delegated keys
- **Safe transfers**: require `spend_key`; prefer `create_safe_transfer` / `create_transfer` (Safe pipeline)
- **Legacy APIs**: `create_legacy_transfer`, `POST /transfers` — deprecated, warns once
- **Tests**: offline WebMock stubs by default; `LIVE=1 rake test` for integration
- **MVM tests**: excluded from `rake test`; run separately if needed
- **Lint**: RuboCop via `rake` (runs after tests in default task)

## CLI boundaries

Interactive API methods are **excluded** from `mixinbot call` (defined in `CLIHelpers::INTERACTIVE_API_METHODS` at `lib/mixin_bot/cli/base.rb:28`):
- `start_blaze_connect`, `blaze`, `upload_attachment`

Use the Ruby API + EventMachine for Blaze (see `examples/blaze.rb`).

Agent-friendly CLI features:
- `mixinbot schema -o json` — machine-readable command schema
- `--output json|yaml|pretty` — structured stdout; auto JSON when piped
- `mixinbot list --limit N --offset N -o json` — bounded method registry

See [docs/agent/cli.md](docs/agent/cli.md).

## Error types

Custom errors in `lib/mixin_bot/errors.rb`: `ResponseError`, `UnauthorizedError`, `InsufficientBalanceError`, `UtxoInsufficientError`, `PinError`, `NotFoundError`, etc.

CLI maps these to structured error kinds (`auth`, `api_error`, `not_found`, …) when `--output json`.

## What not to do

- Do not commit secrets (`test/config.yml`, keystore files with real keys)
- Do not use legacy transfer APIs in new code
- Do not expect Blaze WebSocket flows to work via CLI
