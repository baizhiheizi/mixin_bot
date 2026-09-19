## Purpose

Lets a Rails application adopt "Sign in with Mixin" in one command: `rails g mixin_bot:authentication` generates a complete, working Mixin OAuth login (backed by the `omniauth-mixin` strategy) modeled on Rails' built-in `authentication` generator, so apps integrate Mixin identity without hand-wiring OmniAuth, sessions, and callbacks.

## Requirements

### Requirement: Generator invocation produces the Mixin authentication skeleton
When a developer runs `rails generate mixin_bot:authentication` inside a Rails application, the generator SHALL create, without further manual steps: an OmniAuth initializer registering the `:mixin` provider from `MIXIN_CLIENT_ID` / `MIXIN_CLIENT_SECRET` environment variables; `User`, `Session`, and `Current` models; a `SessionsController` (new/create/destroy) and an `Authentication` controller concern; a sign-in view; database migrations for users (unique Mixin user id + profile fields) and sessions; and route entries for the session resource and the OmniAuth callback. It SHALL inject the authentication concern into `ApplicationController`.

#### Scenario: Fresh Rails app
- **WHEN** the generator runs in a Rails app that has none of the target files
- **THEN** the initializer, the three models, the sessions controller, the authentication concern, the sign-in view, and both migrations exist, and the routes file contains the session resource and the `/auth/mixin/callback` mapping

#### Scenario: Application controller gains authentication enforcement
- **WHEN** the generator runs in a Rails app with a default `ApplicationController`
- **THEN** `ApplicationController` includes the generated authentication concern, so unauthenticated requests redirect to the sign-in page

### Requirement: Generated flow authenticates users via Mixin OAuth
The generated callback action SHALL look up `request.env["omniauth.auth"]` and find or create the `User` whose Mixin user id equals the auth hash uid, storing the profile name and avatar from the auth hash, then start a session for that user and redirect to the originally requested URL (or root). A returning user SHALL be matched by Mixin user id, never duplicated.

#### Scenario: First sign-in creates the user
- **WHEN** a user completes Mixin OAuth and no user with that Mixin user id exists
- **THEN** a `User` is created with that id and the profile fields from the auth hash, and the browser is signed in

#### Scenario: Returning sign-in reuses the user
- **WHEN** a user completes Mixin OAuth for an existing Mixin user id
- **THEN** the existing `User` record is reused (profile fields refreshed) and no duplicate is created

### Requirement: Authentication state persists via DB-backed sessions and a signed cookie
The generated code SHALL store sessions in the database (per user, with user agent and IP address) and remember the session id in a signed, httponly cookie, as Rails' built-in authentication generator does. Requests SHALL resume authentication from that cookie; when absent, requests SHALL redirect to the sign-in page.

#### Scenario: Unauthenticated request redirects
- **WHEN** a request arrives without a valid session cookie
- **THEN** the browser is redirected to the sign-in page, and after signing in is returned to the originally requested URL

#### Scenario: Authenticated request resumes the session
- **WHEN** a request arrives with the signed session cookie of a live session
- **THEN** the request is authenticated as that session's user without a new OAuth round-trip

### Requirement: Sign-out terminates the session
The generated destroy action SHALL delete the database session row, clear the session cookie, and redirect to the sign-in page.

#### Scenario: Sign out
- **WHEN** a signed-in user triggers sign out
- **THEN** the session record is destroyed, the cookie is cleared, and the next request is unauthenticated

### Requirement: The OAuth request phase is CSRF-protected
The generated sign-in entry point SHALL initiate the OmniAuth request phase via POST with a valid CSRF token (using `omniauth-rails_csrf_protection`), consistent with OmniAuth 2.x defaults.

#### Scenario: Sign-in button posts to OmniAuth
- **WHEN** the sign-in form is submitted
- **THEN** the browser POSTs to `/auth/mixin` and is redirected to the Mixin authorize URL

#### Scenario: Direct GET is rejected
- **WHEN** a client requests `/auth/mixin` via GET
- **THEN** the request is not processed as an OAuth request phase (rejected per OmniAuth 2.x defaults)

### Requirement: Missing OAuth credentials fail loudly at sign-in time
When `MIXIN_CLIENT_ID` or `MIXIN_CLIENT_SECRET` is unset, application boot SHALL still succeed (deploys, asset precompilation, and CI must not break), but attempting to sign in SHALL produce a clear error naming the missing environment variables instead of redirecting to a broken authorize URL.

#### Scenario: Boot without credentials
- **WHEN** the app boots with neither environment variable set
- **THEN** boot completes without raising

#### Scenario: Sign-in without credentials
- **WHEN** the sign-in form is submitted while credentials are unset
- **THEN** an error is raised whose message names `MIXIN_CLIENT_ID` / `MIXIN_CLIENT_SECRET`

### Requirement: OAuth tokens are not persisted
The generated code SHALL use the OAuth exchange only to establish identity. Access tokens, refresh tokens, and expiry data from the auth hash SHALL NOT be written to the database or cookies.

#### Scenario: Identity-only storage
- **WHEN** a user signs in via Mixin OAuth
- **THEN** the persisted user and session data contain the Mixin user id and profile fields only, with no OAuth token material

### Requirement: Generated code is self-contained
The generated authentication code SHALL depend only on Rails and the two gems it adds to the host Gemfile (`omniauth-mixin`, `omniauth-rails_csrf_protection`), referencing no `mixin_bot` runtime APIs — the login flow keeps working in host apps that keep or drop `mixin_bot` itself.

#### Scenario: No mixin_bot coupling in generated code
- **WHEN** the generated files are inspected
- **THEN** no generated file requires or references `mixin_bot` classes or configuration

### Requirement: Host Gemfile is wired with the OmniAuth gems
The generator SHALL ensure `omniauth-mixin` and `omniauth-rails_csrf_protection` are present in the host Gemfile — adding them when absent — following the same pattern Rails' authentication generator uses for `bcrypt`.

#### Scenario: Fresh Gemfile gains both gems
- **WHEN** the generator runs in an app whose Gemfile lacks both gems
- **THEN** both gems are added and the bundle is refreshed

#### Scenario: Already-present gems are not duplicated
- **WHEN** the Gemfile already declares one of the gems
- **THEN** no duplicate entry is introduced

### Requirement: Re-running the generator does not corrupt configuration
Running the generator a second time SHALL not duplicate route entries or Gemfile entries.

#### Scenario: Second invocation
- **WHEN** the generator runs twice in the same app
- **THEN** the routes file and Gemfile each still contain exactly one set of the injected entries

### Requirement: The gem remains loadable without Rails
Requiring `mixin_bot` in a process where Rails/railties is not installed SHALL NOT load or require any generator code, and SHALL NOT raise.

#### Scenario: Plain Ruby process
- **WHEN** `require "mixin_bot"` runs in a non-Rails Ruby process without railties on the load path
- **THEN** no error is raised and no generator files are loaded
