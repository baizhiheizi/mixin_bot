# Tasks: cover-upstream-sdk-gaps

## 1. Quick wins (fees, chains, silent)

- [x] 1.1 Add `API#safe_fees` (`GET /safe/fees`) in `lib/mixin_bot/api/asset.rb` next to `asset_fee`; add a WebMock test asserting the request path and envelope `data` passthrough; verify `ruby -Itest -Ilib test/mixin_bot/asset_test.rb` passes and `mixinbot list` shows the new method
- [x] 1.2 Fetch exact chain ids for HyperEVM, Pearl, X Layer, Robinhood and USDT/USDC asset ids for HyperEVM/X Layer/Sui from upstream `bot-api-go-client` (`chain.go`, `asset.go`); record them in the task notes
  <!-- HyperEVM 36d23d9e-bf4e-3ede-a12d-26f1f1f9fd2f · X Layer 37f5a4d1-905f-3b34-8291-c37438c7dcfc · Robinhood b304e03d-d004-3102-875b-8266f8407a1a · Pearl e1bf305c-0d49-397d-85bd-55b9eaadafba · USDT_HYPEREVM 3782f986-a053-33ae-b6bf-460abb62ce49 · USDT_XLAYER c4d9746a-20be-321c-baca-d378534dd4eb · USDC_HYPEREVM 1e01fede-51fa-3791-9b06-5c18801b272c · USDC_XLAYER 8d706a25-514c-3c73-9446-c25fd07d0ae2 · USDC_SUI a0f7ad61-3b9f-30f3-a1de-cd831aec33ff -->
- [x] 1.3 Add the four chains to `CHAIN_NAMES` in `lib/mixin_bot/api/chain.rb` and the stablecoin ids to a `CHAIN_STABLECOIN_ASSET_IDS` hash plus flat constants; add offline tests asserting each new id resolves via `chain_name`/`chain_id?` and matches the constant; verify the chain test file passes
  <!-- Also fixed the Sui chain id to the upstream-corrected value 3acb25e4-6216-35c3-b1ca-87184269ee08 (upstream commit 8b686d5, 2026-06-09) -->
- [x] 1.4 Add `silent: options[:silent]` to `base_message_params` in `lib/mixin_bot/api/message.rb`; add WebMock tests that a silent send includes the field and a plain send omits it (byte-identical payload to current); verify message tests pass

## 2. HTTP timeout configuration

- [x] 2.1 Add `:http_timeout` to `CONFIGURABLE_ATTRS` in `lib/mixin_bot/configuration.rb` and apply `f.request :timeout` in `MixinBot::Client`'s Faraday block only when set; add a test that a configured timeout reaches the Faraday connection and that the default leaves the connection unchanged; verify client/configuration tests pass
  <!-- Implemented as `f.options.timeout = @config.http_timeout if @config.http_timeout` (Faraday 2 canonical form); also fixed the latent `Client.new(nil)` fallback bug (URL/logger used the nil local instead of @config) -->
- [x] 2.2 Document `http_timeout` in the README configuration section alongside the existing config keys

## 3. Encrypted-message pipeline

- [x] 3.1 Create `MixinBot::SessionStore` (`lib/mixin_bot/session_store.rb`) with `fetch(user_id)`/`store(user_id, sessions)`; add unit tests for cache hit/miss/overwrite; verify they pass
- [x] 3.2 Implement `API#post_encrypted_messages(messages, session_store: nil, **kwargs)` in `lib/mixin_bot/api/encrypted_message.rb`: resolve recipients via store-or-`fetch_user_sessions`, encrypt with existing `encrypt_message`, batch-post to `/encrypted_messages`; add WebMock tests for first-send (fetch → store → post) and cache-reuse (no second `/sessions/fetch`); verify they pass
- [x] 3.3 Add the one-shot retry: on `FAILED` responses re-fetch affected recipients' sessions, overwrite the store, re-encrypt, re-post once, and return the final per-recipient responses (`state` `SUCCESS`/`FAILED`); add WebMock tests for the expiry-retry path and a permanent failure that reports `FAILED` after one retry; verify they pass
- [x] 3.4 Verify a custom session store is used in place of the default (test with a stub store recording fetch/store calls)

## 4. Utility and helper parity

- [x] 4.1 Add `format_units`/`parse_units` in `lib/mixin_bot/utils/amount.rb` (integer/string math, `ArgumentError` on excess fractional digits); test round-trips incl. `parse_units('0.1', 18) == 10**17`; verify utils tests pass
  <!-- Verified upstream Node amount.ts uses BigNumber ROUND_FLOOR: parse_units floors over-precise values (no ArgumentError) and format_units trims trailing zeros; design.md updated -->
- [x] 4.2 Add `MixinBot.utils.oauth_code_challenge(verifier)` and validate it against the RFC 7636 test vector; verify the test passes
- [x] 4.3 Thread an optional `code_verifier` through `authorize_code`/`authorization_data` in `lib/mixin_bot/api/auth.rb`, keeping `code_challenge: ''` when absent; add tests for both branches; verify auth tests pass
  <!-- Params building extracted into `oauth_code_params` helper for offline testability; test_helper offline override updated to accept the third arg -->
- [x] 4.4 Extend `blaze_send_app_card` in `lib/mixin_bot/api/blaze.rb` with `cover_url:`/`actions:` keyword args omitted when nil; add payload tests for the extended and legacy shapes; verify blaze tests pass

## 5. Coverage doc, schema, and full gate

- [x] 5.1 Add `API_COVERAGE.md` rows for `ReadSafeFees`, `PostEncryptedMessages` (+ `SessionStore`, `EncryptedMessageResponse`), `MessageRequest.silent`, amount/PKCE utils, app-card fields, chain registry, and `SetHttpTimeout` (config `n/a` row); run `rake mixin_bot:api_coverage` and confirm zero `missing` entries
- [x] 5.2 Run `rake` (tests + RuboCop) and fix any offenses; confirm `mixinbot schema -o json` includes the new callable methods
  <!-- 482 tests / 997 assertions green; RuboCop clean. New methods verified via `mixinbot list --json` + `mixinbot call safe_fees` (schema is a static CLI-subcommand catalog; methods dispatch dynamically through `call`). Also fixed the pre-existing errors.rb rubocop disable/enable directive offense surfaced by rubocop 1.90 -->
