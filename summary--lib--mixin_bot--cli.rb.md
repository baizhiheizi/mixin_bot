# lib/mixin_bot/cli.rb

Thor CLI. Class options: -a/--apihost (default api.mixin.one), -o/--output (pretty/json/yaml), -r/--pretty (boolean). Methods: version.

`setup_api_instance!` reads `-k`/`--keystore` (file path or raw JSON), parses it, and builds an API via `build_api_from_keystore` mapping: app_id/client_id, session_id, server_public_key/pin_token, session_private_key/private_key, spend_key, client_secret, pin.

`invoke_api` filters out `CLIHelpers::INTERACTIVE_API_METHODS` (Blaze connect, upload) with `kind: :unsupported`. `parse_json_data` parses `-d` JSON.

Conditional `node` subcommand when `which mixin` succeeds. Subcommand modules under lib/mixin_bot/cli/: call, api, node, utils, schema_command, plus base, errors, output, schema.