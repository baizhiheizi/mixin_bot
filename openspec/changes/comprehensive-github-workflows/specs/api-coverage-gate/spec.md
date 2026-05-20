## ADDED Requirements

### Requirement: API coverage check in CI

The CI pipeline SHALL include a job that runs `bundle exec rake mixin_bot:api_coverage` on pull requests and pushes to `main`.

#### Scenario: All coverage entries complete

- **WHEN** `API_COVERAGE.md` contains no rows marked `missing`
- **THEN** the api-coverage job exits with success

#### Scenario: Missing coverage entries

- **WHEN** `API_COVERAGE.md` contains one or more `missing` entries
- **THEN** the api-coverage job exits with a non-zero status and fails the workflow

### Requirement: API coverage does not require network

The api-coverage job SHALL NOT set `LIVE=1` or depend on `test/config.yml` or external API credentials.

#### Scenario: Offline execution

- **WHEN** the api-coverage job runs in GitHub Actions
- **THEN** it completes using only repository files without network calls to Mixin APIs
