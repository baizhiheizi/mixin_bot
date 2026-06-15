<!-- hash: transfer-rb-v1 -->
# lib/mixin_bot/api/transfer.rb

`MixinBot::API::Transfer` - Safe pipeline.

## Public methods

- `create_transfer(pin = nil, **kwargs)` - dispatches to `create_legacy_transfer` (when `pin` is a String and `opponent_id` present) or `create_safe_transfer`.
- `send_transaction(**)` (and aliases) - one-line `create_safe_transfer` wrapper.
- `send_transaction_until_sufficient`, `send_transaction_with_change_outputs` - aliases for `create_safe_transfer`.
- `create_safe_transfer(**kwargs)` - full pipeline (build_utxos -> build -> verify -> sign -> submit). Resolves `asset_id` from `utxos.first['asset_id']` when UTXOs are provided, raises `ArgumentError` on missing amount / members, generates `request_id` from `request_id | trace_id | SecureRandom.uuid`.
- `build_utxos(asset_id:, amount:)` - fetches `safe_outputs(state: 'unspent', asset: asset_id, limit: 500)`, sorts by amount ascending, accumulates up to 256 UTXOs. Raises `UtxoInsufficientError` with `total_input`, `total_output`, `output_size`.

Internal calls reference `MixinBot.api.sign_safe_transaction`, `MixinBot.api.send_safe_transaction`, `MixinBot.utils.encode_raw_transaction`, `MixinBot.utils.decode_key`.
