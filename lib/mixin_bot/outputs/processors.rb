# frozen_string_literal: true

module MixinBot
  module Outputs
    ##
    # Base class for output processors. Subclass, implement class-level
    # {matches?} and instance-level {#process}:
    #
    #   module Mixin
    #     module Processors
    #       class OrderDeposit < MixinBot::Outputs::Processor
    #         def self.matches?(envelope)
    #           !envelope.spent? && envelope.memo.to_s.start_with?('ORDER-')
    #         end
    #
    #         def process
    #           Order.settle_by_deposit!(envelope)
    #         end
    #       end
    #     end
    #   end
    #
    # Processors live in app/mixin/processors (Rails autoloads them as
    # Mixin::Processors::*). Every processor whose predicate matches an output
    # gets a job enqueued — matches are independent side effects, and an
    # output matching no processor is recorded only.
    #
    # Enqueue is at-least-once: processors should tolerate rare duplicate
    # runs and can use the envelope's output_id as a natural idempotency key.
    #
    class Processor
      def initialize(envelope)
        @envelope = envelope
      end

      def call
        process
      end

      attr_reader :envelope

      # Override with the processor's selection predicate.
      def self.matches?(_envelope)
        false
      end

      def process
        raise NotImplementedError, "#{self.class} must implement #process"
      end
    end

    ##
    # Processor discovery and selection over the Mixin::Processors namespace.
    #
    module Processors
      NAMESPACE_NAME = 'Mixin::Processors'

      module_function

      ##
      # All processor classes currently defined under Mixin::Processors. Under
      # Rails the namespace is eager-loaded first so the poller process sees
      # every processor without referencing each one.
      #
      # @return [Array<Class>]
      #
      def discover
        eager_load_namespace! if defined?(::Rails.application) && ::Rails.application.respond_to?(:autoloaders)

        namespace = namespace_class
        return [] if namespace.nil?

        namespace.constants.filter_map do |const|
          candidate = namespace.const_get(const)
          candidate if candidate.is_a?(Class) && candidate < Processor
        end
      end

      # Finds a processor by fully-qualified class name (the payload the
      # poller's jobs carry).
      #
      # @param name [String]
      # @return [Class]
      # @raise [NameError] when no such processor is loaded
      #
      def resolve(name)
        constant = Object.const_get(name)
        raise NameError, "#{name} is not a MixinBot::Outputs::Processor" unless constant.is_a?(Class) && constant < Processor

        constant
      end

      ##
      # Processors whose predicate matches the envelope.
      #
      # @return [Array<Class>]
      #
      def for_envelope(envelope, processors:)
        processors.select { |processor| processor.matches?(envelope) }
      end

      def namespace_class
        Object.const_get(NAMESPACE_NAME)
      rescue NameError
        nil
      end

      def eager_load_namespace!
        autoloader = ::Rails.autoloaders.main
        namespace = namespace_class
        return if namespace.nil?

        if autoloader.respond_to?(:eager_load_namespace)
          autoloader.eager_load_namespace(namespace)
        else
          ::Rails.application.eager_load!
        end
      rescue Zeitwerk::SetupRequired, StandardError
        # Best effort: an eager-load problem must not stop polling.
        nil
      end
    end
  end
end
