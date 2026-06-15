# lib/mixin_bot/configuration.rb

`CONFIGURABLE_ATTRS` = app_id, client_secret, session_id, session_private_key, server_public_key, spend_key, pin, api_host, blaze_host, session_private_key_curve25519, server_public_key_curve25519, debug.

Key aliasing: `client_id → app_id`, `private_key → session_private_key`, `pin_token → server_public_key`. Defaults: api_host `api.mixin.one`, blaze_host `blaze.mixin.one`, pin defaults to spend_key.

Setters call `decode_key` and expand 32-byte Ed25519 seeds to 64-byte keypairs via `JOSE::JWA::Ed25519.keypair`. `server_public_key=` derives curve25519 via `pk_to_curve25519` when hex-encoded. `session_private_key=` derives curve25519 via `sk_to_curve25519` when 64 bytes.

`valid?` requires app_id, session_id, session_private_key, server_public_key.