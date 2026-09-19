# frozen_string_literal: true

module MixinBot
  ##
  # Output (transfer) polling integration: delivers every output touching the
  # bot's Safe UTXO set — inbound or outbound — to application processor
  # classes exactly once, via a standalone polling process and the
  # application's job queue.
  #
  #   poller = MixinBot::Outputs::Poller.new(api: MixinBot.bot(:shop))
  #   poller.run   # blocks; see the mixin_bot:poller rake task
  #
  module Outputs
    class << self
      # Shared logger for the outputs integration; called with (level, detail),
      # same shape as MixinBot::Blaze::Reactor's logger. Injectable per
      # component; this default is the fallback.
      attr_accessor :logger

      # Called with a receipt id to reload the receipt record when a processing
      # job runs — set by the generated receipt model (ActiveRecord host apps).
      # Without a loader, processing jobs raise a clear error explaining how to
      # wire one.
      attr_accessor :receipt_loader
    end

    self.logger = ->(level, detail) { warn "[mixin_outputs] #{level}: #{detail}" }
  end
end

require_relative 'outputs/envelope'
require_relative 'outputs/memory_stores'
require_relative 'outputs/processors'
require_relative 'outputs/poller'
require_relative 'outputs/processing_job'
require_relative 'outputs/receipt_model'
require_relative 'outputs/cursor_model'
