## ADDED Requirements

### Requirement: Dependabot for Bundler

The repository SHALL include Dependabot configuration that monitors Bundler dependencies in the default branch.

#### Scenario: Weekly gem update PR

- **WHEN** Dependabot runs on its configured schedule
- **THEN** it MAY open pull requests proposing updates to `Gemfile` / `Gemfile.lock` dependencies

### Requirement: Dependabot for GitHub Actions

The repository SHALL include Dependabot configuration that monitors GitHub Actions used in workflows.

#### Scenario: Weekly Actions update PR

- **WHEN** Dependabot runs on its configured schedule
- **THEN** it MAY open pull requests proposing updates to action versions in `.github/workflows/`

### Requirement: Dependabot PRs run CI

Dependabot pull requests SHALL be subject to the same CI workflow as contributor PRs.

#### Scenario: Dependabot PR opened

- **WHEN** Dependabot opens a dependency update pull request
- **THEN** the CI pipeline runs on that pull request
