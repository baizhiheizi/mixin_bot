# MixinBot

[![CI](https://github.com/an-lee/mixin_bot/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/an-lee/mixin_bot/actions/workflows/ci.yml)

Ruby SDK and CLI for [Mixin Network](https://developers.mixin.one/docs): authenticated REST calls, **Safe** UTXO transfers, Blaze messaging, network asset catalog, inscriptions, invoices and mix addresses, transaction encoding, and optional **MVM** (Mixin Virtual Machine) helpers.

The gem aims for **parity with the official [bot-api-go-client](https://github.com/MixinNetwork/bot-api-go-client)** Go SDK and **[bot-api-nodejs-client](https://github.com/MixinNetwork/bot-api-nodejs-client)** Node SDK. See [API_COVERAGE.md](API_COVERAGE.md) for the full mapping; run `rake mixin_bot:api_coverage` to confirm no gaps are marked missing.

Current gem version: **3.0.0** (see [CHANGELOG.md](CHANGELOG.md) for breaking changes and deprecations).

## Requirements

- **Ruby** ≥ 4.0 (CI runs 4.0).
- **Bundler** 2.6+ recommended.
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
  self.client_secret = 'your-client-secret' # OAuth flows
  self.session_id = 'your-session-uuid'
  self.session_private_key = '...' # seed or full Ed25519 private key; Base64 or hex
  self.server_public_key = '...'   # pin token / server public key
  self.spend_key = '...'           # Ed25519 spend private key for Safe UTXO signing
  # self.pin = self.spend_key        # optional; used where PIN material is required
  # self.api_host = 'api.mixin.one'
  # self.blaze_host = 'blaze.mixin.one'
  # self.http_timeout = 30          # request timeout in seconds (nil = no timeout)
  # self.debug = true               # Faraday response logging
end
```

`MixinBot::Configuration` accepts common aliases: `client_id` → `app_id`, `private_key` → `session_private_key`, `pin_token` → `server_public_key`. Keys are normalized (e.g. 32-byte Ed25519 seeds expanded to 64-byte signing keys) where appropriate.

### 2. Call the API

```ruby
api = MixinBot.api # singleton using global config, or MixinBot::API.new(...)

api.me['full_name']
api.assets
api.network_asset('c6d0c728-2624-429b-8e0d-d9d19b6592fa') # public network catalog
api.fetch_user_sessions(['user-uuid'])
```

### 3. Send assets (Safe API, recommended)

`create_transfer` with keyword arguments runs the **Safe** pipeline (UTXO select → build → verify → sign → submit). You can also call `create_safe_transfer` explicitly. Configure **`spend_key`** first.

```ruby
result = MixinBot.api.create_transfer(
  members: '6ae1c7ae-1df1-498e-8f21-d48cb6d129b5',
  asset_id: '965e5c6e-434c-3fa9-b780-c50f43cd955c',
  amount: '0.01',
  memo: 'payment',
  trace_id: SecureRandom.uuid
)

# Multisig: 2-of-3
MixinBot.api.create_safe_transfer(
  members: %w[uuid-1 uuid-2 uuid-3],
  threshold: 2,
  asset_id: '965e5c6e-434c-3fa9-b780-c50f43cd955c',
  amount: '0.01'
)
```

Lower-level steps: `build_utxos`, `build_safe_transaction`, `verify_raw_transaction` / `create_safe_transaction_request`, `sign_safe_transaction`, `send_safe_transaction` (batch via `requests:`).

Aliases aligned with the Go SDK include `send_transaction`, `send_transfer_transaction`, and `get_transaction_by_id` (→ `safe_transaction`).

### 4. Legacy `POST /transfers`

If the first argument is a **PIN string** and you pass `opponent_id:` (old Messenger transfer shape), `create_transfer` delegates to **`create_legacy_transfer`** (deprecated, warns once). Prefer Safe transfers for new code.

```ruby
# Legacy only — deprecated
MixinBot.api.create_legacy_transfer(
  pin,
  asset_id: '...',
  opponent_id: '...',
  amount: 0.00000001,
  trace_id: SecureRandom.uuid
)
```

## HTTP responses (`ApiEnvelope`)

`MixinBot::Client` returns **`MixinBot::Models::ApiEnvelope`** for REST calls. It wraps the raw JSON so you can use either envelope or flattened shapes:

```ruby
res = MixinBot.api.client.get('/me')
res['data']['user_id'] # envelope
res['user_id']          # delegated lookup into `data` when present
res.to_h                # raw Hash
```

Many convenience methods on `MixinBot::API` still return the **inner `data` hash** where that was the historical contract (e.g. `#me`).

## Library layout

### `MixinBot::API` modules

`MixinBot::API` composes one module per API area (all methods are available on `MixinBot.api`):

| Module | Examples |
|--------|----------|
| **Me** | `me`, `safe_me`, `update_me`, `friends`, `update_preferences`, `relationship` |
| **User** | `user`, `fetch_users`, `search_user`, `create_user`, `safe_register`, `migrate_to_safe` |
| **Session** | `fetch_user_sessions` |
| **LegacyUser** | `upgrade_legacy_user` |
| **Asset** | `assets`, `asset`, `ticker`, `fetch_assets`, `asset_fee`, `asset_balance` |
| **NetworkAsset** | `network_asset`, `network_ticker`, `network_asset_search` |
| **Network** | `network_assets`, `network_assets_top` |
| **Fiat** | `fiats` |
| **Chain** | `network_chain`, `network_chains`, `chain_name`, `chain_id?` |
| **Transfer** | `create_transfer`, `create_safe_transfer`, `build_utxos`, `send_transaction`, … |
| **Transaction** | `create_safe_keys`, `build_safe_transaction`, `verify_raw_transaction`, `sign_safe_transaction`, `build_object_transaction`, `create_object_storage_transaction`, … |
| **Output** | `safe_outputs`, `safe_output`, `build_threshold_script` |
| **Deposit** | `pending_safe_deposits` |
| **Address** (deposit entries) | `safe_deposit_entries` |
| **Snapshot** | `safe_snapshots`, `safe_snapshot`, `create_safe_snapshot_notification` |
| **LegacySnapshot** | `snapshots`, `snapshot`, `snapshot_by_trace_id`, `network_snapshots`, … |
| **Payment** | `safe_pay_url` |
| **LegacyPayment** | `pay_url`, `verify_payment` (deprecated) |
| **Multisig** | `create_safe_multisig_request`, `safe_multisig_request`, `create_multisig_raw_tx` |
| **LegacyMultisig** | `create_multisig_request`, `cancel_multisig_request`, … |
| **LegacyOutput** | `legacy_outputs`, `read_multisigs`, `create_output`, … |
| **LegacyTransfer** | `create_legacy_transfer`, `legacy_transfer` |
| **LegacyTransaction** | `build_raw_transaction`, `create_multisig_transaction`, … |
| **Inscription** | `collection`, `collectible`, `build_inscribe_transaction`, … |
| **LegacyCollectible** | legacy collectible requests (deprecated) |
| **Withdraw** | `withdrawals`, `create_withdraw_address`, `check_address`, `withdraw_addresses` |
| **Conversation** | `conversation`, `create_group_conversation`, `join_conversation`, … |
| **Message** | `send_message`, `send_plain_messages`, Blaze helpers |
| **EncryptedMessage** | `send_encrypted_*`, `post_encrypted_messages`, `encrypt_message`, `decrypt_message` |
| **Blaze** | `blaze`, `start_blaze_connect`, `blaze_send_plain_text`, … |
| **Attachment** | `create_attachment`, `upload_attachment` |
| **Auth** | `oauth_token`, `authorize_code`, `access_token`, `sign_oauth_access_token` |
| **Pin** / **Tip** | `verify_pin`, `update_pin`, `update_tip_pin`, `encrypt_tip_pin`, `get_tip_node`, `tip_body_for_*` |
| **App** | `favorite_apps`, `transfer_app_ownership` (`migrate`) |
| **Code** | `read_code`, `read_multisig_by_code` |
| **Turn** | `turn_servers` |
| **Rpc** | `rpc_proxy`, `send_raw_transaction`, `get_transaction`, … |
| **ComputerApi** | delegates to `MixinBot::Computer` (`get_computer_info`, `register_computer`, …) |

Top-level helpers on **`MixinBot::API`**: `access_token`, `encode_raw_transaction`, `decode_raw_transaction`, native variants via `mixin` CLI.

### Session caching for encrypted messages

`post_encrypted_messages` resolves recipient sessions through a **session store**: `session_store: session_store_obj` — any object answering `fetch(user_id)` (sessions or `nil`) and `store(user_id, sessions)` (storing `nil` evicts). Without one, a per-API-instance in-memory store is used.

For Rails (or any `ActiveSupport::Cache`-style store — Redis, Memcached, solid_cache), use the built-in adapter for TTLs and cross-process caching:

```ruby
MixinBot.api.post_encrypted_messages(
  [{ recipient_id: id, category: 'ENCRYPTED_TEXT', data: 'hello' }],
  session_store: MixinBot::CacheStoreAdapter.new(Rails.cache, expires_in: 12.hours)
)
```

The adapter maps `store(user_id, nil)` to `cache.delete`, so sessions the server reports as expired are evicted, refreshed, and retried automatically.

### Other libraries

| Area | Description |
|------|-------------|
| **`MixinBot::Client`** | Faraday HTTP client (JSON, retries, optional debug). |
| **`MixinBot::Configuration`** | Credentials and hosts. |
| **`MixinBot::Utils`** | Crypto, JWT, encoding, `unique_object_id`, `generate_user_checksum`, … |
| **`MixinBot::Transaction`** | Encode/decode raw Safe transactions. |
| **`MixinBot::MixAddress`** | Parse/build `MIX…` addresses; `request_or_generate_ghost_keys`. |
| **`MixinBot::Invoice`** | `MIN…` payment invoices. |
| **`MixinBot::UrlScheme`** | `mixin://` deep links (`scheme_users`, `scheme_pay`, …). |
| **`MixinBot::Computer`** | [Mixin Computer](https://computer.mixin.one) HTTP API (separate host). |
| **`MixinBot::BotAuth`** | Sign bot-platform requests (`BotAuth::Client#sign_request`). |
| **`MixinBot::Monitor`** | YAML monitor messages, `report_to_monitor`, `check_retryable_error`. |
| **`MixinBot::UUID`**, **`MixinBot::Nfo`** | UUID and NFT memo helpers. |
| **`MVM`** | Optional MVM namespace: `MVM::Bridge`, `MVM::Nft`, `MVM::Scan`, `MVM::Registry`. |

### Errors

API failures raise structured `MixinBot::APIError` subclasses with `code`, `description`, `request_id`, and behavior helpers (`retryable?`, `throttle?`). The full mapping follows the [Mixin error codes](https://developers.mixin.one/docs/api/error-codes) table — notably `429` → `RateLimitError`, not `ForbiddenError`.

Use `MixinBot.retryable?(error)` for job retry decisions; use `error.throttle?` on `RateLimitError` for global backoff. `Monitor.check_retryable_error` delegates to the same policy.

Local validation errors (`ArgumentError`, `InvalidInvoiceFormatError`, …) and `InsufficientAppBillingError` (billing preflight) are separate from API envelope errors. See `lib/mixin_bot/errors.rb`.

### Multiple bots

```ruby
bot_a = MixinBot::API.new(
  app_id: '...',
  session_id: '...',
  session_private_key: '...',
  server_public_key: '...',
  spend_key: '...'
)

bot_b = MixinBot::API.new(...) # separate configuration

bot_a.me
bot_b.me
```

## Blaze (WebSocket)

Blaze uses a WebSocket after JWT auth. `start_blaze_connect` yields a `Faye::WebSocket::Client`; define `on_open` / `on_message` / `on_error` / `on_close` on the receiver (see `examples/blaze.rb`). Run an event loop (e.g. **EventMachine**) in your app.

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

For outbound messages over an open socket, use `blaze_send_plain_text`, `blaze_send_contact`, `blaze_send_app_card`, and related helpers (parity with Go `BlazeClient`).

### Without EventMachine: `blaze_async`

`blaze_async` returns the connected `async-websocket` connection instead of a `Faye::WebSocket::Client` — same URL, `Mixin-Blaze-1` subprotocol, and frame codec; the caller drives the loop in an `Async` reactor. Wire notes: wrap `write_ws_message` byte arrays in `Protocol::WebSocket::BinaryMessage`, feed `message.to_str` into `ws_message`, and own the keepalive ping (see `examples/blaze_async.rb`).

```ruby
require 'async'
require 'mixin_bot'

Async do |task|
  connection = MixinBot.api.blaze_async

  task.async do # keepalive is the caller's job
    loop do
      sleep 30
      connection.send_ping
    end
  end

  connection.write Protocol::WebSocket::BinaryMessage.new(MixinBot.api.list_pending_message.pack('C*'))
  while (message = connection.read)
    raw = JSON.parse MixinBot.api.ws_message(message.to_str)
    # data is a Hash for message envelopes, an Array in LIST_PENDING_MESSAGES replies
    data = raw['data'].is_a?(Hash) ? raw['data'] : {}
    next unless (message_id = data['message_id'])

    bytes = MixinBot.api.acknowledge_message_receipt(message_id)
    connection.write Protocol::WebSocket::BinaryMessage.new(bytes.pack('C*'))
  end
ensure
  connection&.close
end
```

### Running Blaze inside Puma (`plugin :mixin_blaze`)

For Rails/Puma apps, the gem ships a Puma plugin (Solid Queue-style) that hosts the Blaze connection inside the web process tree — no standalone Blaze process to deploy or supervise:

```ruby
# config/puma.rb
plugin :mixin_blaze
mixin_blaze_mode :fork # default; see table below
```

```ruby
# config/initializers/mixin_bot.rb
MixinBot.configure do
  # ... credentials ...
  self.blaze_handler = ->(envelope) { MyBot.process! envelope }
  self.blaze_ack_policy = :on_receipt # default; or :after_handler
end
```

The handler receives each decoded message envelope (a Hash with `action` and `data` keys) and runs serially on the hosting thread — safe for ActiveRecord. Handlers run one message at a time; the keepalive ping runs separately.

| Mode | Where the connection lives | Notes |
|---|---|---|
| `:fork` (default) | Dedicated child process forked from the Puma launcher | Crash-isolated; if the child dies, Puma is stopped so the process manager restarts the unit |
| `:async` | Background thread inside the Puma process itself | In cluster mode that process is the master; no child process |

Ack policy: `:on_receipt` acknowledges each message immediately (at-most-once dispatch — a handler crash loses that message); `:after_handler` acknowledges only after the handler completes without raising (at-least-once — handlers must be idempotent, since unacknowledged messages are redelivered on reconnect).

Receipt confirmations (`ACKNOWLEDGE_MESSAGE_RECEIPT` frames the server pushes for your own outgoing/acknowledged messages) are consumed internally: the handler never sees them and they are never re-acknowledged.

Operational notes:

- **Remove any standalone Blaze process when enabling the plugin** — two connections double your handler invocations (or split deliveries).
- **Cluster mode requires `preload_app!`** — plugins run in the launcher process, which holds no application code without preloading; the plugin reports an error and stays off otherwise.
- **Phased restarts keep the old handler code** in the hosting process until a full restart; the same applies to Solid Queue's plugin.
- Workers that need to *send* messages should use the REST API (`create_message` / `create_messages`), not the socket.

## Rails integration

The gem ships Rails generators under the `mixin_bot:` namespace. The first one sets up **"Sign in with Mixin"** (OAuth login via [`omniauth-mixin`](https://github.com/an-lee/omniauth-mixin)), modeled on Rails' built-in `rails g authentication`:

```bash
rails generate mixin_bot:authentication
```

This creates an identity-only Mixin login: OmniAuth initializer, `User` / `Session` / `Current` models, `SessionsController` with the OAuth callback, an `Authentication` controller concern (injected into `ApplicationController`), a sign-in view, routes, and the `CreateUsers` / `CreateSessions` migrations. It also adds `omniauth-mixin` and `omniauth-rails_csrf_protection` to the Gemfile (uncommenting existing entries, otherwise `bundle add`) and runs migrations generation. Run `bin/rails db:migrate` afterwards.

Then:

- Set `MIXIN_CLIENT_ID` and `MIXIN_CLIENT_SECRET` from the [Mixin Developer Dashboard](https://developers.mixin.one/dashboard).
- Register `https://<your-host>/auth/mixin/callback` as the OAuth redirect URL of your Mixin app.

Notes:

- **Identity only** — the OAuth exchange is used to establish identity (Mixin user id + name + avatar). Access/refresh tokens are not persisted; a future generator may add API-access wiring on top.
- **Fail loud at sign-in, not at boot** — the app boots fine without credentials (deploys, CI, `assets:precompile`); attempting to sign in raises an error naming the missing `MIXIN_CLIENT_ID` / `MIXIN_CLIENT_SECRET`.
- **CSRF-protected request phase** — the sign-in button POSTs to `/auth/mixin` (OmniAuth 2.x default request method, protected by `omniauth-rails_csrf_protection`); the provider redirects back to the `/auth/mixin/callback` GET route.
- **Existing apps beware** — like `rails g authentication`, the generator templates over target files (e.g. an existing `User` model) and will prompt on conflicts; reconcile manually if you already have users.
- Sessions are database-backed (`sessions` table with `ip_address` / `user_agent`) with a signed httponly cookie, exactly like Rails 8's `authentication` generator; `Current.user` is available after sign-in.

The generated code depends only on Rails and the two OmniAuth gems — not on `mixin_bot` itself — so the login keeps working even if you later drop the gem from the app.

## Deep links and bot auth

```ruby
MixinBot::UrlScheme.scheme_pay(
  asset_id: '...',
  trace_id: SecureRandom.uuid,
  recipient_id: '...',
  memo: 'hello',
  amount: '0.01'
)

client = MixinBot::BotAuth.new_client(MixinBot.api)
token = client.sign_request(Time.now.to_i, bot_user_id, 'GET', '/some/path')
```

## CLI

Invoke **`mixinbot`** (global options: `-a` / `--apihost`, `-o` / `--output pretty|json|yaml`, `-r` / `--pretty`).

When stdout is piped, output defaults to JSON. Use `mixinbot schema -o json` for machine-readable command discovery. See [docs/agent/cli.md](docs/agent/cli.md).

Subcommands that talk to the API accept **`-k`** / **`--keystore`**: path to a JSON file **or** inline JSON (`app_id`, `session_id`, `session_private_key`, `server_public_key`, `spend_key`, `client_secret`, `pin`, etc.). Without `-k`, the CLI uses global `MixinBot.configure` credentials.

| Command | Purpose |
|---------|---------|
| `mixinbot call METHOD` | Invoke any `MixinBot::API` method (`-d` JSON kwargs, optional positional args). |
| `mixinbot list [FILTER]` | List callable API methods (grouped by module). |
| `mixinbot api PATH` | Signed `GET`/`POST` via `MixinBot::Client` (`-m`, `-d`, `-p`, `-t`). |
| `mixinbot transfer USER_ID` | Safe transfer (`create_safe_transfer`; `--asset`, `--amount`, …). |
| `mixinbot legacy-transfer USER_ID` | Deprecated `POST /transfers`. |
| `mixinbot safetransfer USER_ID` | Alias for `transfer` (deprecated name). |
| `mixinbot authcode` | OAuth authorize code (`-c`, `-s`). |
| `mixinbot encrypt PIN` / `verifypin` / `updatetip` | PIN/TIP helpers. |
| `mixinbot saferegister` | Safe registration (`--spend_key`). |
| `mixinbot pay` | Safe payment URL. |
| `mixinbot utils call METHOD` | Invoke any `MixinBot.utils` method (`-d` JSON kwargs). |
| `mixinbot utils list [FILTER]` | List utils methods. |
| `mixinbot unique UUID …` | Deterministic UUID. |
| `mixinbot generatetrace HASH` | Trace UUID from tx hash. |
| `mixinbot decodetx HEX` | Decode raw transaction. |
| `mixinbot nftmemo` | NFT mint memo. |
| `mixinbot rsa` / `ed25519` | Key generation. |
| `mixinbot version` | Gem version. |

Examples:

```bash
mixinbot call me -k ~/.mixinbot/keystore.json
mixinbot call safe_outputs -k keystore.json -d '{"asset":"965e5c6e-434c-3fa9-b780-c50f43cd955c","state":"unspent"}'
mixinbot transfer USER_ID -k keystore.json --asset ASSET_ID --amount 0.01
```

Run `mixinbot help` and `mixinbot help COMMAND` for details.

## For AI agents / LLMs

- **[llms.txt](llms.txt)** — curated documentation index ([llmstxt.org](https://llmstxt.org/) format)
- **[AGENTS.md](AGENTS.md)** — repository layout, conventions, and workflows for coding agents
- **[docs/agent/cli.md](docs/agent/cli.md)** — structured `mixinbot` output, schema introspection, JSON examples
- **[docs/agent/cookbook.md](docs/agent/cookbook.md)** — task recipes (transfers, auth, messaging)

Run `mixinbot schema -o json` to discover CLI commands programmatically.

## Documentation

- **API coverage** — [API_COVERAGE.md](API_COVERAGE.md) vs [bot-api-go-client](https://github.com/MixinNetwork/bot-api-go-client).
- **RDoc** — `rake rdoc` → `doc/index.html`.
- **Online** — [RubyDoc.info](https://www.rubydoc.info/gems/mixin_bot).
- **Changelog** — [CHANGELOG.md](CHANGELOG.md).

## Development & tests

```bash
git clone https://github.com/an-lee/mixin_bot.git
cd mixin_bot
bundle install
```

- **Default suite** (offline WebMock stubs):

  ```bash
  rake test
  ```

- **API coverage check**:

  ```bash
  rake mixin_bot:api_coverage
  ```

- **RuboCop** — `rake` runs tests + RuboCop.

- **Live API** (optional):

  ```bash
  cp test/config.yml.example test/config.yml
  LIVE=1 rake test
  # or: rake test_live
  ```

Examples under `examples/` expect `examples/config.yml` (copy from `examples/config.yml.example`).

### CI

GitHub Actions runs on every pull request and on pushes to `main`:

- **Test** — Ruby 4.0: `bundle exec rake test`
- **RuboCop** — Ruby 4.0: `bundle exec rake rubocop`
- **API coverage** — `bundle exec rake mixin_bot:api_coverage`

### Release

Publishing to [RubyGems.org](https://rubygems.org/gems/mixin_bot) is automated when a version tag is pushed:

1. Bump `MixinBot::VERSION` in `lib/mixin_bot/version.rb` and update `CHANGELOG.md`.
2. Commit and push to `main`.
3. Create and push a tag matching the gem version (e.g. `v2.1.0` for version `2.1.0`):

   ```bash
   git tag v2.1.0
   git push origin v2.1.0
   ```

The [Release workflow](.github/workflows/release.yml) builds the gem, publishes to RubyGems.org via [trusted publishing](https://guides.rubygems.org/trusted-publishing/) (GitHub OIDC; trusted publisher for workflow `release.yml` on `an-lee/mixin_bot`), and creates a GitHub Release with notes from `CHANGELOG.md` and the `.gem` attached. To build without publishing, run the Release workflow manually with **dry run** enabled.

## References

- [Mixin developers documentation](https://developers.mixin.one/docs)
- [Mixin API overview](https://developers.mixin.one/api)
- [bot-api-go-client](https://github.com/MixinNetwork/bot-api-go-client) (official Go SDK; parity reference)
- [mixin_client_demo (Python)](https://github.com/myrual/mixin_client_demo)
- [mixin-node (Node.js)](https://github.com/virushuo/mixin-node)

## License

MIT — see [MIT-LICENSE](MIT-LICENSE).
