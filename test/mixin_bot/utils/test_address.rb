# frozen_string_literal: true

require 'test_helper'

module MixinBot::Utils
  class TestAddress < Minitest::Test
    BURNING_ADDRESS = 'XIN8b7CsqwqaBP7576hvWzo7uDgbU9TB5KGU4jdgYpQTi2qrQGpBtrW49ENQiLGNrYU45e2wwKRD7dEUPtuaJYps2jbR4dH'

    def setup
    end

    def test_utils_burning_address
      assert MixinBot.utils.burning_address == BURNING_ADDRESS
    end

    def test_utils_parse_mix_address
      user_id = TEST_UID
      mix_address = MixinBot.utils.build_mix_address(
        members: [user_id],
        threshold: 1
      )
      address = MixinBot.utils.parse_mix_address mix_address

      assert_equal [user_id], address[:members]
      assert address[:threshold] == 1

      user_id2 = 'b847a455-aa41-4f7d-8038-0aefbe40dcaa'
      mix_address2 = 'MIX3QEfo9wugeUo6B38nmJWw51iQ1nBCYR'
      assert MixinBot.utils.parse_mix_address(mix_address2)[:members] == [user_id2]
    end

    def test_utils_members_order_do_not_affect_mix_address
      user_id = TEST_UID
      user_id2 = TEST_UID_2
      mix_address = MixinBot.utils.build_mix_address(
        members: [user_id, user_id2],
        threshold: 1
      )
      mix_address2 = MixinBot.utils.build_mix_address(
        members: [user_id2, user_id],
        threshold: 1
      )
      assert mix_address == mix_address2
    end
  end
end
