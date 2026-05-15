# frozen_string_literal: true

require 'test_helper'

module MixinBot
  class TestTransaction < Minitest::Test
    def setup
    end

    def test_build_object_transaction
      extra = 'May the HOPE be with you!'
      tx = MixinBot.api.build_object_transaction extra

      raw = MixinBot.utils.encode_raw_transaction tx

      request_id = SecureRandom.uuid
      request = MixinBot.api.create_safe_transaction_request(request_id, raw)['data']

      assert_equal request.first['request_id'], request_id
    end

    def test_build_inscribe_transaction
      text = 'May the HOPE be with you!'
      content = "text/plain;charset=UTF-8;#{Base64.strict_encode64(text)}"
      collection_hash = 'd448f7d5ffc44f08e8c41f89573039dfbfc7d94d7f40314ac1780186005a0f3f'

      tx = MixinBot.api.build_inscribe_transaction(content:, collection_hash:)
      raw = MixinBot.utils.encode_raw_transaction tx

      request_id = SecureRandom.uuid
      request = MixinBot.api.create_safe_transaction_request(request_id, raw)['data']

      assert_equal request.first['request_id'], request_id
    end
  end
end
