# ci-pipeline Specification

## Purpose
TBD - created by archiving change comprehensive-github-workflows. Update Purpose after archive.

## Requirements

### Requirement: CI runs on pull requests and main

The CI pipeline SHALL run on every `pull_request` event and on every `push` to the `main` branch.

#### Scenario: Pull request opened

- **WHEN** a contributor opens or updates a pull request against any base branch
- **THEN** the CI workflow runs automatically

#### Scenario: Push to main

- **WHEN** a commit is pushed to the `main` branch
- **THEN** the CI workflow runs automatically

### Requirement: Ruby version matrix

The test job SHALL execute against Ruby versions 3.2, 3.3, and 4.0 on `ubuntu-latest`.

#### Scenario: Matrix execution

- **WHEN** CI runs the test job
- **THEN** three parallel jobs complete, one per listed Ruby version

### Requirement: Default rake quality gate

Each matrix cell SHALL run `bundle exec rake` (the project default task: offline tests and RuboCop).

#### Scenario: Tests and lint pass

- **WHEN** code satisfies offline tests and RuboCop
- **THEN** the test job exits with success for that Ruby version

#### Scenario: Test or RuboCop failure

- **WHEN** a test fails or RuboCop reports offenses
- **THEN** the test job exits with a non-zero status for that Ruby version

### Requirement: Native build dependencies

The test job SHALL install system packages required to compile native gem extensions (e.g. build-essential, libffi, libssl, libgmp) before `bundle install`.

#### Scenario: Native extension compile

- **WHEN** Bundler installs gems with native extensions
- **THEN** compilation succeeds without missing-header errors

### Requirement: PR concurrency

Pull request CI runs SHALL use a concurrency group that cancels superseded in-progress runs for the same ref.

#### Scenario: Rapid pushes on a PR

- **WHEN** multiple commits are pushed to the same pull request branch in quick succession
- **THEN** older in-progress CI runs for that ref are cancelled

### Requirement: Least-privilege permissions

The CI workflow SHALL declare `permissions: contents: read` (or stricter) and MUST NOT require write access to repository contents for test execution.

#### Scenario: Fork pull request

- **WHEN** CI runs for a pull request from a fork
- **THEN** the workflow completes using read-only `GITHUB_TOKEN` permissions
