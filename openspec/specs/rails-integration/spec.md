## Purpose

Provides the Rails entry point for the integration layer — a railtie that registers generators and integration glue with a soft Rails dependency, multi-bot configuration, and a one-command installer — without changing how the plain gem behaves outside Rails.

## Requirements

### Requirement: Opt-in Rails loading
`require 'mixin_bot'` SHALL NOT load any Rails or railtie code. `require 'mixin_bot/rails'` SHALL load the integration layer (railtie, generators, rake tasks) when Rails is present, and SHALL raise a clear error naming the missing dependency when it is not. The gem SHALL NOT add a runtime dependency on Rails.

#### Scenario: Gem without Rails
- **WHEN** a non-Rails application requires `mixin_bot`
- **THEN** all existing SDK behavior loads and no Rails code is required

#### Scenario: Rails application opts in
- **WHEN** a Rails application requires `mixin_bot/rails`
- **THEN** the mixin_bot generators and the polling rake task are available to the application

### Requirement: Multi-bot configuration
Applications SHALL be able to register multiple bot configurations keyed by name, each with its own keystore credentials, in addition to the existing single default bot. All integration components (router, poller, transfer pipeline, notification channel) SHALL accept which bot to use and SHALL default to the default bot.

#### Scenario: Poller for a named bot
- **WHEN** the polling task is run with a bot name argument for a registered bot
- **THEN** it polls that bot's outputs and persists receipts and the cursor under that bot's app id

### Requirement: Install generator composes the others
`rails generate mixin_bot:install` SHALL run the authentication, blaze, outputs, transfers, and notifications generators in dependency order, accepting options to skip any of them, and SHALL be idempotent: running it twice produces no duplicated files, routes, or Gemfile entries.

#### Scenario: Full install in one command
- **WHEN** a developer runs `rails generate mixin_bot:install` in a fresh Rails application
- **THEN** authentication, Blaze routing with an example handler, the outputs poller with an example processor, the transfer ledger, and the notification channel are all generated and the application boots

#### Scenario: Selective install
- **WHEN** a developer runs `rails generate mixin_bot:install --skip-notifications --skip-transfers`
- **THEN** only authentication, blaze, and outputs are generated
