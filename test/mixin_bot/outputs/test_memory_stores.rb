# frozen_string_literal: true

require 'test_helper'
require 'mixin_bot/rails'
require 'support/fake_clock'

module MixinBot
  class MemoryStoresTest < Minitest::Test
    def setup
      super
      @clock = FakeClock.new
      @receipts = MixinBot::Outputs::MemoryReceiptStore.new(clock: @clock.to_proc)
      @cursor = MixinBot::Outputs::MemoryCursorStore.new
    end

    def output(id = 'out-1')
      {
        'output_id' => id,
        'amount' => '1.5',
        'asset_id' => CNB_ASSET_ID,
        'state' => 'unspent',
        'transaction_hash' => 'ab' * 32,
        'output_index' => 0,
        'created_at' => '2026-09-19T12:00:00Z'
      }
    end

    def test_record_returns_created_receipt_with_output_fields
      receipt, status = @receipts.record!(bot_app_id: 'app-1', output: output)

      assert_equal :created, status
      assert_equal 'out-1', receipt.output_id
      assert_equal 'app-1', receipt.bot_app_id
      assert_equal '1.5', receipt.amount
      assert_equal CNB_ASSET_ID, receipt.asset_id
      assert_equal 'unspent', receipt.state
      assert_equal 'ab' * 32, receipt.transaction_hash
      assert_equal 0, receipt.output_index
      assert_equal '2026-09-19T12:00:00Z', receipt.created_at
      assert_nil receipt.enqueued_at
    end

    def test_duplicate_record_returns_existing_receipt
      first, = @receipts.record!(bot_app_id: 'app-1', output: output)

      second, status = @receipts.record!(bot_app_id: 'app-1', output: output)

      assert_equal :duplicate, status
      assert_same first, second
    end

    def test_same_output_id_under_a_different_bot_is_independent
      _, first_status = @receipts.record!(bot_app_id: 'app-1', output: output)
      _, second_status = @receipts.record!(bot_app_id: 'app-2', output: output)

      assert_equal :created, first_status
      assert_equal :created, second_status
    end

    def test_unenqueued_filters_by_bot_age_and_dispatch_state
      old_receipt, = @receipts.record!(bot_app_id: 'app-1', output: output('out-1'))
      enqueued_receipt, = @receipts.record!(bot_app_id: 'app-1', output: output('out-2'))
      other_bot, = @receipts.record!(bot_app_id: 'app-2', output: output('out-3'))
      @receipts.mark_enqueued!(enqueued_receipt)

      @clock.advance 10
      recent, = @receipts.record!(bot_app_id: 'app-1', output: output('out-4'))

      pending = @receipts.unenqueued(bot_app_id: 'app-1', older_than: @clock.now - 5)

      assert_equal [old_receipt], pending # old enough, this bot, not enqueued
      refute_includes pending, enqueued_receipt # already enqueued
      refute_includes pending, other_bot     # other bot's receipt
      refute_includes pending, recent        # too fresh
    end

    def test_cache_snapshot_writes_bridge_fields
      receipt, = @receipts.record!(bot_app_id: 'app-1', output: output)

      receipt.cache_snapshot!(memo: 'M', opponent_id: 'O', trace_id: 'T')

      assert_equal 'M', receipt.memo
      assert_equal 'O', receipt.opponent_id
      assert_equal 'T', receipt.trace_id
    end

    def test_cursor_value_and_advance
      assert_nil @cursor.value(bot_app_id: 'app-1')

      @cursor.advance!(bot_app_id: 'app-1', value: '2026-09-19T12:00:00Z')

      assert_equal '2026-09-19T12:00:00Z', @cursor.value(bot_app_id: 'app-1')
      assert_nil @cursor.value(bot_app_id: 'app-2')
    end
  end
end
