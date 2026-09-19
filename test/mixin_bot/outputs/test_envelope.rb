# frozen_string_literal: true

require 'test_helper'
require 'mixin_bot/rails'
require 'json'

module MixinBot
  class OutputsEnvelopeTest < Minitest::Test
    include WebMock::API

    SNAPSHOT_BODY = {
      'snapshot_id' => 'snap-1',
      'memo' => 'ORDER-42',
      'opponent_id' => 'payer-1',
      'trace_id' => 'trace-1'
    }.freeze

    def setup
      super
      @bridge_calls = []
      @bridge_stub = stub_request(:post, 'https://api.mixin.one/safe/snapshots/notifications')
                     .to_return do |request|
        @bridge_calls << JSON.parse(request.body)
        { status: 200, headers: { 'Content-Type' => 'application/json' },
          body: JSON.generate({ 'data' => SNAPSHOT_BODY, 'error' => nil }) }
      end
    end

    def teardown
      remove_request_stub(@bridge_stub)
      super
    end

    def receipt(memo: nil, opponent_id: nil, trace_id: nil, state: 'unspent')
      MixinBot::Outputs::MemoryReceiptStore::Receipt.new(
        id: 1, bot_app_id: MixinBot.config.app_id, output_id: 'out-1',
        amount: '1.5', asset_id: CNB_ASSET_ID, state:,
        transaction_hash: 'ab' * 32, output_index: 3,
        memo:, opponent_id:, trace_id:
      )
    end

    def test_exposes_output_fields_and_decimal_amount
      envelope = MixinBot::Outputs::Envelope.new(receipt, api: MixinBot.api)

      assert_equal 'out-1', envelope.output_id
      assert_equal BigDecimal('1.5'), envelope.amount
      assert_equal CNB_ASSET_ID, envelope.asset_id
      assert_equal 'ab' * 32, envelope.transaction_hash
      assert_equal 3, envelope.output_index
      refute_predicate envelope, :spent?
      assert_predicate MixinBot::Outputs::Envelope.new(receipt(state: 'spent'), api: MixinBot.api), :spent?
    end

    def test_memo_bridges_once_and_caches_onto_receipt
      record = receipt
      envelope = MixinBot::Outputs::Envelope.new(record, api: MixinBot.api)

      assert_equal 'ORDER-42', envelope.memo
      assert_equal 'payer-1', envelope.opponent_id
      assert_equal 'trace-1', envelope.trace_id

      envelope.memo # second access must not bridge again

      assert_equal 1, @bridge_calls.size
      assert_equal 'ORDER-42', record.memo
      assert_equal 'payer-1', record.opponent_id
      assert_equal 'trace-1', record.trace_id
    end

    def test_pre_cached_receipt_skips_the_bridge
      record = receipt(memo: 'CACHED', opponent_id: 'payer-2', trace_id: 'trace-2')
      envelope = MixinBot::Outputs::Envelope.new(record, api: MixinBot.api)

      assert_equal 'CACHED', envelope.memo
      assert_equal 'payer-2', envelope.opponent_id
      assert_equal 'trace-2', envelope.trace_id

      assert_empty @bridge_calls
    end

    def test_bridge_failure_logs_and_continues_with_nil_fields
      remove_request_stub(@bridge_stub)
      @bridge_stub = stub_request(:post, 'https://api.mixin.one/safe/snapshots/notifications')
                     .to_return(status: 500)
      original_logger = MixinBot::Outputs.logger
      logs = []
      MixinBot::Outputs.logger = ->(level, detail) { logs << [level, detail] }
      stub_request(:post, 'https://api.mixin.one/safe/snapshots/notifications').to_return(status: 500)

      envelope = MixinBot::Outputs::Envelope.new(receipt, api: MixinBot.api)

      assert_nil envelope.memo
      assert_nil envelope.opponent_id
      assert_nil envelope.trace_id
      assert_equal :snapshot_bridge_error, logs.first[0]
    ensure
      MixinBot::Outputs.logger = original_logger
    end

    def test_snapshot_payload_request_carries_output_identity
      envelope = MixinBot::Outputs::Envelope.new(receipt, api: MixinBot.api)
      envelope.memo

      assert_equal 1, @bridge_calls.size
      body = @bridge_calls.first
      assert_equal 'ab' * 32, body['transaction_hash']
      assert_equal 3, body['output_index']
      assert_equal MixinBot.config.app_id, body['receiver_id']
    end
  end
end
