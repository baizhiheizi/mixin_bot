# release-publish Specification

## Purpose
TBD - created by archiving change comprehensive-github-workflows. Update Purpose after archive.

## Requirements

### Requirement: Release triggered by version tags

The release workflow SHALL run when a git tag matching `v*` is pushed to the repository.

#### Scenario: Version tag push

- **WHEN** a maintainer pushes tag `v2.0.1` (or any `v*` semver tag)
- **THEN** the release workflow starts automatically

### Requirement: Gem build before publish

The release job SHALL build the gem using the project Rake task (`bundle exec rake build`) before publishing.

#### Scenario: Successful build

- **WHEN** the gemspec and sources are valid
- **THEN** a `.gem` artifact is produced in the workspace

### Requirement: Publish to RubyGems.org

The release job SHALL push the built gem to RubyGems.org using a repository secret (e.g. `RUBYGEMS_API_KEY`).

#### Scenario: Successful publish

- **WHEN** the API key is valid and the gem version is not already published
- **THEN** the gem becomes available on RubyGems.org

#### Scenario: Duplicate version

- **WHEN** the gem version already exists on RubyGems.org
- **THEN** the publish step fails with a non-zero exit code

### Requirement: Stale GitHub Packages workflow removed

The repository MUST NOT retain the `gem-push.yml` workflow that publishes only to GitHub Packages via `PKG_TOKEN`.

#### Scenario: Workflow inventory

- **WHEN** a maintainer lists files under `.github/workflows/`
- **THEN** `gem-push.yml` is absent and release publishing is handled by the new release workflow

### Requirement: Optional manual release dispatch

The release workflow MAY expose `workflow_dispatch` for maintainers to trigger a publish or build manually.

#### Scenario: Manual trigger

- **WHEN** a maintainer runs the workflow via Actions UI with `workflow_dispatch`
- **THEN** the release job executes with the same build/publish steps as tag-triggered runs (subject to documented inputs)
