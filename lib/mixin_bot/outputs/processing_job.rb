# frozen_string_literal: true

begin
  require 'active_job/base'
rescue LoadError
  nil
end

module MixinBot
  module Outputs
    ##
    # The poller's processing job — carries only (receipt id, processor class
    # name) in its payload and rehydrates everything else at run time: the
    # receipt from the application's receipt loader, the bot API client from
    # the receipt's app id, and the envelope from the receipt.
    #
    # Defined only when ActiveJob is available (it is in every Rails stack
    # that runs a job queue).
    #
    if defined?(ActiveJob::Base)
      class ProcessingJob < ActiveJob::Base
        queue_as :mixin_outputs

        # @param receipt_id [Object] the receipt record's primary key
        # @param processor_name [String] fully-qualified processor class name
        def perform(receipt_id, processor_name)
          loader = MixinBot::Outputs.receipt_loader
          unless loader
            raise ArgumentError,
                  'no receipt loader configured: include MixinBot::Outputs::ReceiptModel ' \
                  'in your receipt model (the mixin_bot:outputs generator does this)'
          end

          receipt = loader.call(receipt_id)
          envelope = Envelope.new(receipt, api: api_for(receipt))
          Processors.resolve(processor_name).new(envelope).call
        end

        private

        def api_for(receipt)
          app_id = receipt.respond_to?(:bot_app_id) ? receipt.bot_app_id : nil
          bot = MixinBot.bot_by_app_id(app_id) if app_id
          bot || MixinBot.api
        end
      end
    end
  end
end
