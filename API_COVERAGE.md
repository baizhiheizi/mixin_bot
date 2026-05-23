# Mixin SDK API Coverage

Go reference: [bot-api-go-client](https://github.com/MixinNetwork/bot-api-go-client) (`package bot`).

Node reference: [bot-api-nodejs-client](https://github.com/MixinNetwork/bot-api-nodejs-client) (`@mixin.dev/mixin-node-sdk`).

Status values: `done` | `alias` | `n/a` (CLI-only / config / platform-specific)

| Go symbol | Ruby method | HTTP / notes | Status |
|-----------|-------------|--------------|--------|
| **Auth** |
| SignAuthenticationToken | `API#access_token` | JWT | done |
| SignAuthenticationTokenWithoutBody | `API#access_token` | JWT | alias |
| SignAuthenticationTokenWithRequestID | `API#access_token` | JWT | alias |
| SignOauthAccessToken | `API#sign_oauth_access_token` | JWT | done |
| OAuthGetAccessToken | `API#oauth_token` | POST `/oauth/token` | done |
| **Users** |
| CreateUserSimple | `API#create_user` | POST `/users` | done |
| CreateUser | `API#create_user` | POST `/users` | done |
| GetUser | `API#user` | GET `/users/:id` | done |
| GetUsers | `API#fetch_users` | POST `/users/fetch` | done |
| SearchUser | `API#search_user` | GET `/search/:q` | done |
| UpdateTipPin | `API#update_tip_pin` | POST `/pin/update` | done |
| UpdatePin | `API#update_pin` | POST `/pin/update` | done |
| UserMe / RequestUserMe | `API#me` / `API#safe_me` | GET `/me`, `/safe/me` | done |
| UpdateUserMe | `API#update_me` | POST `/me` | done |
| UpdatePreference | `API#update_preferences` | POST `/me/preferences` | done |
| Relationship | `API#relationship` | POST `/relationships` | done |
| GenerateUserChecksum | `MixinBot.utils.generate_user_checksum` | local | done |
| RegisterSafe* | `API#safe_register`, `#migrate_to_safe` | POST `/safe/users` | done |
| UpgradeLegacyUser | `API#upgrade_legacy_user` | POST `/legacy/users` | done |
| FetchUserSession | `API#fetch_user_sessions` | POST `/sessions/fetch` | done |
| **Sessions / PIN** |
| EncryptEd25519PIN | `API#encrypt_pin` | local | done |
| VerifyPIN | `API#verify_pin` | POST `/pin/verify` | done |
| VerifyPINTip | `API#verify_pin_tip` | POST `/pin/verify` | alias |
| **Assets** |
| ListAssetWithBalance | `API#assets` | GET `/assets` | done |
| FetchAssets | `API#fetch_assets` | POST `/safe/assets/fetch` | done |
| ReadAssetFee | `API#asset_fee` | GET `/safe/assets/:id/fees` | done |
| AssetBalance* | `API#asset_balance` | derived from outputs | done |
| UserAssetBalance | `API#user_asset_balance` | GET `/safe/outputs` | done |
| ReadAsset | `API#network_asset` | GET `/network/assets/:id` | done |
| ReadAssetTicker* | `API#network_ticker` | GET `/network/ticker` | done |
| AssetSearch | `API#network_asset_search` | GET `/network/assets/search/:q` | done |
| ReadNetworkAssets | `API#network_assets` | GET `/network` | done |
| ReadNetworkAssetsTop | `API#network_assets_top` | GET `/network/assets/top` | done |
| GetFiats / Fiats | `API#fiats` | GET `/external/fiats` | done |
| **Chains** |
| ReadNetworkChainById | `API#network_chain` | GET `/network/chains/:id` | done |
| ReadNetworkChains | `API#network_chains` | GET `/network/chains` | done |
| GetChainName | `API#chain_name` | local | done |
| IsChainId | `API#chain_id?` | local | done |
| GetFullChains | `API#full_chains` | local | done |
| **Outputs / deposits** |
| ListOutputs / ListUnspentOutputs | `API#safe_outputs` | GET `/safe/outputs` | done |
| GetOutput | `API#safe_output` | GET `/safe/outputs/:id` | done |
| FetchPendingSafeDeposits | `API#pending_safe_deposits` | GET `/safe/deposits` | done |
| CreateDepositEntry | `API#safe_deposit_entries` | POST `/safe/deposit/entries` | done |
| **Transactions (Safe)** |
| SendTransaction* | `API#create_safe_transfer` | pipeline | done |
| GetTransactionById* | `API#safe_transaction` | GET `/safe/transactions/:id` | done |
| VerifyRawTransaction | `API#verify_raw_transaction` | POST `/safe/transaction/requests` | done |
| SendRawTransaction | `API#send_safe_transaction` | POST `/safe/transactions` | done |
| BuildRawTransaction | `API#build_safe_transaction` | local | done |
| RequestGhostRecipientsWithTraceId | `API#request_ghost_recipients_with_trace_id` | POST `/safe/keys` | done |
| RequestSafeGhostKeys | `API#create_safe_keys` | POST `/safe/keys` | done |
| CreateMultisigRawTx | `API#create_multisig_raw_tx` | local + keys | done |
| CreateObjectStorageTransaction | `API#create_object_storage_transaction` | pipeline | done |
| EstimateStorageCost | `API#estimate_storage_cost` | local | done |
| StorageRecipient | `API#storage_recipient` | local | done |
| SendKernelTransactionFromAccount | `API#send_kernel_transaction_from_account` | documented N/I | done |
| **Multisig** |
| CreateSafeMultisigRequest | `API#create_safe_multisig_request` | POST `/safe/multisigs` | done |
| FetchSafeMultisigRequest | `API#safe_multisig_request` | GET `/safe/multisigs/:id` | done |
| ReadMultisigs* | `API#read_multisigs` / `#legacy_outputs` | GET `/multisigs/outputs` | done |
| CreateMultisig / Sign / Unlock / Cancel | `API#create_*_multisig_*` | legacy paths | done |
| **Snapshots** |
| SafeSnapshots* | `API#safe_snapshots` | GET `/safe/snapshots` | done |
| SafeSnapshotById | `API#safe_snapshot` | GET `/safe/snapshots/:id` | done |
| SafeNotifySnapshot | `API#create_safe_snapshot_notification` | POST notifications | done |
| Snapshots / SnapshotById / SnapshotByTraceId | `API#snapshots`, `#snapshot`, `#snapshot_by_trace_id` | legacy | done |
| NetworkSnapshot* | `API#network_snapshot(s)` | legacy | done |
| **Withdrawals / addresses** |
| CreateAddress / ReadAddress / DeleteAddress | `API#create_withdraw_address`, etc. | `/addresses` | done |
| GetAddressesByAssetId | `API#withdraw_addresses` | GET `/assets/:id/addresses` | done |
| CheckAddress | `API#check_address` | GET `/external/addresses/check` | done |
| SendWithdrawal | `API#withdrawals` | POST `/withdrawals` | done |
| **Conversations / messages** |
| CreateContactConversation | `API#create_contact_conversation` | POST `/conversations` | done |
| CreateGroupConversation | `API#create_group_conversation` | POST `/conversations` | done |
| ConversationShow | `API#conversation` | GET `/conversations/:id` | done |
| JoinConversation | `API#join_conversation` | POST `.../join` | done |
| RotateConversation | `API#rotate_conversation` | POST `.../rotate` | done |
| UpdateParticipants | `API#add/remove/..._participants` | POST participants | done |
| PostMessage(s) | `API#send_message` | POST `/messages` | done |
| EncryptMessageData / DecryptMessageData | `API#encrypt_message` / `#decrypt_message` | local | done |
| BlazeClient send helpers | `API#blaze_send_*` | WebSocket | done |
| **Inscriptions** |
| ReadCollection / ReadInscription / ReadCollectionItems | `API#collection`, `#collectible`, etc. | safe inscriptions | done |
| **Apps** |
| Migrate | `API#transfer_app_ownership` | POST `/apps/:id/transfer` | done |
| **Codes** |
| ReadCode | `API#read_code` | GET `/codes/:id` | done |
| **TIP** |
| GetTipNodeByPath* | `API#get_tip_node` | GET `/external/tip/:path` | done |
| TipBodyFor* | `API#tip_body_for_*` | local | done |
| **Network misc** |
| GetTurnServer | `API#turn_servers` | GET `/turn` | done |
| CallKernelRPC | `API#rpc_proxy` | POST `/external/kernel` | done |
| **Mix / invoice** |
| NewUUIDMixAddress / NewMainnetMixAddress | `MixAddress` | local | done |
| MixAddress.RequestOrGenerateGhostKeys | `MixAddress#request_or_generate_ghost_keys` | local/API | done |
| NewMixinInvoice | `MixinBot::Invoice` | local | done |
| **URL schemes** |
| SchemeUsers / Transfer / Pay / … | `MixinBot::UrlScheme` | local | done |
| **Utils** |
| UniqueObjectId | `MixinBot.utils.unique_object_id` | local | done |
| UniqueConversationId | `MixinBot.utils.unique_uuid` | local | done |
| GroupConversationId | `MixinBot.utils.generate_group_conversation_id` | local | done |
| Chunked / MakeUniqueStringSlice | `MixinBot.utils.chunked`, `#make_unique_string_slice` | local | done |
| **Computer** |
| GetComputerInfo | `MixinBot::Computer.info` / `API#get_computer_info` | computer.mixin.one | done |
| GetComputerUser | `API#get_computer_user` | done |
| GetComputerDeployedAssets | `API#get_computer_deployed_assets` | done |
| GetComputerSystemCall | `API#get_computer_system_call` | done |
| ComputerDeployExternalAsset | `API#computer_deploy_external_asset` | done |
| LockComputerNonceAccount | `API#lock_computer_nonce_account` | done |
| GetFeeOnXINBasedOnSOL | `API#get_fee_on_xin_based_on_sol` | done |
| RegisterComputer | `API#register_computer` | done |
| ComputerUserIDToBytes | `API#computer_user_id_to_bytes` | done |
| BuildSystemCallExtra | `API#build_system_call_extra` | done |
| EncodeOperationMemo / EncodeMtgExtra / DecodeComputerExtraBase64 | `API#encode_*` | done |
| **BotAuth** |
| NewBotAuthClient / SignRequest | `MixinBot::BotAuth` | local | done |
| **Monitor** |
| ReportToMonitor | `MixinBot::Monitor.report_to_monitor` | pipeline | done |
| UnmarshalAppMessage | `MixinBot::Monitor.unmarshal_app_message` | local | done |
| CheckRetryableError | `MixinBot::Monitor.check_retryable_error` | local | done |
| **HTTP config** |
| Request / SetBaseUri / SetBlazeUri | `MixinBot::Configuration`, `Client` | config | n/a |
| NewSafeUser | `MixinBot::Configuration` | config | n/a |
| cli/*, examples/*, mixin/rpc main | `mixinbot call` / `mixinbot list` | CLI dispatch to `MixinBot::API` | done |

## Node SDK

TS-only or Node-first REST surfaces. Ruby methods follow snake_case; aliases mirror TS names where helpful.

| TS symbol | Ruby method | HTTP / notes | Status |
|-----------|-------------|--------------|--------|
| **Circle** |
| circle.fetch | `API#circle` | GET `/circles/:id` | done |
| circle.fetchList | `API#circles` | GET `/circles` | done |
| circle.conversations | `API#circle_conversations` | GET `/circles/:id/conversations` | done |
| circle.create | `API#create_circle` | POST `/circles` | done |
| circle.update | `API#update_circle` | POST `/circles/:id` | done |
| circle.delete | `API#delete_circle` | POST `/circles/:id/delete` | done |
| circle.addUser | `API#add_user_to_circle` | POST `/users/:id/circles` | done |
| circle.removeUser | `API#remove_user_from_circle` | POST `/users/:id/circles` | done |
| circle.addConversation | `API#add_conversation_to_circle` | POST `/conversations/:id/circles` | done |
| circle.removeConversation | `API#remove_conversation_from_circle` | POST `/conversations/:id/circles` | done |
| **App** |
| app.fetch | `API#app` | GET `/apps/:id` | done |
| app.fetchList | `API#apps` | GET `/apps` | done |
| app.properties | `API#app_properties` | GET `/apps/property` | done |
| app.billing | `API#app_billing` | GET `/safe/apps/:id/billing` | done |
| app.create | `API#create_app` | POST `/apps` | done |
| app.update | `API#update_app` | POST `/apps/:id` | done |
| app.updateSecret | `API#rotate_app_secret` | POST `/apps/:id/secret` | done |
| app.updateSafeSession | `API#update_app_safe_session` | POST `/safe/apps/:id/session` | done |
| app.registerSafe | `API#register_app_safe` | POST `/safe/apps/:id/register` | done |
| app.favorite / unfavorite | `API#add_favorite_app` / `#remove_favorite_app` | POST `/apps/:id/favorite` | done |
| app.favorites | `API#favorite_apps` | GET `/users/:id/apps/favorite` | done |
| app.migrate | `API#transfer_app_ownership` | POST `/apps/:id/transfer` | done |
| **OAuth** |
| oauth.getToken | `API#oauth_token` | POST `/oauth/token` | done |
| oauth.authorize | `API#authorize_code` | POST `/oauth/authorize` | done |
| oauth.authorizations | `API#authorizations` | GET `/authorizations` | done |
| oauth.revokeAuthorize | `API#revoke_authorization` | POST `/oauth/cancel` | done |
| **User** |
| user.profile | `API#me` | GET `/me` | done |
| user.friends | `API#friends` | GET `/friends` | done |
| user.blockings | `API#blocking_users` | GET `/blocking_users` | done |
| user.rotateCode | `API#rotate_user_code` | GET `/me/code` | done |
| user.search | `API#search_user` | GET `/search/:q` | done |
| user.fetch | `API#user` | GET `/users/:id` | done |
| user.fetchList | `API#fetch_users` | POST `/users/fetch` | done |
| user.createBareUser | `API#create_user` | POST `/users` | done |
| user.update | `API#update_me` | POST `/me` | done |
| user.updatePreferences | `API#update_preferences` | POST `/me/preferences` | done |
| user.updateRelationships | `API#relationship` | POST `/relationships` | done |
| user.logs | `API#user_logs` | GET `/logs` | done |
| **Conversation** |
| conversation.mute / unmute | `API#mute_conversation` / `#unmute_conversation` | POST `/conversations/:id/mute` | done |
| conversation.disappearDuration | `API#set_conversation_disappear_duration` | POST `/conversations/:id/disappear` | done |
| conversation.updateGroupInfo | `API#update_conversation` | POST `/conversations/:id` | done |
| conversation.* (CRUD/participants) | `API#conversation`, `#create_*`, `#join_*`, etc. | various | done |
| **Message** |
| message.sendAcknowledgement(s) | `API#acknowledge_message` / `#acknowledge_messages` | POST `/acknowledgements` | done |
| message.sendSticker/Audio/Video/Live/Location/Transfer | `API#send_*_message` | POST `/messages` | done |
| message.sendText/Image/File/Post/Contact/AppCard/AppButton/Recall | `API#send_*_message` | POST `/messages` | done |
| **Code** |
| code.fetch | `API#read_code` | GET `/codes/:id` | done |
| code.schemes | `API#create_scheme` | POST `/schemes` | done |
| **Address** |
| address.fetchListOfChain | `API#safe_withdraw_addresses` | GET `/safe/addresses?chain=` | done |
| address.fetch/create/delete | `API#get_withdraw_address`, `#create_withdraw_address`, `#delete_withdraw_address` | `/addresses` | done |
| **External** |
| external.proxy | `API#external_proxy` | POST `/external/proxy` | done |
| external.deposits | `API#transactions` (legacy) | GET `/external/transactions` | done |
| external.checkAddress | `API#check_address` | GET `/external/addresses/check` | done |
| external.exchangeRates | `API#fiats` | GET `/external/fiats` | done |
| **Safe / UTXO / Transfer / Network / etc.** |
| safe.* / utxo.* / transfer.* / network.* | spread across existing `API` modules | same HTTP paths as TS | done |
| **Blaze** |
| blaze.loop | `API#blaze` | WebSocket | done |
| **WebView** |
| WebViewApi | — | browser bridge | n/a |

Update this file when adding or changing API surfaces. Run `rake mixin_bot:api_coverage` to ensure no `missing` rows remain.
