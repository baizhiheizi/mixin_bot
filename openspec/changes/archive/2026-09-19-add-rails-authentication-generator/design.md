## Context

mixin_bot ships an SDK and CLI (`lib/mixin_bot/`) but nothing Rails-specific. The host-side OAuth strategy already exists as `omniauth-mixin` (OAuth2 strategy, provider name `:mixin`, authorize `https://mixin.one/oauth/authorize`, token `https://api.mixin.one/oauth/token`, uid from `/me` → `user_id`, credentials include token/refresh_token/expiry). Rails 8's built-in `rails g authentication` generator (rails/rails `railties/lib/rails/generators/rails/authentication/`) is the UX reference: template files, `route` injection, Gemfile gem wiring, migration generation via `generate "migration"`. The gem requires Ruby >= 4.0 — realistically meaning host apps run Rails 8.x. Dev/test-only dependencies live in the Gemfile; the gemspec holds runtime deps only.

## Goals / Non-Goals

**Goals:**
- `rails g mixin_bot:authentication` works in a fresh Rails 8 app with zero manual patching, producing a complete identity-only Mixin login.
- File-for-file parity with the Rails 8 authentication skeleton where it applies (Session/Current models, Authentication concern, signed-cookie + DB session pattern), so the result feels native to Rails developers.
- The gem stays Rails-free at runtime; generator code loads only when railties asks for it.

**Non-Goals:**
- Persisting or refreshing OAuth tokens (explicitly deferred; a future generator may add API-access wiring on top).
- `--api` / token-auth variant (JSON:API/JWT flows) — future work.
- Adapting to an existing `User` model, or Devise integration.
- Any change to `MixinBot::API`, the CLI, or existing specs' behavior.

## Decisions

### Generator layout and discovery
- `lib/generators/mixin_bot/authentication/authentication_generator.rb` defining `MixinBot::Generators::AuthenticationGenerator`, plus a `lib/generators/mixin_bot.rb` namespace stub and a `USAGE` file, with templates beside the generator in `templates/`.
- Why this shape: it is the convention used by Devise and other gem-bundled generators — railties scans bundle gems' `lib/generators` paths, so no configuration is needed in the host app. Alternative (top-level `lib/rails/generators/...`) is nonstandard for namespaced generators.
- Gemfile shipping: the gemspec's existing `lib/**/*` glob already includes the generator tree; no gemspec change.

### Model the Rails 8 authentication generator, minus passwords
Generated set mirrors Rails' generator: `app/models/{user,session,current}.rb`, `app/controllers/sessions_controller.rb`, `app/controllers/concerns/authentication.rb`, `app/channels/.../connection.rb` only if ActionCable is defined, view for `sessions#new`, `include Authentication` injected into `ApplicationController`, `resource :session` route, `CreateUsers`/`CreateSessions` migrations via `generate "migration", ..., "--force"`.
Deltas from Rails' version:
- No `has_secure_password`, no `PasswordsController`/`PasswordsMailer` (no email identity), no registration flow.
- `User` instead carries `mixin_user_id:string!:uniq name:string avatar_url:string`; sessions controller `create` is the OmniAuth callback (`get "/auth/mixin/callback" => "sessions#create"`); `new` renders the sign-in button.
- The OmniAuth initializer replaces bcrypt wiring as the "enable the dependency" step.
- Generated controller omits `rate_limit` (a Rails 7.2+ feature with little value on an OAuth callback) to keep the generated code conservative.

### OmniAuth wiring and CSRF
- Initializer `config/initializers/omniauth.rb` uses `OmniAuth::Builder` with `provider :mixin, ENV.fetch("MIXIN_CLIENT_ID", nil), ENV.fetch("MIXIN_CLIENT_SECRET", nil)` plus `omniauth-rails_csrf_protection` (standard OmniAuth 2.x Rails setup; `allowed_request_methods` defaults to `:post`).
- Sign-in view uses `button_to "Sign in with Mixin", "/auth/mixin"` — POST with CSRF token; the Rails route layer never sees `/auth/mixin` (middleware intercepts) but does route the callback GET into `SessionsController#create`.
- Alternative considered: GET-based sign-in link — rejected; OmniAuth 2.x blocks it (CVE-2015-9284) and the CSRF-protection gem is the ecosystem standard.

### Fail-loud credentials at request time, not boot time
The provider registration includes an OmniAuth **setup phase** proc that raises an `ArgumentError` naming `MIXIN_CLIENT_ID` / `MIXIN_CLIENT_SECRET` when either is blank. The setup phase runs per OAuth request, so `assets:precompile`, CI boots, and deploys without secrets keep working, while a real sign-in attempt fails with an actionable message instead of redirecting to a broken authorize URL. Alternative (raise in the initializer) rejected: it breaks common CI/precompile flows.

### Identity-only user upsert
`User.find_or_create_by_mixin_auth!(auth)`: `find_or_create_by!(mixin_user_id: auth.uid)` then refresh `name` / `avatar_url` (sourced from `info` with `extra.raw_info` fallback) when changed. Credentials from the auth hash are never read. Rationale: keeps profiles fresh without extra columns; honoring the identity-only decision.

### Session handling copies Rails 8 verbatim-in-spirit
DB-backed `Session` (`user:references ip_address:string user_agent:string`), `Current` attributes, signed httponly permanent cookie, `resume_session` / `start_new_session_for` / `terminate_session` / `after_authentication_url` exactly as Rails' concern does. Why not a plain Rails cookie session: parity with `rails g authentication` and server-side revocation (destroy deletes the row).

### Gemfile wiring mirrors the bcrypt pattern
For each of `omniauth-mixin` and `omniauth-rails_csrf_protection`: if the Gemfile contains the gem (commented or not), uncomment it; otherwise `bundle_command("add <gem>", quiet: true)`. Re-running is naturally non-duplicating (uncomment is idempotent; absence triggers a single add). Dev/test dependency for this repo: `railties` in the Gemfile for the generator test harness.

### Testing strategy (offline)
- `Rails::Generators::TestCase` with `destination` under `tmp/` and a minimal fake app skeleton (Gemfile + config/routes.rb + ApplicationController fixture) checked in under `test/`; `argument`/behavior tests assert the generated file set, route injection, controller/concern/initializer content, and Application-controller injection.
- `bundle_command` is stubbed in tests (no network, no real bundle) — the gem-wiring tests assert Gemfile text changes only.
- A non-Rails smoke test asserts `require "mixin_bot"` loads nothing from `lib/generators` (mirrors the blaze-puma-plugin "loadable without Puma" test).
- Full generated-app runtime behavior (real OAuth round-trip) is a manual/live verification task, as with blaze-puma-plugin's live smoke.

## Risks / Trade-offs

- [Generator templates overwrite or prompt on existing files when run into an app that already has `User` etc.] → Thor's standard conflict prompt is kept (parity with `rails g authentication`); README documents reconciliation for existing apps.
- [`bundle_command("add ...")` needs network and mutates the host Gemfile.lock] → Same trade-off as Rails' own generator; failures surface bundler's own error message. Tests stub it.
- [Host Rails version drift (7.x vs 8.x APIs, e.g. attribute APIs in generated models)] → Generated code uses long-stable APIs only; CI can't run a full Rails matrix offline — live smoke on a current Rails 8 app is the safety net.
- [OmniAuth callback depends on middleware/route interaction that file-presence tests can't fully exercise] → Acceptance relies on the manual boot-and-sign-in task; unit tests assert the exact route text and initializer wiring.
- [Raised setup-phase error renders as a raw 500] → Acceptable fail-loud behavior for a misconfigured deployment; message names the fix. Documented in README.

## Migration Plan

Purely additive gem release: new files under `lib/generators/`, `railties` dev dependency. No runtime code touched; rollback = remove the files. Host apps adopt by running the generator; un-adopt by deleting the generated files and re-running migrations down.

## Open Questions

None — remaining unknowns (real-browser OAuth round-trip behavior, exact Gemfile lock side effects) are covered by the manual live-verification task.
