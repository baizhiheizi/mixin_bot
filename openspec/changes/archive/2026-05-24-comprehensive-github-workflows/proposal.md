## Why

The repository’s GitHub Actions setup is minimal and partly stale: CI runs only on pushes to `main` (not on pull requests), `gem-push.yml` targets GitHub Packages with RubyGems publishing commented out, and there is no Dependabot or API-coverage gate in CI. As the gem matures (Ruby 3.2–4.0 matrix, RuboCop, `rake mixin_bot:api_coverage`, agent-oriented docs), contributors and releases need predictable, modern automation without maintaining dead workflow paths.

## What Changes

- **Replace** narrow `ci.yml` with a PR-aware CI workflow: test + RuboCop via default `rake`, Ruby matrix (3.2, 3.3, 4.0), concurrency, least-privilege `permissions`.
- **Remove** `gem-push.yml` (GitHub Packages–only, unused RubyGems path) and **add** a single release/publish workflow triggered by `v*` tags (and optional `workflow_dispatch`), aligned with `rake publish` / RubyGems as the primary distribution channel.
- **Add** Dependabot for Bundler and GitHub Actions ecosystem updates.
- **Add** a dedicated API coverage check job (or step) running `rake mixin_bot:api_coverage` on `main` and PRs.
- **Add** workflow hygiene: pinned action versions, `permissions` defaults, `concurrency` for PR CI, documented required secrets for publish.
- **Optional (non-blocking in v1)**: `workflow_dispatch` manual publish dry-run; no agent/LLM workflows in this change (keeps scope to standard gem CI/CD).

## Capabilities

### New Capabilities

- `ci-pipeline`: Pull-request and main-branch CI — offline tests, RuboCop, Ruby version matrix, native dependency setup.
- `release-publish`: Tag-driven gem build and push to RubyGems (secrets documented); replaces GitHub Packages–only flow.
- `dependency-updates`: Dependabot configuration for Ruby gems and GitHub Actions.
- `api-coverage-gate`: CI enforcement of `API_COVERAGE.md` completeness via `rake mixin_bot:api_coverage`.

### Modified Capabilities

<!-- No existing openspec/specs/ capabilities -->

## Impact

- **Files**: `.github/workflows/ci.yml` (rewrite), `.github/workflows/gem-push.yml` (delete), new `.github/workflows/release.yml` (or equivalent), new `.github/dependabot.yml`.
- **Secrets**: Document `RUBYGEMS_API_KEY` (or trusted-publishing OIDC if adopted in design); remove reliance on `PKG_TOKEN` / GitHub Packages unless explicitly retained.
- **Contributor docs**: Update `README.md` / `AGENTS.md` CI badges and publish instructions if they reference old workflows.
- **No runtime gem API changes** — automation only.
