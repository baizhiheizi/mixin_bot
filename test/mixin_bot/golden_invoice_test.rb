# frozen_string_literal: true

require 'test_helper'

module MixinBot
  class GoldenInvoiceTest < Minitest::Test
    FIXTURE = File.expand_path('../fixtures/golden/invoice.json', __dir__)

    def setup
      @data = JSON.parse(File.read(FIXTURE))
    end

    def test_storage_recipient_mix_matches_go
      s = @data['storage_recipient']
      mix = MixinBot.utils.build_mix_address(members: s['members'], threshold: s['threshold'])
      assert_equal s['expected_mix'], mix
    end

    def test_two_entry_invoice_round_trip_matches_go
      inv = @data['two_entry_invoice']
      recipient = MixAddress.new(address: inv['recipient'])
      e1 = InvoiceEntry.new(
        trace_id: '772e6bef-3bff-4fcc-987d-29bafca74d63',
        asset_id: 'c6d0c728-2624-429b-8e0d-d9d19b6592fa',
        amount: '0.12345678',
        extra: 'extra one',
        hash_references: ['7ecf9fc49ff4d2e36424b8e53e67aed8cc4e9d08d7cbdca7d8bdb153ed2fcdde']
      )
      e2 = InvoiceEntry.new(
        trace_id: '3552d116-b29d-4d72-9b24-3ca3b2e0f9c2',
        asset_id: '43d61dcd-e413-450d-80b8-101d5e903357',
        amount: '0.23345678',
        extra: 'extra two',
        index_references: [0],
        hash_references: ['4a5f79c76872524c6a4a81b174338584e790f09fb059c39cf2a894de1b3c31c6']
      )
      one = Invoice.new(recipient:, entries: [e1, e2])
      assert_equal inv['expected_address'], one.address

      two = Invoice.new(address: inv['expected_address'])
      assert_equal inv['expected_address'], two.address
      assert_equal inv['recipient'], two.recipient.address
      assert_equal 2, two.entries.size
      assert_equal e1.trace_id, two.entries[0].trace_id
      assert_equal e2.trace_id, two.entries[1].trace_id
    end
  end
end
