# frozen_string_literal: true

require 'test_helper'
require 'active_job'
require 'mixin_bot/rails'
require 'json'

module MixinBot
  class OutputsProcessorsTest < Minitest::Test
    def setup
      super
      MixinBot::Outputs.receipt_loader = nil
      ActiveJob::Base.logger = nil if defined?(ActiveJob::Base) && ActiveJob::Base.logger
    end

    def teardown
      cleanup_fake_namespace
      MixinBot::Outputs.receipt_loader = nil
      super
    end

    # ---- discovery ----

    def test_discovers_processor_subclasses_under_mixin_processors
      with_fake_processors(ProcessorA, ProcessorB, NotAProcessor)

      discovered = MixinBot::Outputs::Processors.discover

      assert_includes discovered, ProcessorA
      assert_includes discovered, ProcessorB
      refute_includes discovered, NotAProcessor
    end

    def test_discover_without_namespace_is_empty
      cleanup_fake_namespace

      assert_empty MixinBot::Outputs::Processors.discover
    end

    def test_resolve_finds_loaded_processor
      with_fake_processors(ProcessorA)

      assert_same ProcessorA, MixinBot::Outputs::Processors.resolve(ProcessorA.name)
    end

    def test_resolve_rejects_non_processors
      error = assert_raises(NameError) do
        MixinBot::Outputs::Processors.resolve('String')
      end

      assert_match(/not a MixinBot::Outputs::Processor/, error.message)
    end

    # ---- selection ----

    def test_for_envelope_selects_matching_processors
      matcher = Class.new(MixinBot::Outputs::Processor) do
        def self.matches?(envelope)
          envelope.memo == 'MATCH'
        end
      end
      envelope = envelope_double(memo: 'MATCH')

      selected = MixinBot::Outputs::Processors.for_envelope(envelope, processors: [matcher, ProcessorA])

      assert_equal [matcher], selected
    end

    # ---- ProcessingJob ----

    def test_job_payload_carries_only_receipt_id_and_processor_name
      MixinBot::Outputs::ProcessingJob.queue_adapter = :test
      adapter = MixinBot::Outputs::ProcessingJob.queue_adapter

      MixinBot::Outputs::ProcessingJob.perform_later(42, 'Mixin::Processors::Fake')

      assert_equal 1, adapter.enqueued_jobs.size
      assert_equal [42, 'Mixin::Processors::Fake'], adapter.enqueued_jobs.first[:args]
    ensure
      adapter.enqueued_jobs.clear
    end

    def test_job_rehydrates_receipt_envelope_and_processor
      with_fake_processors(EnvelopeCapturingProcessor)
      received_receipt = receipt_double(bot_app_id: MixinBot.config.app_id)
      MixinBot::Outputs.receipt_loader = ->(_id) { received_receipt }

      MixinBot::Outputs::ProcessingJob.perform_now(77, EnvelopeCapturingProcessor.name)

      assert_same received_receipt, EnvelopeCapturingProcessor.captured.receipt
    end

    def test_job_uses_the_bot_bound_to_the_receipt_app_id
      shop = MixinBot.register_bot(:processor_shop, **registry_credentials('processor-shop-app-id', 'shop'))
      with_fake_processors(ApiCapturingProcessor)
      MixinBot::Outputs.receipt_loader = ->(_id) { receipt_double(bot_app_id: 'processor-shop-app-id') }

      MixinBot::Outputs::ProcessingJob.perform_now(78, ApiCapturingProcessor.name)

      assert_same shop, ApiCapturingProcessor.captured_api
    end

    def test_job_without_receipt_loader_raises_clear_error
      error = assert_raises(ArgumentError) do
        MixinBot::Outputs::ProcessingJob.perform_now(1, 'Mixin::Processors::Fake')
      end

      assert_match(/no receipt loader configured/, error.message)
    end

    private

    def receipt_double(bot_app_id:, memo: nil)
      MixinBot::Outputs::MemoryReceiptStore::Receipt.new(
        id: 9, bot_app_id:, output_id: 'out-9', amount: '2.0', asset_id: CNB_ASSET_ID,
        state: 'unspent', transaction_hash: 'cd' * 32, output_index: 0,
        memo:, opponent_id: nil, trace_id: nil
      )
    end

    def envelope_double(memo: nil)
      receipt = receipt_double(bot_app_id: 'x', memo:)
      MixinBot::Outputs::Envelope.new(receipt, api: MixinBot.api)
    end

    def registry_credentials(app_id, seed_suffix)
      session_seed = Digest::SHA256.digest("mixin_bot:test:registry:#{seed_suffix}:session")[0, 32]
      spend_seed = Digest::SHA256.digest("mixin_bot:test:registry:#{seed_suffix}:spend")[0, 32]
      session_kp = JOSE::JWA::Ed25519.keypair(session_seed)
      spend_kp = JOSE::JWA::Ed25519.keypair(spend_seed)

      {
        app_id:,
        session_id: app_id,
        session_private_key: session_kp[1].unpack1('H*'),
        server_public_key: session_kp[0].unpack1('H*'),
        spend_key: spend_kp[1].unpack1('H*')
      }
    end

    def with_fake_processors(*classes)
      namespace =
        if Object.const_defined?(:Mixin)
          Object.const_get(:Mixin)
        else
          Object.const_set(:Mixin, Module.new)
        end
      namespace.const_set(:Processors, Module.new) unless namespace.const_defined?(:Processors)
      @processors_module = namespace.const_get(:Processors)
      classes.each do |klass|
        @processors_module.const_set(klass.name.split('::').last, klass)
      end
    end

    def cleanup_fake_namespace
      return unless defined?(@processors_module) && @processors_module

      @processors_module.constants.each { |c| @processors_module.send(:remove_const, c) }
    end

    # ---- processor fixtures (top-level so const_set names are simple) ----

    class ProcessorA < MixinBot::Outputs::Processor
      def self.matches?(_envelope)
        false
      end

      def process; end
    end

    class ProcessorB < MixinBot::Outputs::Processor
      def self.matches?(_envelope)
        true
      end

      def process; end
    end

    # Not a Processor subclass — must be ignored by discovery.
    NotAProcessor = Class.new

    class EnvelopeCapturingProcessor < MixinBot::Outputs::Processor
      class << self
        attr_accessor :captured
      end

      def self.matches?(_envelope)
        true
      end

      def process
        self.class.captured = envelope
      end
    end

    class ApiCapturingProcessor < MixinBot::Outputs::Processor
      class << self
        attr_accessor :captured_api
      end

      def self.matches?(_envelope)
        true
      end

      def process
        self.class.captured_api = envelope.api
      end
    end
  end
end
