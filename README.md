# MixinBot

[![CI](https://github.com/an-lee/mixin_bot/actions/workflows/ci.yml/badge.svg)](https://github.com/an-lee/mixin_bot/actions/workflows/ci.yml)

Ruby SDK and CLI for [Mixin Network](https://developers.mixin.one/docs): authenticated REST calls, **Safe** UTXO transfers, Blaze messaging, invoices and mix addresses, transaction encoding, and optional **MVM** (Mixin Virtual Machine) helpers.

Current gem version: **2.0.0** (see [CHANGELOG.md](CHANGELOG.md) for breaking changes and deprecations).

API parity with the official [bot-api-go-client](https://github.com/MixinNetwork/bot-api-go-client) is tracked in [API_COVERAGE.md](API_COVERAGE.md). Run `rake mixin_bot:api_coverage` to verify the coverage table has no missing entries.

## Requirements

- **Ruby** ≥ 3.2 (CI runs 3.2, 3.3, and 4.0).
- **Bundler** 2.5+ recommended, especially on Ruby 4.
- Optional: the **`mixin`** CLI in `PATH` if you use `MixinBot::API#encode_raw_transaction_native` / `#decode_raw_transaction_native` or the experimental `MixinBot::NodeCLI` helpers.

## Installation

Add to your Gemfile:

```ruby
gem 'mixin_bot'
```

Then:

```bash
bundle install
```

Or install the gem directly:

```bash
gem install mixin_bot
```

The gem ships the `mixinbot` executable (see [CLI](#cli)).

## Quick start

### 1. Configure credentials

Set the fields your flows need. **Safe** transfers and signing require a **spend key** (`spend_key`) in addition to session material.

```ruby
require 'mixin_bot'

MixinBot.configure do
  self.app_id = 'your-app-uuid'
  self.client_secret = 'your-client-secret' # if you use OAuth-style flows that need it
  self.session_id = 'your-session-uuid'
  self.session_private_key = '...' # seed or full Ed25519 private key; Base64 or hex
  self.server_public_key = '...'   # pin token / server public key
  self.spend_key = '...'             # Ed25519 spend private key for Safe UTXO signing
  # self.pin = self.spend_key        # optional; used where PIN material is required
  # self.api_host = 'api.mixin.one'
  # self.blaze_host = 'blaze.mixin.one'
  # self.debug = true               # Faraday response logging
end
```

`MixinBot::Configuration` accepts common aliases: `client_id` → `app_id`, `private_key` → `session_private_key`, `pin_token` → `server_public_key`. Keys are normalized (e.g. 32-byte Ed25519 seeds expanded to 64-byte signing keys) where appropriate.

### 2. Call the API

```ruby
api = MixinBot.api # singleton using global config, or MixinBot::API.new(...)

# Profile (returns inner fields via ApiEnvelope; see below)
api.me['full_name']

# Assets
api.assets
```

### 3. Send assets (Safe API, recommended)

Use **`create_safe_transfer`** for the Safe pipeline (select UTXOs → build → verify → sign → submit). Configure **`spend_key`** first.

```ruby
result = MixinBot.api.create_safe_transfer(
  members: '6ae1c7ae-1df1-498e-8f21-d48cb6d129b5',
  asset_id: '965e5c6e-434c-3fa9-b780-c50f43cd955c',
  amount: '0.01',
  memo: 'payment',
  trace_id: SecureRandom.uuid # optional; defaults to a new UUID
)

# Multisig example: 2-of-3
MixinBot.api.create_safe_transfer(
  members: %w[uuid-1 uuid-2 uuid-3],
  threshold: 2,
  asset_id: '965e5c6e-434c-3fa9-b780-c50f43cd955c',
  amount: '0.01'
)
```

Lower-level steps are available as `build_utxos`, `build_safe_transaction`, `create_safe_transaction_request`, `sign_safe_transaction`, and `send_safe_transaction` on `MixinBot::API`.

### 4. Legacy `POST /transfers` (deprecated)

`MixinBot::API#create_transfer` is an alias for **`create_legacy_transfer`** and emits a deprecation warning. Migrate to **`create_safe_transfer`** and related Safe APIs. See [CHANGELOG.md](CHANGELOG.md).

## HTTP responses (`ApiEnvelope`)

`MixinBot::Client` returns **`MixinBot::Models::ApiEnvelope`** for REST calls. It wraps the raw JSON so you can use either envelope or flattened shapes, for example:

```ruby
res = MixinBot.api.client.get('/me')
res['data']['user_id'] # envelope
res['user_id']          # delegated lookup into `data` when present
res.to_h                # raw Hash
```

Many convenience methods on `MixinBot::API` still return the **inner `data` hash** where that was the historical contract (e.g. `#me`).

## Library layout

| Area | Description |
|------|-------------|
| **`MixinBot::API`** | Composed modules: profile (`Me`), assets, Safe and legacy transfers, payments, multisig, outputs, snapshots, Blaze, messages, PIN/TIP, withdrawals, RPC helpers, etc. |
| **`MixinBot::Client`** | Faraday-based HTTP client (JSON, retries, optional debug logger). |
| **`MixinBot::Configuration`** | Credentials and hosts. |
| **`MixinBot::Utils`** | Crypto, JWT access tokens, encoding/decoding helpers used by the API and CLI. |
| **`MixinBot::Transaction`** | Encode/decode raw transactions (version 5 Safe transactions, references, etc.). |
| **`MixinBot::MixAddress`** | Parse/build `MIX…` multisig-style addresses (`MixinBot::MixAddress`). |
| **`MixinBot::Invoice`** | Encode/decode `MIN…` invoices. |
| **`MixinBot::UUID`**, **`MixinBot::Nfo`** | UUID and NFT memo helpers. |
| **`MVM`** | Optional MVM namespace: `MVM.bridge`, `MVM.nft`, `MVM.scan`, `MVM.registry` (see `lib/mvm.rb`). |

### Errors

Custom errors live under `MixinBot::` (for example `ResponseError`, `UnauthorizedError`, `InsufficientBalanceError`, `UtxoInsufficientError`, `PinError`, `InvalidInvoiceFormatError`). See `lib/mixin_bot/errors.rb`.

### Multiple bots

```ruby
bot_a = MixinBot::API.new(
  app_id: '...',
  session_id: '...',
  session_private_key: '...',
  server_public_key: '...',
  spend_key: '...'
)

bot_b = MixinBot::API.new(app_id: '...', ...) # separate configuration instance

bot_a.me
bot_b.me
```

## Blaze (WebSocket)

Mixin Messenger / Blaze uses a WebSocket after JWT auth. `MixinBot::API#start_blaze_connect` yields a `Faye::WebSocket::Client` and supports optional `on_open` / `on_message` / `on_error` / `on_close` methods on the receiver (see `examples/blaze.rb`). Run the reactor (for example **EventMachine**) in your app.

```ruby
require 'eventmachine'
require 'mixin_bot'

EM.run do
  MixinBot.api.start_blaze_connect do
    def on_open(blaze, _event)
      blaze.send list_pending_message
    end

    def on_message(blaze, event)
      raw = JSON.parse ws_message(event.data)
      blaze.send acknowledge_message_receipt(raw['data']['message_id']) if raw.dig('data', 'message_id')
    end
  end
end
```

## CLI

Invoke **`mixinbot`** (global options: `-a` / `--apihost`, `-r` / `--pretty`).

Subcommands that talk to the API accept **`-k`** / **`--keystore`**: path to a JSON file **or** inline JSON. Supported keystore keys include `app_id` / `client_id`, `session_id`, `session_private_key` / `private_key`, `server_public_key` / `pin_token`, and `pin` for PIN/TIP operations. If `-k` is omitted, the CLI uses **`MixinBot::API.new`** with the **global** `MixinBot.configure` credentials.

| Command | Purpose |
|---------|---------|
| `mixinbot api PATH` | Signed `GET`/`POST` to a path (`-m`, `-d`, `-p`, `-t` for custom token). |
| `mixinbot authcode` | OAuth-style authorize code (`-c` app id, `-s` scopes). |
| `mixinbot encrypt PIN` | Encrypt PIN (`-i` iterator). |
| `mixinbot verifypin PIN` | Verify PIN. |
| `mixinbot updatetip PIN` | Rotate TIP PIN material. |
| `mixinbot transfer USER_ID` | **Legacy** transfer (`--asset`, `--amount`, `--memo`). |
| `mixinbot safetransfer USER_ID` | Safe transfer walkthrough (UTXO select → build → verify → sign → submit). |
| `mixinbot saferegister` | Safe network registration (`--spend_key`). |
| `mixinbot pay` | Print a Safe payment URL (`--members`, `--threshold`, `--asset`, `--amount`, …). |
| `mixinbot unique UUID …` | Deterministic unique UUID from inputs. |
| `mixinbot generatetrace HASH` | Trace UUID from transaction hash. |
| `mixinbot decodetx HEX` | Decode raw transaction hex. |
| `mixinbot nftmemo` | NFT mint memo (`-c` collection, `-t` token id, `-h` metadata hash). |
| `mixinbot rsa` / `mixinbot ed25519` | Generate RSA / Ed25519 key material. |
| `mixinbot version` | Print gem version. |

Run `mixinbot help` and `mixinbot help COMMAND` for details.

## Documentation

- **RDoc** — generate HTML docs:

  ```bash
  rake rdoc
  # open doc/index.html
  ```

- **Online** — [RubyDoc.info](https://www.rubydoc.info/gems/mixin_bot) for published releases.

- **Changelog** — [CHANGELOG.md](CHANGELOG.md) (2.0 deprecations, `ApiEnvelope`, Safe vs legacy).

## Development & tests

```bash
git clone https://github.com/an-lee/mixin_bot.git
cd mixin_bot
bundle install
```

- **Default suite** — offline stubs, no real network:

  ```bash
  rake test
  ```

- **RuboCop** — `rake` runs **tests + RuboCop** by default.

- **Live API** (optional, uses real credentials):

  ```bash
  cp test/config.yml.example test/config.yml
  # edit test/config.yml with your app (dashboard: https://developers.mixin.one/dashboard)
  LIVE=1 rake test
  # or: rake test_live
  ```

Examples under `examples/` (for example `examples/blaze.rb`) expect `examples/config.yml` — copy from `examples/config.yml.example`.

## References

- [Mixin developers documentation](https://developers.mixin.one/docs)
- [Mixin API overview](https://developers.mixin.one/api)
- [mixin_client_demo (Python)](https://github.com/myrual/mixin_client_demo)
- [mixin-node (Node.js)](https://github.com/virushuo/mixin-node)

## License

MIT — see [MIT-LICENSE](MIT-LICENSE).
