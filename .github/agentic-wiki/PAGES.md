# Home

*[MixinBot](https://github.com/baizhiheizi/mixin_bot) is a Ruby SDK (gem version 3.0.3) and CLI for [Mixin Network](https://developers.mixin.one/docs). It mirrors the official Go and Node SDKs and exposes authenticated REST calls, Safe UTXO transfers, Blaze messaging, network asset catalogs, inscriptions, invoices, transaction encoding, and optional MVM helpers.*

## Project overview

*{ Summarize the gem, its scope (REST SDK + CLI + optional Rails layer + optional MVM), the SDKs it parallels (bot-api-go-client, bot-api-nodejs-client), and the Ruby/runtime requirements (Ruby >= 4.0, Bundler 2.6+). }*

## Quick links

*[Project README](https://github.com/baizhiheizi/mixin_bot/blob/main/README.md) covers installation and basic usage. [[Getting Started|Getting-Started]] walks through configuration and your first call. [[Architecture|Architecture]] explains how the modules compose. [[API Reference|API-Reference]] documents each domain. [[Rails Integration|Rails-Integration]] covers the optional Rails layer.*

# Getting Started

## Installation

*{ Document the two install paths: Bundler (`gem 'mixin_bot'`) and direct install (`gem install mixin_bot`). Note that the gem ships the `mixinbot` executable and that the `mixin` CLI is optional. }*

## First call

*{ Walk through configuring credentials with `MixinBot.configure`, calling `MixinBot.api.me`, and reading `MixinBot.api.assets`. Show a minimal Safe transfer via `create_transfer` including the `spend_key` requirement. }*

####+ Prerequisites
*{ Ruby >= 4.0, Bundler 2.6+ recommended, optional `mixin` CLI for the native encoder helpers. }*

####+ Common commands
*{ Enumerate the rake tasks: `rake`, `rake test`, `rake test_live`, `rake mixin_bot:api_coverage`, `rake rdoc`, `rake build`, `rake publish`. }*

# Configuration

## Configuration object

*{ Explain `MixinBot::Configuration` and its attribute list (app_id, client_secret, session_id, session_private_key, server_public_key, spend_key, pin, api_host, blaze_host, http_timeout, debug, blaze_handler, blaze_ack_policy). Cover key aliasing (`client_id` -> `app_id`, `private_key` -> `session_private_key`, `pin_token` -> `server_public_key`) and automatic Ed25519/Curve25519 format conversions. }*

####+ Keystores
*{ Describe the JSON keystore consumed by the CLI via `-k`/`--keystore` and the `setup_api_instance!` flow that turns it into an `API` instance. }*

####+ Multiple bots
*{ Show creating dedicated `MixinBot::API.new(...)` instances per bot, in contrast to the global singleton via `MixinBot.api`, and the named `MixinBot.register_bot` registry. }*

# Architecture

## Module composition

*{ Explain that `MixinBot::API` (in `lib/mixin_bot/api.rb`) composes ~40 domain modules through Ruby `include`. List the modules: Me, User, Session, Asset, NetworkAsset, Network, Chain, Fiat, Transfer, Transaction, Output, Deposit, Address, Snapshot, Payment, Multisig, Message, EncryptedMessage, Blaze, BlazeAsync, Conversation, Circle, Attachment, App, Auth, Code, Turn, Rpc, ComputerApi, External, Inscription, Withdraw, and the `legacy_*` modules. }*

```mermaid
flowchart LR
  CLI[CLI Thor] --> API[MixinBot::API]
  Config[MixinBot::Configuration] --> API
  API --> Client[MixinBot::Client Faraday]
  API --> Modules[Domain Modules]
  Modules --> Client
  Client --> Mixin[Mixin Network REST]
```

## HTTP client

*{ Document `MixinBot::Client`: Faraday-based, signs JWT access tokens via `MixinBot::Utils.access_token`, retries on `Faraday::ConnectionFailed`/`TimeoutError`, returns `MixinBot::Models::ApiEnvelope`. Mention `get`, `post`, `fetch_get`, `fetch_post`, `fetch_post_array` and the `res['data']` / delegated lookup pattern. }*

## Request lifecycle

```mermaid
sequenceDiagram
  participant Caller
  participant Client
  participant Utils
  participant Mixin as Mixin API
  Caller->>Client: get/post with kwargs
  Client->>Utils: sign_token(method,uri,body)
  Utils-->>Client: JWT
  Client->>Mixin: HTTP request with Bearer
  Mixin-->>Client: JSON envelope
  Client->>Client: parse_response! map errors
  Client-->>Caller: ApiEnvelope
```

# API Reference

*{ Overview of the public API surface: every `MixinBot::API` instance method falls into one of the domain modules. Methods prefixed `safe_*` use the Safe UTXO pipeline; methods prefixed `legacy_*` are deprecated and emit a deprecation warning once. Interactive WebSocket flows (Blaze connect, upload) are not callable from the CLI. }*

####+ Profile & Users
*{ `me`, `safe_me`, `update_me`, `user`, `fetch_users`, `search_user`, `create_user`, `safe_register`, `migrate_to_safe`, `friends`. Explain how to retrieve the bot profile and look up counterparties. }*

####+ Assets & Network
*{ `assets`, `asset`, `network_assets`, `network_asset`, `network_ticker`, `ticker`, `fiats`, `network_chain`, `network_chains`, `safe_fees`, `asset_balance`. Distinguish the bot-scoped asset catalog from the public network catalog. }*

####+ Transfers (Safe pipeline)
*{ `create_transfer`, `create_safe_transfer`, `safe_outputs`, `build_safe_transaction`, `verify_raw_transaction`, `sign_safe_transaction`, `send_safe_transaction`. Walk through the UTXO select -> build -> verify -> sign -> submit sequence. }*

####+ Transactions
*{ `transactions`, `safe_transaction`, `verify_transaction`, `create_safe_keys`, `build_object_transaction`, `build_inscribe_transaction`, `create_object_storage_transaction`. Reference `MixinBot::Transaction` (`SAFE_TX_VERSION = 0x05`) for the underlying envelope. }*

####+ Multisig
*{ `safe_multisig_*` operations and `MixinBot::API::Multisig`: registering member hashes, ghost-key derivation, threshold configuration. }*

####+ Messaging & Blaze
*{ `start_blaze_connect`, `blaze_async`, `blaze_send_plain_text`, `blaze_send_recall_message`, `send_message`, `send_encrypted_messages`, `conversations`, `create_conversation`. Note the EventMachine/Faye WebSocket lifecycle and `MixinBot::API::Blaze`. }*

####+ Snapshots & Outputs
*{ `safe_snapshots`, `safe_snapshot`, `safe_snapshot_by_trace`, `create_safe_snapshot_notification`, `safe_outputs`, `pending_safe_deposits`, `safe_deposit_entries`. }*

####+ NFTs & Inscriptions
*{ `collection`, `collectible`, `collectibles`, `create_collectible_transfer`, `create_collectible_request`, `mint`, `inscriptions`, `inscription`. Cross-reference the MVM NFT helpers. }*

####+ Auth & Sessions
*{ `app`, `update_app`, `update_app_security`, `code`, `oauth_token`, `request_oauth`, `authorize_code`, `sign_oauth_access_token`, `fetch_user_sessions`. }*

####+ Pin & Tip
*{ `verify_pin`, `create_pin`, `update_pin`, `update_tip_pin`, `encrypt_tip_pin`, `get_tip_node`, `tip_body_for_*`. }*

####+ Withdrawals & Deposits
*{ `create_withdrawal`, `withdrawal`, `withdrawals`, `safe_withdraw_addresses`, `create_withdraw_address`, `check_address`, deposit addresses and `MixinBot::MixAddress`/`MixinBot::URLScheme`. }*

####+ Legacy APIs (deprecated)
*{ Briefly enumerate the `legacy_*` modules and explain the deprecation policy: warn once via `MixinBot.deprecator`, slated for removal in 3.0.0. }*

# Safe Pipeline

## Why Safe

*{ Contrast the Safe UTXO API with the legacy transfer API. Explain that Safe offers better security (Ed25519 spend key signing), lower fees, and finer-grained control over inputs/outputs. }*

## Pipeline stages

```mermaid
flowchart LR
  A[build_utxos] --> B[build_safe_transaction]
  B --> C[verify_raw_transaction]
  C --> D[sign_safe_transaction]
  D --> E[send_safe_transaction]
```

## Minimal example

*{ Provide a code block showing `create_transfer` (or the explicit `build_utxos` -> `build_safe_transaction` -> ... sequence) with `spend_key`, asset_id, members/threshold, amount, memo, and trace_id. Reference `MixinBot::Utils::Encoder` for low-level encoding. }*

# CLI

## mixinbot command

*{ Document the Thor-based CLI in `lib/mixin_bot/cli.rb`: `mixinbot call METHOD`, `mixinbot list [FILTER]`, `mixinbot schema -o json|yaml`, `mixinbot utils call/list`, plus `mixinbot version`. Note that interactive Blaze connect and upload methods are excluded from `mixinbot call` and require the Ruby API. }*

## Output formats

*{ Explain `--output pretty|json|yaml`, `--pretty`, and the CLI's mapping of internal errors to structured `kind` (`auth`, `api_error`, `not_found`). }*

# Transactions

## Transaction envelope

*{ Document `MixinBot::Transaction` (SAFE_TX_VERSION = 0x05), `MixinBot::Transaction::Encoder`, and `MixinBot::Transaction::Decoder`. Cover the magic prefix, MAX_EXTRA_SIZE = 512, aggregated signature masks, and references-version support (0x04). }*

## Encoder & Decoder

*{ Reference `MixinBot::Utils::Encoder`/`Utils::Decoder` for low-level int/binary packing and the wrapper methods `encode_raw_transaction` / `decode_raw_transaction` (Ruby + native `mixin` CLI fallback). }*

# Utils & Crypto

*{ Explain `MixinBot::Utils` as a composition of five sub-modules: Address, Amount, Crypto, Decoder, Encoder. Show access via `MixinBot.utils` or `api.utils`. }*

####+ Crypto helpers
*{ `access_token` (JWT signing), `generate_ed25519_key`, `encrypt_pin`, `decode_key`, `unique_uuid`. }*

####+ Address helpers
*{ Main address, ghost-key derivation, address validation - tied to `MixinBot::Address` and `lib/mixin_bot/utils/address.rb`. }*

# MVM

## Overview

*{ Document the optional `MVM` (Mixin Virtual Machine) helpers under `lib/mvm/`: `MVM::Bridge`, `MVM::Client`, `MVM::Nft`, `MVM::Registry`, `MVM::Scan`. Cover `MVM.bridge`, `MVM.nft`, `MVM.scan`, `MVM.registry` singletons and the constants `RPC_URL`, `MIRROR_ADDRESS`, `REGISTRY_ADDRESS`. }*

## ERC-20/721/1155

*{ Explain that MVM exposes the standard contract ABIs (`lib/mvm/abis/erc20.json`, `erc721.json`, `bridge.json`, `mirror.json`, `registry.json`) for cross-chain and NFT operations. }*

# Errors & Error Handling

## Error hierarchy

*{ Outline the base `MixinBot::Error` / `MixinBot::APIError` hierarchy in `lib/mixin_bot/errors.rb`. Map specific subclasses to HTTP/API conditions: `ResponseError`, `UnauthorizedError`, `ForbiddenError`, `RateLimitError`, `ValidationError`, `ConflictError`, `TransferError`, `TransientError`, `ServerError`, `InsufficientBalanceError`, `UtxoInsufficientError`, `InsufficientPoolError`, `PinError`, `NotFoundError`, `UserNotFoundError`, `AppUpdateRequiredError`, `InvalidAddressFormatError`. }*

####+ Retries & throttling
*{ Explain `client_error?`, `retryable?`, `throttle?` predicates and the canonical `MixinBot.retryable?` helper used by callers and the Faraday retry middleware. }*

####+ Local validation errors
*{ Distinguish API errors from local argument errors: `MixinBot::ArgumentError`, `ConfigurationNotValidError`, `InvalidUuidFormatError`, `InvalidInvoiceFormatError`, `InvalidNfoFormatError`, `InvalidTransactionFormatError`. }*

# Models

*{ Describe `lib/mixin_bot/models/` (asset, user, output, api_envelope, address, safe_multisig_request, ghost_keys, sequencer_transaction_request) and how the HTTP client wraps responses in `MixinBot::Models::ApiEnvelope`. }*

# Rails Integration

*{ Explain that `require 'mixin_bot'` never loads Rails; `require 'mixin_bot/rails'` loads the integration layer, and the railtie is `MixinBot::Railtie` (never `MixinBot::Rails`, which would shadow `::Rails`). Describe the `app/mixin` Zeitwerk root, the `mixin_bot:poller` rake task, and the components the layer provides. }*

## Multi-bot registry
*{ `MixinBot.register_bot`, `MixinBot.bot(name)`, `MixinBot.bot_by_app_id(app_id)`, and how the router, poller, transfers and notifications accept a bot name. }*

## Blaze router
*{ `MixinBot::Blaze::Router`, the `on` DSL (category aliases and condition hashes), `Router::Base` handlers in `app/mixin/handlers`, and the `Router::Message#reply` helper. }*

## Outputs poller
*{ `MixinBot::Outputs::Poller`, `Processor`, `Processors.discover`, `Envelope` snapshot bridging, the `ReceiptModel` concern, the receipt-derived resume cursor, and the `mixin_bot:poller` task. }*

## Transfers and notifications
*{ `MixinBot::Transfers::Model` state machine, `Performer`, `Reconcile`, and `MixinBot::Notifications::MixinChannel` for the Noticed gem. }*

## Generators
*{ Enumerate the Rails generators under `mixin_bot:` — authentication, blaze, outputs, transfers, notifications, install — and the `--skip-<component>` flags of the install generator. }*

# Development

## Running tests

*{ Document the offline test suite (`rake test`) backed by WebMock stubs and the live mode (`LIVE=1 rake test_live`) requiring `test/config.yml`. Mention the fixtures under `test/fixtures/`. }*

## Linting & coverage

*{ Cover RuboCop (`rake rubocop`) and the parity task `rake mixin_bot:api_coverage` that checks the Ruby SDK against the official Go SDK endpoint catalog. }*

####+ OpenSpec workflow
*{ Describe the OpenSpec-driven change workflow: `opsx propose`, `opsx apply`, `opsx archive`, `opsx explore`. Point to the specs under `openspec/specs/` (api-coverage-gate, api-error-code-catalog, blaze-message-router, blaze-puma-plugin, ci-pipeline, create-user-billing-gate, dependency-updates, mixin-notifications, outbound-transfers, outputs-poller, rails-generators, rails-integration, release-publish, upstream-parity). }*

####+ Docs & RDoc
*{ Document `rake rdoc` (output in `doc/`), `docs/agent/cli.md` and `docs/agent/cookbook.md`, and the maintenance workflows under `.github/workflows/`. }*

# For Agents

These pages provide compact documentation indexes for AI coding agents.

## AGENTS.md

You can add this to your repository root as `AGENTS.md` to give AI coding agents quick access to project documentation.

```
# MixinBot
> Ruby SDK (gem 3.0.3) and CLI for Mixin Network: Safe UTXO transfers, Blaze messaging, Rails integration, MVM helpers.
Wiki: https://github.com/baizhiheizi/mixin_bot/wiki
To read any page: https://github.com/baizhiheizi/mixin_bot/wiki/{slug}
Section: https://github.com/baizhiheizi/mixin_bot/wiki/{slug}#{anchor}

## Page Index
|Home: Project overview and quick links
|Getting-Started: Install, configure, first call
|  Getting-Started#prerequisites: Ruby/Bundler/mixin CLI requirements
|  Getting-Started#common-commands: rake tasks
|Configuration: Configuration object, key conversion, keystores
|  Configuration#keystores: JSON keystore flow
|  Configuration#multiple-bots: per-instance API and registry
|Architecture: Module composition, HTTP client, request lifecycle
|API-Reference: Public API surface by domain
|  API-Reference#profile--users: me, safe_me, user, friends
|  API-Reference#assets--network: assets, network_assets, ticker, chains
|  API-Reference#transfers-safe-pipeline: create_transfer, build_safe_transaction, ...
|  API-Reference#transactions: safe_transaction, verify_raw_transaction
|  API-Reference#multisig: safe_multisig_*, member hashes
|  API-Reference#messaging--blaze: start_blaze_connect, send_message
|  API-Reference#snapshots--outputs: safe_snapshots, safe_outputs, deposits
|  API-Reference#nfts--inscriptions: collectibles, inscriptions
|  API-Reference#auth--sessions: app, session, oauth
|  API-Reference#pin--tip: verify_pin, tip_*
|  API-Reference#withdrawals--deposits: create_withdraw_address, deposits
|  API-Reference#legacy-apis-deprecated: legacy_* deprecations
|Safe-Pipeline: Safe UTXO pipeline stages and example
|CLI: mixinbot call/list/schema and output formats
|Transactions: Transaction envelope and encoder/decoder
|Utils-Crypto: Address, Amount, Crypto, Decoder, Encoder
|  Utils-Crypto#crypto-helpers: access_token, generate_ed25519_key, encrypt_pin
|  Utils-Crypto#address-helpers: main address, ghost keys
|MVM: Bridge, Nft, Registry, Scan (Mixin Virtual Machine)
|Errors-Error-Handling: APIError hierarchy, retry/throttle
|  Errors-Error-Handling#retries--throttling: retryable? / throttle?
|  Errors-Error-Handling#local-validation-errors: ArgumentError, ConfigurationNotValidError
|Models: ApiEnvelope and domain models
|Rails-Integration: Opting in, railtie, app/mixin autoload root
|  Multi-bot-registry: register_bot, bot, bot_by_app_id
|  Blaze-Router: Router, on DSL, handlers, Router::Message
|  Outputs-Poller: Poller, Processor, Envelope, ReceiptModel, receipt cursor
|  Transfers-and-Notifications: Transfers::Model, Performer, Reconcile, MixinChannel
|  Generators: mixin_bot:* generators and install flags
|Development: Tests, RuboCop, coverage, OpenSpec, RDoc
|  Development#openspec-workflow: opsx propose/apply/archive/explore
|  Development#docs--rdoc: rake rdoc and docs/agent/
```

## llms.txt

You can serve this at `yoursite.com/llms.txt` or include it in your repository to help LLMs discover your documentation.

```
# MixinBot
> Ruby SDK and CLI for Mixin Network (gem 3.0.3) with Safe UTXO transfers, Blaze messaging, a Rails integration layer, and MVM helpers.

## Wiki Pages
- [Home](https://github.com/baizhiheizi/mixin_bot/wiki/Home): Project overview and quick links
- [Getting Started](https://github.com/baizhiheizi/mixin_bot/wiki/Getting-Started): Install, configure, first call
- [Configuration](https://github.com/baizhiheizi/mixin_bot/wiki/Configuration): Configuration object, key conversion, keystores
- [Architecture](https://github.com/baizhiheizi/mixin_bot/wiki/Architecture): Module composition, HTTP client, request lifecycle
- [API Reference](https://github.com/baizhiheizi/mixin_bot/wiki/API-Reference): Public API surface by domain
- [Safe Pipeline](https://github.com/baizhiheizi/mixin_bot/wiki/Safe-Pipeline): UTXO select -> build -> sign -> submit
- [CLI](https://github.com/baizhiheizi/mixin_bot/wiki/CLI): mixinbot call/list/schema
- [Transactions](https://github.com/baizhiheizi/mixin_bot/wiki/Transactions): Transaction envelope and encoding
- [Utils & Crypto](https://github.com/baizhiheizi/mixin_bot/wiki/Utils-Crypto): Address, Amount, Crypto, Decoder, Encoder helpers
- [MVM](https://github.com/baizhiheizi/mixin_bot/wiki/MVM): Mixin Virtual Machine helpers
- [Errors & Error Handling](https://github.com/baizhiheizi/mixin_bot/wiki/Errors-Error-Handling): APIError hierarchy and retry semantics
- [Models](https://github.com/baizhiheizi/mixin_bot/wiki/Models): ApiEnvelope and domain models
- [Rails Integration](https://github.com/baizhiheizi/mixin_bot/wiki/Rails-Integration): Opting in, railtie, app/mixin autoload root
- [Multi-bot registry](https://github.com/baizhiheizi/mixin_bot/wiki/Multi-bot-registry): Registering and resolving named bots
- [Blaze Router](https://github.com/baizhiheizi/mixin_bot/wiki/Blaze-Router): Message routing DSL and handlers
- [Outputs Poller](https://github.com/baizhiheizi/mixin_bot/wiki/Outputs-Poller): Output polling, receipts and processors
- [Transfers and Notifications](https://github.com/baizhiheizi/mixin_bot/wiki/Transfers-and-Notifications): Transfer ledger state machine and Noticed channel
- [Generators](https://github.com/baizhiheizi/mixin_bot/wiki/Generators): Rails generators under the mixin_bot: namespace
- [Development](https://github.com/baizhiheizi/mixin_bot/wiki/Development): Tests, RuboCop, coverage, OpenSpec workflow
```
