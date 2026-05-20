# mixinbot CLI — agent guide

The `mixinbot` executable wraps `MixinBot::API` and utilities for scripting and agent automation.

## Global options

| Flag | Description |
|------|-------------|
| `-a`, `--apihost` | Mixin API host (default: `api.mixin.one`) |
| `-o`, `--output` | Output format: `pretty`, `json`, `yaml` |
| `-r`, `--pretty` | Alias for `--output pretty` (default in TTY) |

**Auto-detect**: when `--output` is omitted, TTY → `pretty`, piped → `json`.

Environment:

- `MIXINBOT_NO_SPINNER=1` — disable progress spinners

## Keystore

API commands accept `-k` / `--keystore`: path to JSON or inline JSON:

```json
{
  "app_id": "uuid",
  "session_id": "uuid",
  "session_private_key": "hex-or-base64",
  "server_public_key": "hex-or-base64",
  "spend_key": "hex",
  "client_secret": "...",
  "pin": "123456"
}
```

Aliases: `client_id` → `app_id`, `private_key` → `session_private_key`, `pin_token` → `server_public_key`.

Without `-k`, the CLI uses global `MixinBot.configure` credentials.

## Schema introspection

Discover commands without parsing `--help`:

```bash
mixinbot schema -o json
mixinbot schema -o json | jq '.commands[].name'
```

Returns clispec-shaped JSON: `name`, `version`, `commands[]` (with `mutating`, `args`), `errors[]`.

## Structured output envelope

Success (stdout):

```json
{
  "status": "ok",
  "command": "call",
  "data": { ... }
}
```

Error (stderr, exit 1):

```json
{
  "status": "error",
  "error": {
    "kind": "invalid_args",
    "message": "unknown or unsupported API method: foo",
    "hint": "mixinbot list"
  }
}
```

Error kinds: `invalid_args`, `auth`, `not_found`, `api_error`, `unsupported`, `conflict`, `internal`.

## Commands

### Discovery

```bash
mixinbot list                          # all callable API methods
mixinbot list transfer -o json --limit 10 --offset 0
mixinbot list transfer -o json --fields name,owner
mixinbot utils list -o json --limit 20
```

List JSON shape:

```json
{
  "status": "ok",
  "command": "list",
  "data": {
    "items": [{"name": "create_safe_transfer", "owner": "MixinBot::API::Transfer"}],
    "total": 142,
    "limit": 10,
    "offset": 0
  }
}
```

### API invocation

```bash
mixinbot call me -k keystore.json -o json
mixinbot call safe_outputs -k keystore.json -d '{"asset":"965e5c6e-434c-3fa9-b780-c50f43cd955c","state":"unspent","limit":10}' -o json
mixinbot call user USER_UUID -k keystore.json --data-only -o json
```

### Raw HTTP

```bash
mixinbot api /me -k keystore.json -o json
mixinbot api /search/1051445 -k keystore.json -o json
mixinbot api /payments -k keystore.json -m POST -d '{"asset_id":"..."}' -o json
```

### Transfers (mutating)

```bash
mixinbot transfer USER_ID -k keystore.json --asset ASSET_ID --amount 0.01 -o json
mixinbot transfer USER_ID -k keystore.json --asset ASSET_ID --amount 0.01 --dry-run -o json
```

`--dry-run` validates keystore and prints kwargs without submitting.

### Utilities

```bash
mixinbot utils call unique_uuid -d '{"uuids":["uuid1","uuid2"]}' -o json
mixinbot unique UUID1 UUID2 -o json
mixinbot decodetx HEX -o json
mixinbot version -o json
```

## Piping

```bash
mixinbot version | jq .status
mixinbot list --limit 5 | jq '.data.items[].name'
mixinbot schema | jq '.commands[] | select(.mutating) | .name'
```

Diagnostics (spinners, warnings) go to **stderr**; data goes to **stdout**.

## Non-interactive

All commands run without prompts. Blaze WebSocket (`blaze`, `start_blaze_connect`) is **not** available via CLI — use the Ruby API.
