# frozen_string_literal: true

# Outbound transfer ledger. Creating a record enqueues the perform job; the
# runtime concern (MixinBot::Transfers::Model) drives the Safe pipeline and
# records the outcome in #state. bot_app_id selects a registered bot
# (MixinBot.register_bot); nil uses the default bot.
class MixinTransfer < ApplicationRecord
  include MixinBot::Transfers::Model

  after_create_commit -> { MixinTransfers::PerformJob.perform_later(id) }
end
