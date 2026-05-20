## Context

MixinBot is a Ruby gem (>= 3.2) with offline Minitest + WebMock, RuboCop via default `rake`, optional live tests (`LIVE=1`), and `rake mixin_bot:api_coverage` guarding `API_COVERAGE.md`. Current automation:

| Workflow | Trigger | Behavior |
|----------|---------|----------|
| `ci.yml` | `push` → `main` only | Ruby 3.2/3.3/4.0 matrix, apt native deps, `rake build` + `rake` (test+rubocop) |
| `gem-push.yml` | `v*` tags, `workflow_dispatch` | Publishes to GitHub Packages via `PKG_TOKEN`; RubyGems step commented out |

Gaps: no PR CI, no API coverage in CI, publish path diverges from `rake publish` (RubyGems), no Dependabot, redundant lockfile mutation step in CI.

## Goals / Non-Goals

**Goals:**

- Run the same quality gates on every PR and on `main` that maintainers expect locally (`rake`, `rake mixin_bot:api_coverage`).
- Publish gems to **RubyGems.org** on version tags, matching gem conventions and `Rakefile` `publish` task.
- Keep Ruby 3.2 / 3.3 / 4.0 matrix on Ubuntu with native deps required by `blake3-rb`, `eth`, etc.
- Add Dependabot for Bundler + GitHub Actions; pin major action versions.
- Use least-privilege `permissions` and PR `concurrency` to cancel superseded runs.

**Non-Goals:**

- LLM/agent workflows (CI doctor, scheduled repo-assist) — out of scope for this change.
- Live/network integration tests in CI (remain manual / `LIVE=1` locally).
- MVM test suite in default CI (excluded from `rake test` today).
- GitHub Packages publishing unless explicitly re-added later.
- RubyGems trusted publishing (OIDC) in v1 — use API key secret unless maintainer opts in during apply.

## Decisions

### 1. Single `ci.yml` with two jobs: `test` and `api-coverage`

- **`test` job**: Matrix `ruby: ['3.2', '3.3', '4.0']`, `bundle exec rake` (default = test + rubocop). Drop separate `rake build` in CI — `rake test` does not require a built `.gem`; release workflow builds the gem.
- **`api-coverage` job**: Single Ruby version (3.3), runs `bundle exec rake mixin_bot:api_coverage` — fast, no network, validates docs parity.
- **Triggers**: `pull_request` (all branches) + `push` to `main`.
- **Alternative considered**: One job only — rejected because coverage failure would be buried in matrix noise; separate job gives a clear check name.

### 2. Replace `gem-push.yml` with `release.yml`

- **Trigger**: `push` tags matching `v*` (e.g. `v2.0.1`); optional `workflow_dispatch` with `ref` input for emergency republish.
- **Steps**: checkout → setup-ruby → `bundle exec rake build` → `gem push` using `RUBYGEMS_API_KEY` secret (classic API key in repo secrets).
- **Delete** `gem-push.yml` and document removal of `PKG_TOKEN` / GitHub Packages flow.
- **Alternative considered**: Dual publish (RubyGems + GPR) — rejected as stale/unused per proposal.

### 3. Dependabot at `.github/dependabot.yml`

- **Ecosystems**: `bundler` (weekly), `github-actions` (weekly).
- **Grouping**: Group patch/minor Action updates in one PR where Dependabot supports it (v2 syntax).
- **Alternative considered**: Renovate — not chosen to avoid new bot onboarding for a small repo.

### 4. CI native dependencies and Bundler

- Keep `apt-get` install of build-essential, libffi, libssl, libgmp, etc. (required for native extensions).
- **Remove** the “Update lockfile for path gems” step unless `bundle install` fails without it on a clean checkout — prefer `bundler-cache: true` only; reintroduce only if CI proves broken.
- Set `BUNDLE_WITHOUT` unset; do not run live tests.

### 5. Workflow hygiene

- `permissions: contents: read` on CI; release job gets no extra repo write (publish uses RubyGems API only).
- `concurrency` on PRs: `group: ci-${{ github.workflow }}-${{ github.ref }}`, `cancel-in-progress: true`.
- Pin `actions/checkout@v4`, `ruby/setup-ruby@v1` (document SHA pinning as follow-up if desired).

## Risks / Trade-offs

| Risk | Mitigation |
|------|------------|
| Missing `RUBYGEMS_API_KEY` breaks first release | Document secret setup in README/AGENTS.md; `workflow_dispatch` allows dry-run build-only job variant |
| API coverage rake fails on fork PRs | Job only needs `API_COVERAGE.md` in repo — no secrets; forks get same check |
| Native apt packages slow CI | Acceptable for gem with native ext; cache bundler via setup-ruby |
| Tag push without version bump in code | Release workflow should verify tag matches `MixinBot::VERSION` (optional step in tasks) |
| Removing GPR publish breaks consumers on GPR | Confirm with maintainer; proposal assumes RubyGems is canonical (`homepage`, `rake publish`) |

## Migration Plan

1. Add new workflows and Dependabot config on a branch; open PR to validate CI on the PR itself.
2. Merge after green CI.
3. Add `RUBYGEMS_API_KEY` repository secret before next tag.
4. Delete `gem-push.yml` in same PR.
5. Next release: tag `vX.Y.Z` → `release.yml` publishes; verify on rubygems.org.

**Rollback**: Revert workflow commit; restore `gem-push.yml` from git history if GPR still needed.

## Open Questions

- Should release workflow enforce `git tag` == `MixinBot::VERSION` (recommended — include in tasks)?
- Does the maintainer still need GitHub Packages for any internal consumer? If yes, add a second publish job instead of deleting GPR entirely.
