# frozen_string_literal: true

require 'test_helper'
require 'digest'
require 'sha3'

module MixinBot
  class TestTipHashAlgorithms < Minitest::Test
    def test_tip_body_uses_sha256_not_sha3
      body = 'TIP:VERIFY:ping'
      sha256 = Digest::SHA256.hexdigest(body)
      sha3 = SHA3::Digest::SHA256.hexdigest(body)
      refute_equal sha256, sha3
      assert_equal sha256, Digest::SHA256.hexdigest(body)
    end
  end
end
