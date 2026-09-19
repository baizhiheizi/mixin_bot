# frozen_string_literal: true

require 'test_helper'
require 'mixin_bot/rails'
require 'support/fake_clock'
require 'cgi'
require 'json'

module MixinBot
  class OutputsPollerTest < Minitest::Test
    include WebMock::API

    def setup
      super
      @clock = FakeClock.new
      @receipts = MixinBot::Outputs::MemoryReceiptStore.new(clock: @clock.to_proc)
      @enqueued = []
      @enqueuer = ->(processor, receipt) { @enqueued << [processor, receipt] }
      @output_queries = []
      @pages = []
      @outputs_stub = stub_request(:get, %r{https://api\.mixin\.one/safe/outputs}).to_return do |request|
        @output_queries << URI.decode_www_form(request.uri.query.to_s).to_h
        page = @pages.shift || []
        { status: 200, headers: { 'Content-Type' => 'application/json' },
          body: JSON.generate({ 'data' => page, 'error' => nil }) }
      end
    end

    def teardown
      remove_request_stub(@outputs_stub)
      super
    end

    def output(id, sequence: 100, created_at: '2026-09-19T12:00:00Z', amount: '1.5', state: 'unspent')
      {
        'output_id' => id,
        'amount' => amount,
        'asset_id' => CNB_ASSET_ID,
        'state' => state,
        'transaction_hash' => 'ab' * 32,
        'output_index' => 0,
        'sequence' => sequence,
        'created_at' => created_at
      }
    end

    def build_poller(**)
      MixinBot::Outputs::Poller.new(
        receipts: @receipts,
        processors: [MatchingProcessor, OtherProcessor],
        interval: 5, enqueuer: @enqueuer,
        sleeper: ->(_s) { raise 'poller must not sleep in these tests' },
        clock: @clock.to_proc,
        **
      )
    end

    # ---- page processing ----

    def test_absorbs_a_page_advances_cursor_and_enqueues_matches
      @pages << [output('out-1'), output('out-2', amount: '9.9')]
      poller = build_poller

      count = poller.poll_once

      assert_equal 2, count
      query = @output_queries.first
      assert_equal '500', query['limit']
      assert_equal 'ASC', query['order']
      assert_equal 100, @receipts.cursor_value(bot_app_id: MixinBot.config.app_id)
      # both processors match both outputs
      assert_equal 4, @enqueued.size
      assert_equal [MatchingProcessor, OtherProcessor] * 2, @enqueued.map(&:first)
    end

    def test_fetch_uses_the_derived_cursor_as_offset
      # receipts already absorbed sequence 90 — restart derives from them
      @receipts.record!(bot_app_id: MixinBot.config.app_id,
                        output: output('old-1', sequence: 90))
      poller = build_poller

      poller.poll_once

      assert_equal '90', @output_queries.first['offset']
    end

    def test_forwarded_poll_filters
      poller = build_poller(asset: CNB_ASSET_ID, members: %w[user-a user-b], threshold: 2)

      poller.poll_once

      query = @output_queries.first
      assert_equal CNB_ASSET_ID, query['asset']
      # the API receives members hashed
      assert_equal MixinBot.utils.hash_members(%w[user-a user-b]), query['members']
      assert_equal '2', query['threshold']
    end

    def test_refetched_output_is_not_enqueued_twice
      @pages << [output('out-1')]
      poller = build_poller
      poller.poll_once

      @pages << [output('out-1'), output('out-2')] # cursor overlap
      poller.poll_once

      assert_equal 4, @enqueued.size # 2 processors x 2 distinct outputs
      receipts = @receipts.unenqueued(bot_app_id: MixinBot.config.app_id, older_than: @clock.now + 1)
      assert_empty receipts
    end

    def test_output_matching_no_processor_is_recorded_and_stamped
      poller = build_poller(processors: [])
      @pages << [output('quiet-1')]

      poller.poll_once

      receipts = @receipts.instance_variable_get(:@records).values
      assert_equal 1, receipts.size
      refute_nil receipts.first.enqueued_at
      assert_empty @enqueued
    end

    # ---- cursor atomicity ----

    def test_mid_page_failure_leaves_the_cursor_untouched
      @pages << [output('out-1'), output('out-2')]
      broken = MixinBot::Outputs::MemoryReceiptStore.new(clock: @clock.to_proc)
      def broken.record!(**)
        raise 'disk on fire'
      end
      poller = build_poller(receipts: broken)

      assert_raises(RuntimeError) { poller.poll_once }

      assert_nil @receipts.cursor_value(bot_app_id: MixinBot.config.app_id)
    end

    def test_next_cycle_after_failure_refetches_the_same_page
      @pages << [output('out-1'), output('out-2')]
      poller = build_poller
      poller.poll_once
      poller.poll_once # page now empty; overlap already deduped

      assert_equal '100', @output_queries.second['offset']
      assert_equal '100', @output_queries.last['offset']
    end

    # ---- restart ----

    def test_restarted_poller_resumes_from_the_receipt_derived_cursor
      @pages << [output('out-1', sequence: 300)]
      build_poller.poll_once

      # a fresh poller over the SAME receipt store (restart)
      restarted = build_poller
      restarted.poll_once

      assert_equal '300', @output_queries.last['offset']
      assert_equal 2, @enqueued.size # only the first cycle enqueued
    end

    # ---- sweep of undispatched receipts ----

    def test_sweep_rediscovers_undispatched_receipts
      poller = build_poller

      receipt, = @receipts.record!(bot_app_id: MixinBot.config.app_id, output: output('crashed-1'))
      receipt.recorded_at = @clock.now - 60 # recorded long ago, enqueue never happened

      @clock.advance 1
      poller.poll_once # empty page; sweep must pick the receipt up

      assert_equal [MatchingProcessor, OtherProcessor], @enqueued.map(&:first)
      refute_nil receipt.enqueued_at
    end

    def test_fresh_receipts_are_not_swept
      # A receipt recorded seconds ago belongs to the normal pipeline, not the
      # crash sweep: it must not be double-dispatched.
      receipt, = @receipts.record!(bot_app_id: MixinBot.config.app_id, output: output('fresh-1'))
      receipt.recorded_at = @clock.now - 1
      poller = build_poller(interval: 300)
      poller.poll_once # empty page

      assert_empty @enqueued
      assert_nil receipt.enqueued_at
    end

    # ---- dispatch error containment ----

    def test_enqueue_failure_keeps_receipt_undispatched_without_raising
      exploding = ->(_p, _r) { raise 'queue down' }
      logs = []
      poller = build_poller(enqueuer: exploding, logger: ->(level, detail) { logs << [level, detail] })
      @pages << [output('out-1')]

      poller.poll_once # must not raise

      receipt = @receipts.instance_variable_get(:@records).values.first
      assert_nil receipt.enqueued_at
      assert_equal :dispatch_error, logs.first[0]
    end

    # ---- run loop ----

    def test_run_cycles_until_stop
      cycles = 0
      sleeper = lambda { |_s|
        cycles += 1
        @stop_after_two&.call
      }
      poller = MixinBot::Outputs::Poller.new(
        receipts: @receipts, processors: [],
        interval: 7, enqueuer: @enqueuer, sleeper:, clock: @clock.to_proc
      )
      @stop_after_two = -> { poller.stop if cycles >= 2 }

      poller.run

      assert_equal 2, cycles
    end

    def test_run_logs_cycle_errors_and_keeps_going
      logs = []
      broken_receipts = Object.new
      def broken_receipts.unenqueued(...)
        raise 'receipt store offline'
      end
      poller = MixinBot::Outputs::Poller.new(
        receipts: broken_receipts, processors: [],
        interval: 1, enqueuer: @enqueuer,
        sleeper: ->(_s) { poller.stop },
        logger: ->(level, detail) { logs << [level, detail] }
      )

      poller.run

      assert_equal :poll_error, logs.first[0]
    end

    # ---- processor fixtures ----

    class MatchingProcessor < MixinBot::Outputs::Processor
      def self.matches?(_envelope)
        true
      end

      def process; end
    end

    class OtherProcessor < MixinBot::Outputs::Processor
      def self.matches?(_envelope)
        true
      end

      def process; end
    end
  end
end
