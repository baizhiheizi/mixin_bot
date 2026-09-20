# frozen_string_literal: true

module MixinTransfers
  # Executes the Safe pipeline for one MixinTransfer. Retries are safe: the
  # transfer's trace id deduplicates network-side.
  class PerformJob < ApplicationJob
    queue_as :mixin_transfers

    def perform(transfer_id)
      MixinTransfer.find(transfer_id).perform!
    end
  end
end
