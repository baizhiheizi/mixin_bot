# frozen_string_literal: true

require 'test_helper'

module MixinBot
  ##
  # Offline unit tests for the +ComputerApi+ delegate module.
  #
  # +ComputerApi+ is a thin pass-through to {MixinBot::Computer}; the value
  # of these tests is pinning the delegation wiring (argument forwarding,
  # URL routing on the +computer.mixin.one+ host, and the structural
  # encoding helpers) so refactors of the SDK surface don't silently
  # break parity with the Go / Node SDKs.
  #
  class TestComputerApi < Minitest::Test
    include WebMock::API

    SAMPLE_ADDR = '0xabc1230000000000000000000000000000000000'
    SAMPLE_ID = SecureRandom.uuid

    def setup
      WebMock.reset!
      MixinApiStubs.register!
    end

    # ===== HTTP delegations ===============================================

    def test_get_computer_info_hits_root
      stub_computer('GET', '/') { { 'data' => { 'version' => '1' } } }
      res = MixinBot.api.get_computer_info
      assert_equal '1', res['data']['version']
      assert_requested(:get, 'https://computer.mixin.one/')
    end

    def test_get_computer_info_delegates_to_underlying_computer_class
      stub_computer('GET', '/') { { 'data' => { 'version' => '1' } } }
      # The ComputerApi module is a thin delegate — it must return whatever
      # MixinBot::Computer.info returns (no transformation, no caching).
      assert_equal MixinBot::Computer.info, MixinBot.api.get_computer_info
    end

    def test_get_computer_user_hits_users_path
      stub_computer('GET', "/users/#{SAMPLE_ADDR}") { { 'data' => { 'id' => SAMPLE_ADDR } } }
      res = MixinBot.api.get_computer_user(SAMPLE_ADDR)
      assert_equal SAMPLE_ADDR, res['data']['id']
      assert_requested(:get, "https://computer.mixin.one/users/#{SAMPLE_ADDR}")
    end

    def test_get_computer_deployed_assets_hits_deployed_assets_path
      stub_computer('GET', '/deployed_assets') { { 'data' => [{ 'id' => 'a' }] } }
      res = MixinBot.api.get_computer_deployed_assets
      assert_kind_of Array, res['data']
      assert_requested(:get, 'https://computer.mixin.one/deployed_assets')
    end

    def test_get_computer_system_call_hits_system_calls_path
      stub_computer('GET', "/system_calls/#{SAMPLE_ID}") { { 'data' => { 'id' => SAMPLE_ID } } }
      res = MixinBot.api.get_computer_system_call(SAMPLE_ID)
      assert_equal SAMPLE_ID, res['data']['id']
      assert_requested(:get, "https://computer.mixin.one/system_calls/#{SAMPLE_ID}")
    end

    def test_computer_deploy_external_asset_posts_to_deployed_assets
      stub_computer('POST', '/deployed_assets') { { 'data' => { 'ok' => true } } }
      res = MixinBot.api.computer_deploy_external_asset(['asset-1'])
      assert_equal true, res['data']['ok']
      assert_requested(:post, 'https://computer.mixin.one/deployed_assets')
    end

    def test_computer_deploy_external_asset_rejects_solana_chain_id
      assert_raises(ArgumentError) do
        MixinBot.api.computer_deploy_external_asset([MixinBot::Computer::SOLANA_CHAIN_ID])
      end
    end

    def test_lock_computer_nonce_account_posts_with_mix
      stub_computer('POST', '/nonce_accounts') { { 'data' => { 'ok' => true } } }
      MixinBot.api.lock_computer_nonce_account('0xdeadbeef')
      assert_requested(:post, 'https://computer.mixin.one/nonce_accounts',
                       body: { mix: '0xdeadbeef' })
    end

    def test_get_fee_on_xin_based_on_sol_posts_sol_amount_as_string
      stub_computer('POST', '/fee') { { 'data' => { 'amount' => '0.1' } } }
      MixinBot.api.get_fee_on_xin_based_on_sol(1)
      assert_requested(:post, 'https://computer.mixin.one/fee',
                       body: { sol_amount: '1' })
    end

    def test_get_fee_on_xin_based_on_sol_coerces_numeric_to_string
      stub_computer('POST', '/fee') { { 'data' => { 'amount' => '0.5' } } }
      MixinBot.api.get_fee_on_xin_based_on_sol(0.5)
      assert_requested(:post, 'https://computer.mixin.one/fee',
                       body: { sol_amount: '0.5' })
    end

    # ===== Pure helpers (delegate) =======================================

    def test_computer_user_id_to_bytes_packs_positive_integer_as_big_endian_q
      bytes = MixinBot.api.computer_user_id_to_bytes(42)
      assert_equal "\x00\x00\x00\x00\x00\x00\x00\x2A".b, bytes
    end

    def test_computer_user_id_to_bytes_accepts_numeric_string
      bytes = MixinBot.api.computer_user_id_to_bytes('1')
      assert_equal "\x00\x00\x00\x00\x00\x00\x00\x01".b, bytes
    end

    def test_computer_user_id_to_bytes_rejects_negative_input
      assert_raises(ArgumentError) { MixinBot.api.computer_user_id_to_bytes(-1) }
    end

    def test_encode_operation_memo_is_one_byte_operation_plus_extra
      memo = MixinBot.api.encode_operation_memo(1, 'abc')
      assert_equal "\x01abc".b, memo.b
    end

    def test_encode_operation_memo_default_extra_is_empty
      memo = MixinBot.api.encode_operation_memo(2)
      assert_equal "\x02".b, memo.b
    end

    def test_encode_mtg_extra_packs_uuid_then_extra
      app_id = '0' * 32
      extra = 'hello'
      encoded = MixinBot.api.encode_mtg_extra(app_id, extra)
      decoded = Base64.urlsafe_decode64(encoded)
      # First 16 bytes are the UUID packed, rest is the extra.
      assert_equal MixinBot::UUID.new(hex: app_id).packed, decoded[0, 16]
      assert_equal 'hello', decoded[16..]
    end

    def test_encode_mtg_extra_is_urlsafe_without_padding
      app_id = '0' * 32
      extra = 'X' * 50
      encoded = MixinBot.api.encode_mtg_extra(app_id, extra)
      refute_includes encoded, '='
      assert_match(/\A[A-Za-z0-9_-]+\z/, encoded)
    end

    def test_decode_computer_extra_base64_round_trips
      app_id = '1' * 32
      extra = 'round-trip'
      encoded = MixinBot.api.encode_mtg_extra(app_id, extra)
      decoded_app_id, decoded_extra = MixinBot.api.decode_computer_extra_base64(encoded)
      assert_equal MixinBot::UUID.new(hex: app_id).unpacked, decoded_app_id
      assert_equal extra, decoded_extra
    end

    def test_decode_computer_extra_base64_short_input_returns_blank_app_id
      app_id, extra = MixinBot.api.decode_computer_extra_base64('')
      assert_equal '', app_id
      assert_nil extra
    end

    def test_build_system_call_extra_without_fid_packs_uid_cid_and_zero_flag
      uid = '7ed9292d-7c95-4333-aa48-a8c640064186'
      cid = 'a67c6e87-1c9e-4a1c-b81c-47a9f4f1bff1'
      extra = MixinBot.api.build_system_call_extra(uid, cid, skip_process: false, fid: nil)
      # 8 bytes (uid) + 16 bytes (cid) + 1 byte (skip_process flag) = 25 bytes.
      assert_equal 25, extra.bytesize
      assert_equal "\x00".b, extra.byteslice(24, 1).b
    end

    def test_build_system_call_extra_with_skip_process_emits_one_byte_flag
      uid = '7ed9292d-7c95-4333-aa48-a8c640064186'
      cid = 'a67c6e87-1c9e-4a1c-b81c-47a9f4f1bff1'
      extra = MixinBot.api.build_system_call_extra(uid, cid, skip_process: true, fid: nil)
      assert_equal "\x01".b, extra.byteslice(24, 1).b
    end

    def test_build_system_call_extra_with_fid_appends_packed_fid
      uid = '7ed9292d-7c95-4333-aa48-a8c640064186'
      cid = 'a67c6e87-1c9e-4a1c-b81c-47a9f4f1bff1'
      fid = '11111111-2222-3333-4444-555555555555'
      extra = MixinBot.api.build_system_call_extra(uid, cid, skip_process: false, fid:)
      # 8 + 16 + 1 + 16 (fid) = 41 bytes.
      assert_equal 41, extra.bytesize
    end

    private

    def stub_computer(method, path)
      WebMock.stub_request(method.downcase.to_sym, "https://computer.mixin.one#{path}").to_return(
        status: 200,
        headers: { 'Content-Type' => 'application/json' },
        body: JSON.generate(yield)
      )
    end
  end
end
