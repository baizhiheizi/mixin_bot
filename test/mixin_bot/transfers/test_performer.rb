# frozen_string_literal: true

require 'test_helper'
require 'mixin_bot/rails'
require 'support/fake_transfer'
require 'json'

module MixinBot
  class TransfersPerformerTest < Minitest::Test
    include WebMock::API

    def setup
      super
      @submitted = []
      @submit_stub = stub_request(:post, 'https://api.mixin.one/safe/transactions').to_return do |request|
        payload = JSON.parse(request.body).first
        @submitted << payload
        { status: 200, headers: { 'Content-Type' => 'application/json' },
          body: JSON.generate({ 'data' => [{ 'request_id' => payload['request_id'], 'transaction_hash' => 'aa' * 32 }],
                                'error' => nil }) }
      end
    end

    def teardown
      remove_request_stub(@submit_stub) if @submit_stub
      super
    end

    def transfer(state: 'pending')
      FakeTransfer.new(
        recipient_id: TEST_UID, asset_id: CNB_ASSET_ID,
        amount: '0.001', memo: 'payout', state:
      )
    end

    # ---- success: pending → broadcast → confirmed ----

    def test_successful_send_confirms_with_the_transaction_hash
      record = transfer

      record.perform!

      assert_equal 'confirmed', record.state
      assert_equal 'aa' * 32, record.transaction_hash
      # the intermediate broadcast hop is visible in the audit trail
      assert_equal 'broadcast', record.previous_state
      assert_equal 1, @submitted.size
    end

    def test_send_uses_the_trace_id_as_request_id
      record = transfer

      record.perform!

      assert_equal record.trace_id, @submitted.first['request_id']
    end

    # ---- definitive rejection: failed, never retried ----

    def test_definitive_rejection_marks_the_transfer_failed
      remove_request_stub(@submit_stub)
      @submit_stub = stub_request(:post, 'https://api.mixin.one/safe/transactions')
                     .to_return(status: 400, headers: { 'Content-Type' => 'application/json' },
                                body: JSON.generate({ 'error' => { 'code' => 20_117, 'desc' => 'insufficient balance' } }))

      record = transfer

      record.perform!

      assert_equal 'failed', record.state
      assert_match(/InsufficientBalanceError/, record.error)
    end

    # ---- indeterminate outcome: reconciling ----

    def test_network_timeout_marks_the_transfer_reconciling
      remove_request_stub(@submit_stub)
      @submit_stub = stub_request(:post, 'https://api.mixin.one/safe/transactions')
                     .to_raise(Faraday::ConnectionFailed)

      record = transfer

      record.perform!

      assert_equal 'reconciling', record.state
      assert_match(/ConnectionFailed/, record.error)
    end

    # ---- reconciliation ----

    def test_reconcile_confirms_from_the_trace_snapshot_without_resending
      remove_request_stub(@submit_stub)
      @submit_stub = nil
      snapshot_stub = stub_request(:get, "https://api.mixin.one/safe/snapshots/trace/#{transfer.trace_id}")
                      .to_return(status: 200, headers: { 'Content-Type' => 'application/json' },
                                 body: JSON.generate({ 'data' => { 'snapshot_id' => 'snap-1',
                                                                   'transaction_hash' => 'ff' * 32 },
                                                       'error' => nil }))
      record = transfer(state: 'reconciling')
      record.transaction_hash = nil

      result = record.reconcile!

      assert_equal :confirmed, result
      assert_equal 'confirmed', record.state
      assert_equal 'ff' * 32, record.transaction_hash
      assert_not_requested :post, 'https://api.mixin.one/safe/transactions'
    ensure
      remove_request_stub(snapshot_stub)
    end

    def test_reconcile_resends_with_the_same_trace_when_no_snapshot_exists
      snapshot_stub = stub_request(:get, "https://api.mixin.one/safe/snapshots/trace/#{transfer.trace_id}")
                      .to_return(status: 404, headers: { 'Content-Type' => 'application/json' },
                                 body: JSON.generate({ 'error' => { 'code' => 404, 'desc' => 'not found' } }))

      record = transfer(state: 'reconciling')

      result = record.reconcile!

      assert_equal :resent, result
      assert_equal 'confirmed', record.state
      assert_equal record.trace_id, @submitted.first['request_id']
    ensure
      remove_request_stub(snapshot_stub)
    end

    def test_reconcile_reports_failed_when_the_resend_is_rejected
      remove_request_stub(@submit_stub)
      @submit_stub = stub_request(:post, 'https://api.mixin.one/safe/transactions')
                     .to_return(status: 400, headers: { 'Content-Type' => 'application/json' },
                                body: JSON.generate({ 'error' => { 'code' => 20_117,
                                                                   'desc' => 'insufficient balance' } }))
      snapshot_stub = stub_request(:get, "https://api.mixin.one/safe/snapshots/trace/#{transfer.trace_id}")
                      .to_return(status: 404, headers: { 'Content-Type' => 'application/json' },
                                 body: JSON.generate({ 'error' => { 'code' => 404, 'desc' => 'not found' } }))

      record = transfer(state: 'reconciling')

      result = record.reconcile!

      assert_equal :failed, result
      assert_equal 'failed', record.state
    ensure
      remove_request_stub(snapshot_stub)
    end
  end
end
