## ADDED Requirements

### Requirement: Billing preflight before create_user

The SDK SHALL call `ensure_app_billing_credit!` at the start of `User#create_user` unless `force: true` is passed.

The preflight SHALL fetch `app_billing` for `config.app_id` and `app_properties` for the next user fee.

The preflight SHALL compute `cost = cost.users + cost.resources` and `increment = price` from app properties (default `0` if missing).

The preflight SHALL allow the request only when `credit > cost + increment` (strict inequality, using decimal comparison).

#### Scenario: Sufficient headroom

- **WHEN** `create_user` is called with default options
- **AND** billing returns credit greater than total cost plus increment
- **THEN** the SDK posts to `POST /users`

#### Scenario: Insufficient headroom

- **WHEN** `create_user` is called with default options
- **AND** billing returns credit less than or equal to total cost plus increment
- **THEN** the SDK raises `InsufficientAppBillingError`
- **AND** does not post to `POST /users`

#### Scenario: Force skips preflight

- **WHEN** `create_user` is called with `force: true`
- **THEN** the SDK does not call billing/properties preflight
- **AND** posts to `POST /users`

#### Scenario: Free tier increment zero

- **WHEN** `app_properties` returns `price` of `"0"`
- **AND** credit is greater than total cost
- **THEN** the SDK allows `create_user`

### Requirement: InsufficientAppBillingError

The SDK SHALL define `MixinBot::InsufficientAppBillingError` exposing `app_id`, `credit`, `cost`, and `increment`.

The error message SHALL indicate insufficient app billing credit and include the compared values.

#### Scenario: Error fields populated

- **WHEN** billing preflight fails for insufficient headroom
- **THEN** the raised error includes the app id, credit, total cost, and increment used in the comparison

### Requirement: create_safe_user forwards force

`User#create_safe_user` SHALL accept an optional `force:` keyword and pass it to `create_user`.

#### Scenario: create_safe_user with force

- **WHEN** `create_safe_user` is called with `force: true`
- **THEN** `create_user` is invoked with `force: true`

### Requirement: CLI billing error kind

The CLI SHALL map `InsufficientAppBillingError` to structured error kind `billing` when `--output json` (or piped) is used.

#### Scenario: Structured billing error

- **WHEN** `mixinbot call create_user` fails due to insufficient app billing
- **AND** output is structured JSON
- **THEN** stderr contains `"kind": "billing"`

### Requirement: CLI force flag for create_user

The `mixinbot call` command SHALL accept `--force` that sets `force: true` when the invoked method is `create_user`.

The flag SHALL NOT inject `force` into kwargs for other API methods.

#### Scenario: CLI force on create_user

- **WHEN** user runs `mixinbot call create_user NAME -k KEYSTORE --force`
- **THEN** the SDK invokes `create_user` with `force: true`

#### Scenario: CLI force not injected for other methods

- **WHEN** user runs `mixinbot call me -k KEYSTORE --force`
- **THEN** `force` is not passed to `me`
