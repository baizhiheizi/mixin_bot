# frozen_string_literal: true

module MixinBot
  ##
  # Outbound transfer pipeline: a persisted transfer record enqueues a job
  # that executes the Safe transaction pipeline exactly once per trace id,
  # records the outcome on the record's state, and reconciles unknown
  # outcomes (timeout after submission) against the snapshot API before any
  # retry — the network's trace deduplication makes retries safe.
  #
  module Transfers
    class << self
      # Shared logger for the transfers integration; called with (level, detail).
      attr_accessor :logger
    end

    self.logger = ->(level, detail) { warn "[mixin_transfers] #{level}: #{detail}" }
  end
end

require_relative 'transfers/model'
require_relative 'transfers/performer'
require_relative 'transfers/reconcile'
