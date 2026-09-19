## Why

mixin_bot today is a raw SDK + CLI: a Rails app that wants "Sign in with Mixin" must hand-wire OmniAuth middleware, session handling, the OAuth callback, and user upsert logic from scratch. Rails 8 set the expectation that one generator command produces a working auth skeleton (`rails g authentication`); a `rails g mixin_bot:authentication` generator brings the same experience to Mixin OAuth (via `omniauth-mixin`), making the gem the natural entry point for Rails-based Mixin apps.

## What Changes

- Add a Rails generator namespace to the gem under `lib/generators/mixin_bot/`; the first generator is `rails g mixin_bot:authentication`, modeled after Rails' built-in `authentication` generator.
- The generator produces an identity-only Mixin OAuth sign-in (per decision: OAuth tokens are NOT persisted):
  - `config/initializers/omniauth.rb` mounting the `:mixin` provider from `MIXIN_CLIENT_ID` / `MIXIN_CLIENT_SECRET` env vars.
  - Models `app/models/user.rb` (`mixin_user_id` unique + `name`, `avatar_url`), `app/models/session.rb` (DB-backed sessions à la Rails 8), `app/models/current.rb`.
  - Controllers `app/controllers/sessions_controller.rb` (new = sign-in page, create = OmniAuth callback that finds-or-creates the user by Mixin uid, destroy = sign out) and `app/controllers/concerns/authentication.rb` (`require_authentication` / `allow_unauthenticated_access` / `start_new_session_for`), with `include Authentication` injected into `ApplicationController`.
  - View `app/views/sessions/new.html.erb` with a CSRF-safe POST "Sign in with Mixin" button; routes `resource :session` plus the `/auth/mixin/callback` mapping; migrations `CreateUsers` and `CreateSessions`.
  - Host Gemfile gains `omniauth-mixin` and `omniauth-rails_csrf_protection` (OmniAuth 2.x requires the POST request phase to be CSRF-protected).
- The gem itself gains NO runtime dependency on Rails or OmniAuth: generator code loads only when railties invokes it; `railties` is added as a development/test dependency for the generator test harness, and host apps get `omniauth-mixin` through their own Gemfile at generate time (same pattern as `bcrypt` in Rails' generator).
- Docs: README "Rails integration" section plus a matching `docs/agent/` cookbook section.
- Tests: offline `Rails::Generators::TestCase`-style tests asserting the generated file set, key contents, Gemfile wiring, and route injection.

## Capabilities

### New Capabilities
- `rails-generators`: The `mixin_bot:` Rails generator namespace — invoking `rails g mixin_bot:authentication` yields a working Mixin OAuth sign-in flow backed by `omniauth-mixin` with DB-backed sessions: generated file set and contents, routes and initializer wiring, Gemfile changes, behavior of the generated flow (find-or-create by Mixin uid, session lifecycle), and constraints (identity-only, no token persistence; gem stays Rails-free at runtime).

### Modified Capabilities

## Impact

- **Code**: new `lib/generators/mixin_bot/authentication/` (generator class + templates); no changes to existing `lib/mixin_bot/` runtime code. The gemspec `s.files` glob (`lib/**/*`) already ships the new paths.
- **Dependencies**: gem runtime — none added. Dev/test — `railties` (generator test harness). Host apps add `omniauth-mixin` + `omniauth-rails_csrf_protection` at generate time.
- **Compatibility**: host apps need Rails >= 7.2 (verified on 8.x) on the gem's Ruby floor. Like `rails g authentication`, the generator templates over existing target files (e.g. an existing `User` model) — docs must call out reconciliation for apps that already have users.
- **Ops**: generated apps must set `MIXIN_CLIENT_ID` / `MIXIN_CLIENT_SECRET` and register `https://<host>/auth/mixin/callback` as the OAuth redirect URL in the Mixin developer dashboard.
