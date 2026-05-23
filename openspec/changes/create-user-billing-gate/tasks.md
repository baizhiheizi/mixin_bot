## 1. Error and App preflight

- [x] 1.1 Add `MixinBot::InsufficientAppBillingError` to `lib/mixin_bot/errors.rb` with `app_id`, `credit`, `cost`, `increment` readers and descriptive message
- [x] 1.2 Implement `App#ensure_app_billing_credit!(force: false, access_token: nil)` in `lib/mixin_bot/api/app.rb` using `BigDecimal`, `app_billing`, and `app_properties`

## 2. User API integration

- [x] 2.1 Add `force: false` keyword to `User#create_user` and invoke `ensure_app_billing_credit!` before `POST /users`
- [x] 2.2 Add `force: false` to `User#create_safe_user` and forward to `create_user`
- [x] 2.3 Add YARD docs for `force:` on both methods describing billing preflight behavior

## 3. CLI support

- [x] 3.1 Add `--force` option to `mixinbot call` in `lib/mixin_bot/cli/call.rb`; inject `force: true` only when method is `create_user` (respect `-d` override)
- [x] 3.2 Map `InsufficientAppBillingError` to `:billing` in `lib/mixin_bot/cli/errors.rb`; add to `ERROR_KINDS` schema metadata
- [x] 3.3 Update `docs/agent/cli.md` with `billing` error kind and `--force` usage example

## 4. Tests

- [x] 4.1 Extend WebMock stubs to support configurable billing/properties responses for preflight tests
- [x] 4.2 Add `test/mixin_bot/api/test_user.rb` cases: sufficient headroom, insufficient (no POST), free tier (`price: 0`), edge equality, and `force: true`
- [x] 4.3 Add `test/mixin_bot/api/test_app.rb` unit test for `ensure_app_billing_credit!` raise/pass paths
- [x] 4.4 Add CLI tests: structured `billing` error kind and `--force` on `create_user` vs no injection on `me`
- [x] 4.5 Run `rake test` and `rake rubocop`; fix any offenses

## 5. Changelog

- [x] 5.1 Add CHANGELOG entry under Unreleased for billing preflight, new error, and CLI `--force` / `billing` kind
