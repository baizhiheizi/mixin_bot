# frozen_string_literal: true

# One row per bot app id: the last absorbed output position (the outputs
# API's own created_at value). Survives poller restarts.
class MixinPollerCursor < ApplicationRecord
  include MixinBot::Outputs::CursorModel
end
