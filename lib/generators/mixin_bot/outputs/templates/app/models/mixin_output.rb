# frozen_string_literal: true

# Receipt row for every output the poller observes (inbound or outbound).
# The (bot_app_id, output_id) unique index is the dedup gate; snapshot-derived
# fields (memo, opponent_id, trace_id) are cached here by the envelope bridge.
class MixinOutput < ApplicationRecord
  include MixinBot::Outputs::ReceiptModel
end
