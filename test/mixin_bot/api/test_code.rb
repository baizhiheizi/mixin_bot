# frozen_string_literal: true

require 'test_helper'

module MixinBot
  class TestCode < Minitest::Test
    def test_read_code
      code_id = SecureRandom.uuid
      r = MixinBot.api.read_code(code_id)

      assert_equal code_id, r['data']['code_id']
    end

    def test_create_scheme
      r = MixinBot.api.create_scheme('mixin://users/123')

      refute_nil r['data']['scheme']
    end
  end
end
