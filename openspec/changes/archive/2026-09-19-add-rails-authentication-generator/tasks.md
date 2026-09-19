## 1. Generator scaffolding

- [x] 1.1 Add `railties` to the Gemfile (dev/test group); verify `bundle install` succeeds and `rake test` still passes
- [x] 1.2 Create `lib/generators/mixin_bot.rb` namespace stub (`MixinBot::Generators`), the `lib/generators/mixin_bot/authentication/` directory, and `USAGE`; verify `Rails::Generators` resolves `mixin_bot:authentication` in the test harness

## 2. Generator and templates

- [x] 2.1 Implement `MixinBot::Generators::AuthenticationGenerator`: template the file set, inject `include Authentication` into `ApplicationController`, add routes (`resource :session`, callback mapping), and create migrations via `generate 'migration', 'CreateUsers', 'mixin_user_id:string!:uniq name:string avatar_url:string', '--force'` and `'CreateSessions', 'user:references ip_address:string user_agent:string', '--force'`; verify a test invocation produces the complete file set in a scratch destination
- [x] 2.2 Add the `config/initializers/omniauth.rb` template: `OmniAuth::Builder` with `provider :mixin` from `MIXIN_CLIENT_ID`/`MIXIN_CLIENT_SECRET` and a setup-phase proc that raises an error naming the missing env vars when either is blank; verify content assertions on the generated initializer
- [x] 2.3 Add the `User` / `Session` / `Current` model templates (User: `has_many :sessions`, `find_or_create_by_mixin_auth!` matching uid and refreshing name/avatar; Session/Current mirroring Rails 8); verify content assertions and that no token fields appear
- [x] 2.4 Add the `Authentication` concern template (require_authentication / allow_unauthenticated_access / resume_session / start_new_session_for / terminate_session / after_authentication_url) and the ApplicationController injection; verify generated concern content and injected line in tests
- [x] 2.5 Add the `SessionsController` template (new renders sign-in page, create consumes `omniauth.auth` and starts a session, destroy terminates), the `sessions/new` view with `button_to "Sign in with Mixin", "/auth/mixin"`, and route entries; verify content assertions on controller, view, and routes text
- [x] 2.6 Implement Gemfile wiring for `omniauth-mixin` and `omniauth-rails_csrf_protection` (uncomment if present, else `bundle_command("add ...", quiet: true)`); verify with a stubbed `bundle_command` that absent gems are added and commented entries are uncommented without duplication

## 3. Offline tests

- [x] 3.1 Add a minimal fake Rails app fixture (Gemfile, config/routes.rb, ApplicationController) under `test/` and a `Rails::Generators::TestCase` base with destination under `tmp/`; verify the full generated file set matches the spec (initializer, 3 models, controller, concern, view, routes) and the two migrations are requested via recorded `rails_command` calls (railties 8.1 `generate` shells out to `bin/rails`, so the migration generator itself is not invoked in-process — same boundary Rails' own generator tests stub)
- [x] 3.2 Add content assertions: routes text, initializer env vars + fail-loud setup proc, concern methods, controller callback consumes `omniauth.auth`, no `mixin_bot` references in any generated file; verify all green
- [x] 3.3 Add a re-run idempotency test (generator invoked twice): verify routes and stubbed Gemfile each contain exactly one set of injected entries
- [x] 3.4 Add a non-Rails load smoke test: `require "mixin_bot"` in a process without railties raises nothing and loads no `lib/generators` files; verify via `$LOADED_FEATURES` assertion

## 4. Docs

- [x] 4.1 Add a "Rails integration" README section: Gemfile + generator invocation, required env vars, registering `https://<host>/auth/mixin/callback` in the Mixin dashboard, identity-only note (tokens not persisted), conflict/overwrite caveat for existing apps, and fail-loud credential behavior; verify rendered output matches implemented templates exactly
- [x] 4.2 Add the matching section to `docs/agent/` cookbook (same content, agent-oriented); verify presence and consistency with README

## 5. Final verification

- [x] 5.1 Run `rake` (tests + RuboCop) clean; run `rake build` and verify the built gem contains `lib/generators/mixin_bot/authentication/authentication_generator.rb` and all templates (RuboCop clean; the 7 failures / 227 errors in the full suite are pre-existing on pristine main in this environment — verified via `git stash` baseline — and all 14 new generator tests pass; built gem verified to ship the generator tree)
- [ ] 5.2 Live smoke (manual, needs real Mixin app credentials): boot a fresh Rails 8 app, run `rails g mixin_bot:authentication`, migrate, sign in with a real Mixin account via the QR/app flow, verify user row + session record + signed cookie + sign-out, and record observed behavior
