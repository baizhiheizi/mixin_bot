# frozen_string_literal: true

module Mixin
  module Processors
    class DepositProcessor < MixinBot::Outputs::Processor
      def self.matches?(_envelope)
        true
      end

      def process; end
    end
  end
end
