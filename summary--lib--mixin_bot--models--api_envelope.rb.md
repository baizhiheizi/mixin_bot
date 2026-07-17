# Summary: lib/mixin_bot/models/api_envelope.rb
`size: 1596`
`MixinBot::Models::ApiEnvelope < SimpleDelegator`. Overrides `[]`, `dig`, `key?` (alias `include?`/`has_key?`) to fall through to `inner['data']`. Adds `with_indifferent_access` (merges top-level + data) and `to_h`.