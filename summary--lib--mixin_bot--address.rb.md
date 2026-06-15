<!-- hash: address-rb-v1 -->
# lib/mixin_bot/address.rb

## Constants

- `MAIN_ADDRESS_PREFIX = 'XIN'`
- `MIX_ADDRESS_PREFIX = 'MIX'`
- `MIX_ADDRESS_VERSION = 2`
- `UUID_ADDRESS_LENGTH = 16`
- `MAIN_ADDRESS_LENGTH = 64`

## MixAddress

`MixinBot::MixAddress` builds/parses MIX multisig addresses.

- `self.parse(string)` / `self.from_members(members:, threshold:)` - constructors.
- `initialize(**args)` - accepts `:address`, `:payload`, or `:members/:threshold/:version`. Validates and raises `ArgumentError` if `valid?` fails.
- `valid?` - true when `address` + (`uuid_members` or `xin_members`) + `threshold` are present.
- `to_safe_recipient` - `{ members:, threshold:, amount:, mix_address: }`.
- `request_or_generate_ghost_keys(output_index = 0, api: MixinBot.api)` - for XIN members, generates Ed25519 keypair locally; for UUID members, calls `api.create_safe_keys`.
- `encode` - validates (member count <= 255, XIN-only <= 64, threshold rules), builds payload + SHA3-256 checksum + Base58, returns address.
- `decode` - validates prefix / length / checksum / version / threshold / member count.

## MainAddress

`MixinBot::MainAddress` - XIN address (public key + SHA3 checksum + Base58).

- `self.burning_address` - returns the canonical burn address derived from a 64-byte zero seed.
