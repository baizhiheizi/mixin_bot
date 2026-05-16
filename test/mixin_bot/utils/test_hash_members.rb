# frozen_string_literal: true

require 'test_helper'

module MixinBot
  class TestHashMembers < Minitest::Test
    def test_matches_go_crypto_test_vector
      j = JSON.parse(File.read(File.expand_path('../../fixtures/golden/hash_members.json', __dir__)))
      assert_equal j['expected_hex'], MixinBot.utils.hash_members(j['members'])
    end
  end
end
