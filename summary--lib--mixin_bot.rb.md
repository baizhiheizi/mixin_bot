# lib/mixin_bot.rb

Top-level MixinBot module. Lazily exposes:

- `MixinBot.api` → `@api ||= MixinBot::API.new` (singleton)
- `MixinBot.config` → `@config ||= MixinBot::Configuration.new`
- `MixinBot.configure(&block)` → `config.instance_exec(&block)`
- `MixinBot.utils` → `MixinBot::Utils`
- `MixinBot.deprecator` → `ActiveSupport::Deprecation.new('2.0', 'MixinBot')`

Requires errors, address, models, api, bot_auth, cli, computer, invoice, monitor, url_scheme, utils, nfo, uuid, transaction, version, and mvm.