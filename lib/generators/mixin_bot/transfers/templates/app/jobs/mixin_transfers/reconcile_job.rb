# frozen_string_literal: true

module MixinTransfers
  # Resolves transfers whose send attempt ended indeterminately (timeout
  # after submission): confirms from the trace snapshot or re-sends with the
  # same trace id. Wired by the recurring schedule in config/recurring.yml.
  class ReconcileJob < ApplicationJob
    queue_as :mixin_transfers

    def perform
      MixinTransfer.reconcile_pending!
    end
  end
end
