# lib/mixin_bot/api.rb

`MixinBot::API` composes domain modules via `include`. Modules (in source order):

Address, App, Asset, Attachment, Auth, Blaze, Chain, Code, Circle, ComputerApi, Conversation, Deposit, EncryptedMessage, External, Fiat, Inscription, Me, Message, Multisig, Network, NetworkAsset, Output, Payment, Pin, PinPayload, Rpc, Session, Snapshot, Tip, Transaction, Transfer, Turn, User, Withdraw.

Legacy modules: LegacyCollectible, LegacyUser, LegacyMultisig, LegacyOutput, LegacyPayment, LegacySnapshot, LegacyTransaction, LegacyTransfer.

`API#initialize(**kwargs)` builds `Configuration` (or uses the global one) and a `Client`. Public helpers: `access_token`, `encode_raw_transaction`, `decode_raw_transaction`, `generate_trace_from_hash`, `encode_raw_transaction_native`, `decode_raw_transaction_native`. Private `warn_legacy_mixin_api!` (uses `MixinBot.deprecator`) and `ensure_mixin_command_exist`.