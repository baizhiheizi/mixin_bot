# MixinBot agent cookbook

Task-oriented recipes. Full API reference: [README](../../README.md), [API_COVERAGE.md](../../API_COVERAGE.md).

## Configure credentials (Ruby)

```ruby
require 'mixin_bot'

MixinBot.configure do
  self.app_id = 'your-app-uuid'
  self.session_id = 'your-session-uuid'
  self.session_private_key = '...'
  self.server_public_key = '...'
  self.spend_key = '...'           # required for Safe transfers
  self.client_secret = '...'       # OAuth flows
end

api = MixinBot.api
api.me
```

## Call /me (CLI)

```bash
mixinbot call me -k keystore.json -o json --data-only
# or
mixinbot api /me -k keystore.json -o json
```

## Safe transfer

**Ruby** (recommended):

```ruby
MixinBot.api.create_transfer(
  members: 'recipient-uuid',
  asset_id: '965e5c6e-434c-3fa9-b780-c50f43cd955c',
  amount: '0.01',
  memo: 'payment',
  trace_id: SecureRandom.uuid
)
```

**CLI**:

```bash
mixinbot transfer RECIPIENT_UUID \
  -k keystore.json \
  --asset 965e5c6e-434c-3fa9-b780-c50f43cd955c \
  --amount 0.01 \
  --memo "payment" \
  -o json
```

Preview without submitting:

```bash
mixinbot transfer RECIPIENT_UUID -k keystore.json \
  --asset ASSET_ID --amount 0.01 --dry-run -o json
```

## OAuth authorization code

```bash
mixinbot authcode -k keystore.json -c TARGET_APP_ID -s PROFILE:READ -o json
```

## PIN / TIP

```bash
mixinbot verifypin 123456 -k keystore.json -o json
mixinbot encrypt 123456 -k keystore.json -o json
mixinbot updatetip NEW_PIN -k keystore.json -o json
```

## Safe registration

```bash
mixinbot saferegister -k keystore.json --spend_key SPEND_KEY_HEX -o json
```

## Payment URL

```bash
mixinbot pay \
  --members RECIPIENT_UUID \
  --asset ASSET_ID \
  --amount 0.01 \
  -o json
```

## Decode transaction

```bash
mixinbot decodetx RAW_TX_HEX -o json
mixinbot utils call decode_raw_transaction -d '{"raw":"..."}' -o json
```

## List UTXOs

```bash
mixinbot call safe_outputs -k keystore.json \
  -d '{"asset":"965e5c6e-434c-3fa9-b780-c50f43cd955c","state":"unspent","limit":10}' \
  -o json --data-only
```

## Blaze messaging (Ruby only)

Blaze requires WebSocket + EventMachine. **Not supported via CLI.**

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
      mid = raw.dig('data', 'message_id')
      blaze.send acknowledge_message_receipt(mid) if mid
    end
  end
end
```

See [examples/blaze.rb](../../examples/blaze.rb).

## Blaze inside Puma (`plugin :mixin_blaze`)

For Rails/Puma apps the gem ships a Puma plugin (Solid Queue-style) that hosts the Blaze connection inside the web process tree — no standalone Blaze process. Requires a configured `blaze_handler`; without one the plugin logs an error and stays off.

```ruby
# config/puma.rb
plugin :mixin_blaze
mixin_blaze_mode :fork # default (:fork = supervised child process); :async = in-process thread

# config/initializers/mixin_bot.rb
MixinBot.configure do
  # ... credentials ...
  self.blaze_handler = ->(envelope) { MyBot.process! envelope } # required
  self.blaze_ack_policy = :on_receipt # default; :after_handler = ack after handler success
end
```

Behavior: reconnect with bounded backoff, keepalive pings, serial handler dispatch (ActiveRecord-safe), handler exceptions logged without ending delivery, graceful shutdown with Puma (child killed on stop; in `:fork` mode a dead child stops Puma so the unit restarts).

Operational notes:

- **Remove any standalone Blaze process when enabling the plugin** — duplicate connections duplicate handler invocations.
- **Puma cluster mode requires `preload_app!`** — plugins run in the launcher process; without preloading there is no app code to resolve the handler and the plugin reports an error.
- **Phased restarts keep old handler code** in the hosting process until a full restart.
- Workers that need to *send* messages use the REST API (`create_message`), not the socket.

## Discover API methods

```bash
mixinbot list transfer -o json --limit 20
mixinbot schema -o json | jq '.commands[] | select(.name == "call")'
```

## Error handling

```ruby
begin
  MixinBot.api.create_safe_transfer(...)
rescue MixinBot::InsufficientBalanceError => e
  # handle
rescue MixinBot::UnauthorizedError => e
  # check credentials
end
```

CLI errors emit JSON to stderr with `error.kind` when output is structured.
