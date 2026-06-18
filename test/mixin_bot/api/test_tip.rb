# frozen_string_literal: true

require 'test_helper'

module MixinBot
  class TestTip < Minitest::Test
    def test_tip_body_returns_ascii_bytes
      assert_equal 'TIP:VERIFY:ping'.b, MixinBot.api.tip_body('TIP:VERIFY:ping')
      assert_equal ''.b, MixinBot.api.tip_body('')
      assert_equal '42'.b, MixinBot.api.tip_body(42)
    end

    def test_tip_body_for_verify_zero_pads_to_32_digits
      body = MixinBot.api.tip_body_for_verify(1)
      assert_equal "TIP:VERIFY:#{'0' * 31}1", body
      assert_equal 43, body.length
    end

    def test_tip_body_for_verify_uses_supplied_timestamp
      body = MixinBot.api.tip_body_for_verify(1_700_000_000_000_000_000)
      assert_equal 'TIP:VERIFY:1700000000000000000', body
    end

    def test_tip_body_for_withdrawal_create_concatenates_fields_in_order
      body = MixinBot.api.tip_body_for_withdrawal_create('addr', '1', '0', 'trace', 'memo')
      assert_equal 'TIP:WITHDRAWAL:CREATE:addr10tracememo', body
    end

    def test_tip_body_for_transfer_concatenates_fields_in_order
      body = MixinBot.api.tip_body_for_transfer('asset', 'user', '7', 'trace', 'hi')
      assert_equal 'TIP:TRANSFER:CREATE:assetuser7tracehi', body
    end

    def test_tip_body_for_raw_transaction_create_joins_receivers_array
      body = MixinBot.api.tip_body_for_raw_transaction_create(
        'asset', 'opponent', %w[r1 r2 r3], 2, '5', 'trace', 'memo'
      )
      assert_equal 'TIP:TRANSACTION:CREATE:assetopponentr1r2r325tracememo', body
    end

    def test_tip_body_for_phone_number_update
      body = MixinBot.api.tip_body_for_phone_number_update('verif', '123456')
      assert_equal 'TIP:PHONE:NUMBER:UPDATE:verif123456', body
    end

    def test_tip_body_for_emergency_contact_create
      body = MixinBot.api.tip_body_for_emergency_contact_create('verif', '654321')
      assert_equal 'TIP:EMERGENCY:CONTACT:CREATE:verif654321', body
    end

    def test_tip_body_for_address_add
      body = MixinBot.api.tip_body_for_address_add('asset', 'pub', 'tag', 'name')
      assert_equal 'TIP:ADDRESS:ADD:assetpubtagname', body
    end

    def test_tip_body_for_provisioning_update
      body = MixinBot.api.tip_body_for_provisioning_update('device', 'secret')
      assert_equal 'TIP:PROVISIONING:UPDATE:devicesecret', body
    end

    def test_tip_body_for_ownership_transfer
      body = MixinBot.api.tip_body_for_ownership_transfer('user-id')
      assert_equal 'TIP:APP:OWNERSHIP:TRANSFER:user-id', body
    end

    def test_tip_body_for_sequencer_register
      body = MixinBot.api.tip_body_for_sequencer_register('user-id', 'pub')
      assert_equal 'SEQUENCER:REGISTER:user-idpub', body
    end

    def test_tip_migrate_body
      body = MixinBot.api.tip_migrate_body('aabbcc')
      assert_equal 'TIP:MIGRATE:aabbcc', body
    end

    def test_encrypt_tip_pin_rejects_unknown_action
      assert_raises(ArgumentError) do
        MixinBot.api.encrypt_tip_pin('000000', 'NOT:A:REAL:ACTION:')
      end
    end

    def test_encrypt_tip_pin_accepts_all_documented_actions
      action = 'TIP:VERIFY:'
      encrypted = MixinBot.api.encrypt_tip_pin('000000', action)
      refute_nil encrypted
      refute_empty encrypted
    end
  end
end