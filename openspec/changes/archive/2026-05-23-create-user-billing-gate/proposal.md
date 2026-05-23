## Why

Creating a Mixin network user via `POST /users` is billed against the parent app's prepaid credit. If credit falls below accumulated cost, the entire app API can stop working—not just user creation. The SDK currently calls `create_user` with no client-side check, so a single call can push an already-strained app into lockout. A preflight gate with an explicit escape hatch protects operators while preserving opt-in force behavior for advanced use.

## What Changes

- Add `App#ensure_app_billing_credit!` that compares app credit against total cost plus the next user fee (headroom), using `app_billing` and `app_properties`.
- Gate `User#create_user` with that check by default; skip when `force: true`.
- Introduce `MixinBot::InsufficientAppBillingError` with structured fields (`app_id`, `credit`, `cost`, `increment`).
- Forward `force:` from `create_safe_user` to `create_user` (no separate gate on the high-level method).
- CLI: add `--force` on `mixinbot call create_user` (scoped injection), map the new error to kind `billing`, document in agent CLI docs.
- Offline tests for pass, block, free-tier, edge, and force paths.

## Capabilities

### New Capabilities

- `create-user-billing-gate`: Client-side billing preflight before `create_user`, including Ruby API `force:` keyword, `InsufficientAppBillingError`, and CLI `--force` / `billing` error kind.

### Modified Capabilities

- _(none — no existing OpenSpec capability specs in this repository)_

## Impact

- **API**: `lib/mixin_bot/api/app.rb`, `lib/mixin_bot/api/user.rb`
- **Errors**: `lib/mixin_bot/errors.rb`
- **CLI**: `lib/mixin_bot/cli/call.rb`, `lib/mixin_bot/cli/errors.rb`, `docs/agent/cli.md`
- **Tests**: `test/mixin_bot/api/test_user.rb`, `test/mixin_bot/api/test_app.rb`, `test/mixin_bot/cli/test_errors.rb`, WebMock stubs in `test/support/mixin_api_stubs.rb`
- **Not gated**: raw `mixinbot api POST /users`, `migrate_to_safe`, `safe_register`
