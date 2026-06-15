<!-- hash: crypto-rb-v1 -->
# lib/mixin_bot/utils/crypto.rb

`MixinBot::Utils::Crypto` - cryptographic helpers.

## JWT

`access_token(method, uri, body='', exp_in: 600, scp: 'FULL', app_id:, session_id:, private_key:)`. Builds payload with `uid`, `sid`, `iat`, `exp`, `jti`, `sig = SHA256(method+uri+body)`, `scp`. Uses `EdDSA` for 64-byte Ed25519 keys, `RS512` for PEM. Raises `ConfigurationNotValidError` if `private_key` blank.

## Key generation

- `generate_ed25519_key` -> `{ private_key:, public_key: }` (Base64-urlsafe, no padding).
- `generate_rsa_key` -> `{ private_key:, public_key: }` (PEM, 1024-bit).

## Internal scalar / signing

- `shared_public_key(key)` - derive public from private (first 64 bytes).
- `scalar_from_bytes(raw)` - convert raw bytes to a `JOSE::JWA::FieldElement` (used for Ed25519 ops).
- `sign(msg, key:)` - Blake3-hashed Ed25519-style signature.

## UUID helpers

- `generate_unique_uuid(uuid1, uuid2)` - MD5(sorted pair) with v3-like bits set.
- `unique_uuid(*uuids)` - sort and fold via `generate_unique_uuid`.
- `generate_group_conversation_id(user_ids:, name:, owner_id:, random_id: nil)` - deterministic conv id.
- `generate_user_checksum(sessions)` - MD5 of sorted session IDs.
- `chunked`, `make_unique_string_slice`, `unique_object_id` - small utilities.
- `generate_trace_from_hash(hash, output_index = 0)` - trace UUID from tx hash + index.

## PIN crypto

- `decrypt_pin(msg, shared_key:)` - AES-256-CBC inverse.
- `encrypt_pin(pin, iterator: nil, shared_key: nil)` - requires `shared_key`, default iterator `Time.now.utc.to_i`. AES-256-CBC with random IV, Base64-urlsafe output.

## TIP / ghost keys

- `tip_public_key(key, counter: 0)` - encode tip public key.
- `hash_scalar(pkey, output_index)` - Blake3-based scalar hash.
- `multiply_keys(public_key:, private_key:)` - Ed25519 point multiplication.
- `derive_ghost_public_key(private_key, view_key, spend_key, index)` - public ghost key.
- `derive_ghost_private_key(public_key, view_key, spend_key, index)` - private ghost key.
