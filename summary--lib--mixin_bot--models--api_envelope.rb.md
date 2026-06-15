# lib/mixin_bot/models/api_envelope.rb

`MixinBot::Models::ApiEnvelope < SimpleDelegator`. `[]` and `dig` first check top-level hash, then fall through to inner `data` hash. `key?`/`include?`/`has_key?` apply same fallback. `with_indifferent_access` returns HashWithIndifferentAccess with data merged into top level. `to_h` returns the underlying hash.