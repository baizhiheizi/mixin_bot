## 1. CI pipeline

- [x] 1.1 Rewrite `.github/workflows/ci.yml`: triggers `pull_request` + `push` to `main`, `permissions: contents: read`, PR `concurrency`
- [x] 1.2 Add `test` job: Ruby matrix 3.2 / 3.3 / 4.0, apt native deps, `ruby/setup-ruby` with `bundler-cache`, `bundle exec rake`
- [x] 1.3 Add `api-coverage` job: single Ruby 3.3, `bundle exec rake mixin_bot:api_coverage`
- [x] 1.4 Remove obsolete steps (e.g. lockfile mutation, redundant `rake build` in CI) unless CI fails without them

## 2. Release and publish

- [x] 2.1 Add `.github/workflows/release.yml`: tag `v*`, `bundle exec rake build`, `gem push` via `RUBYGEMS_API_KEY`
- [x] 2.2 Add optional tag/version consistency check (`git tag` vs `MixinBot::VERSION`)
- [x] 2.3 Delete `.github/workflows/gem-push.yml`
- [x] 2.4 Document `RUBYGEMS_API_KEY` setup and tag-based release flow in `README.md` and/or `AGENTS.md`

## 3. Dependency automation

- [x] 3.1 Add `.github/dependabot.yml` for `bundler` and `github-actions` (weekly schedule)
- [x] 3.2 Verify Dependabot PRs trigger the updated CI workflow

## 4. Validation and cleanup

- [x] 4.1 Open a PR and confirm all CI jobs pass on the PR itself
- [x] 4.2 Confirm maintainer has added `RUBYGEMS_API_KEY` before next release tag
- [x] 4.3 Update CI badge in `README.md` if present (branch/events wording)
