# frozen_string_literal: true

require 'test_helper'

module MixinBot
  class TestTransactionFixture < Minitest::Test
    FIXTURE = File.expand_path('../fixtures/transactions/version3_multi_io.hex', __dir__)

    def test_hex_fixture_round_trips_byte_for_byte
      hex = File.read(FIXTURE).strip
      decoded = MixinBot.utils.decode_raw_transaction(hex)
      round = MixinBot.utils.encode_raw_transaction(decoded)
      assert_equal hex, round
    end
  end
end
