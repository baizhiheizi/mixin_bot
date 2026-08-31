# upstream-parity Specification

## Purpose

Keeps the gem's public API surface in parity with the official Mixin Go and Node SDKs for features added after the 2026-05-24 sync: the global Safe fee schedule, the automated encrypted-message send pipeline, the extended chain and stablecoin registry, configurable HTTP timeouts, silent messaging, and small amount/PKCE/app-card utility gaps.

## Requirements

### Requirement: Global Safe fee schedule

The API SHALL expose the global Safe fee schedule via `GET /safe/fees`, returning the list of fee entries (each with asset, chain, fee asset, fee amount, and priority) through the standard API envelope.

#### Scenario: Reading the fee schedule

- **WHEN** a caller requests the Safe fee schedule with valid credentials
- **THEN** the client sends `GET /safe/fees` and returns the fee entries from the response `data` field

#### Scenario: Listing callable methods

- **WHEN** the CLI lists or schemas callable API methods
- **THEN** the Safe fee schedule read appears as a callable method

### Requirement: Automated encrypted-message send pipeline

The API SHALL provide a send path that accepts unencrypted messages addressed by `recipient_id`, resolves each recipient's sessions, encrypts the payload for those sessions, and posts to `/encrypted_messages`. Recipient sessions SHALL be resolved through a session store: cached sessions are reused, and missing sessions are fetched via `POST /sessions/fetch`.

#### Scenario: Sending to recipients without cached sessions

- **WHEN** a caller sends an encrypted message to recipients whose sessions are not in the store
- **THEN** their sessions are fetched, the payload is encrypted for those sessions, and the request is posted to `/encrypted_messages`

#### Scenario: Reusing cached sessions

- **WHEN** a recipient's sessions were fetched during an earlier send in the same process
- **THEN** the store's cached sessions are used and no additional `POST /sessions/fetch` call is made for that recipient

#### Scenario: Retrying after session expiry

- **WHEN** the server reports a recipient's sessions have expired
- **THEN** the pipeline re-fetches that recipient's sessions, re-encrypts, and retries the send once

#### Scenario: Reporting per-recipient outcomes

- **WHEN** the send completes
- **THEN** the caller can determine each recipient's outcome state (`SUCCESS` or `FAILED`) from the response

#### Scenario: Pluggable session store

- **WHEN** a caller supplies a custom session store
- **THEN** the pipeline uses it instead of the default in-memory store

### Requirement: Extended chain registry

The chain registry SHALL resolve the names of the HyperEVM, Pearl, X Layer, and Robinhood chains added upstream since the sync, and the chain-id predicate SHALL recognize their ids. The registry SHALL also expose the upstream stablecoin asset-id constants for these chains (per-chain USDT/USDC).

#### Scenario: Resolving a newly added chain

- **WHEN** a caller asks for the chain name of any newly added chain id
- **THEN** the registry returns the upstream chain name (HyperEVM, Pearl, X Layer, or Robinhood)

#### Scenario: Chain-id recognition

- **WHEN** a caller tests any newly added chain id with the chain-id predicate
- **THEN** it returns true, and unrelated UUIDs still return false

### Requirement: Configurable HTTP timeout

Configuration SHALL accept an HTTP timeout (in seconds) that the HTTP client applies to every request. When unset, behavior SHALL be unchanged from the current release.

#### Scenario: Configuring a timeout

- **WHEN** the caller configures an HTTP timeout of N seconds
- **THEN** API requests abort with a timeout error after N seconds instead of hanging indefinitely

#### Scenario: Default behavior preserved

- **WHEN** no HTTP timeout is configured
- **THEN** requests behave exactly as in the current release (no timeout applied)

### Requirement: Silent message sending

REST message sends SHALL accept an optional silent flag that is forwarded to the server, telling the recipient's client to suppress the notification.

#### Scenario: Sending a silent message

- **WHEN** a caller sends a REST message with the silent flag set
- **THEN** the outgoing request body includes the flag

#### Scenario: Omitting the flag

- **WHEN** a caller sends a REST message without the silent flag
- **THEN** the outgoing request body contains no silent field, matching the current wire format

### Requirement: Amount formatting utilities

The utilities module SHALL provide decimal-safe unit conversion between human-readable amounts and integer minor units for a given number of decimals, without floating-point loss.

#### Scenario: Formatting to a decimal string

- **WHEN** the caller formats integer minor units with a decimals count
- **THEN** the result is the exact decimal string with no float rounding error

#### Scenario: Parsing a decimal string

- **WHEN** the caller parses a decimal amount string with a decimals count
- **THEN** the result is the exact integer minor-unit value

### Requirement: OAuth PKCE challenge utility

The utilities module SHALL derive an OAuth PKCE code challenge from a code verifier (S256), and the OAuth authorization-data flow SHALL accept an optional code verifier, sending its derived challenge instead of the current empty value.

#### Scenario: Deriving a challenge

- **WHEN** the caller derives a code challenge from a verifier
- **THEN** the result is the base64url-encoded SHA-256 digest of the verifier without padding

#### Scenario: Authorization with PKCE

- **WHEN** the caller supplies a code verifier to the authorization-data flow
- **THEN** the outgoing parameters carry the derived challenge; without a verifier the current empty-challenge behavior is unchanged

### Requirement: Rich app card over Blaze

The Blaze app-card helper SHALL accept the extended card fields (`cover_url` and `actions`) added upstream, in addition to the existing title/description/icon/action fields.

#### Scenario: Sending a card with cover and actions

- **WHEN** a caller sends a Blaze app card with a cover URL and action list
- **THEN** the outgoing card payload includes both fields

#### Scenario: Backward-compatible card sends

- **WHEN** a caller sends a Blaze app card without the new fields
- **THEN** the payload matches the previous format
