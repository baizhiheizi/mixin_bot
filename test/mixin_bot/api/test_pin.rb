# frozen_string_literal: true

require 'test_helper'

module MixinBot
  class TestPin < Minitest::Test
    def setup; end

    def test_verify_pin
      res = MixinBot.api.verify_pin(PIN_CODE)

      refute_nil res['data']
    end

    # it 'decrypt encrypted pin_code' do
    def test_decrypt_encrypted_pin
      encrypted_pin = MixinBot.api.encrypt_pin(PIN_CODE)
      decrypted_pin = MixinBot.api.decrypt_pin(encrypted_pin)

      assert_equal PIN_CODE, decrypted_pin.byteslice(0, PIN_CODE.bytesize)
    end
  end
end
