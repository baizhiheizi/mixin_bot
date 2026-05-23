# frozen_string_literal: true

require 'test_helper'

module MixinBot
  class TestCircle < Minitest::Test
    def setup
      @circle_id = SecureRandom.uuid
    end

    def test_circles
      r = MixinBot.api.circles
      assert r['data'].is_a?(Array)
    end

    def test_create_and_fetch_circle
      created = MixinBot.api.create_circle(name: 'Work')
      cid = created['data']['circle_id']
      refute_nil cid

      r = MixinBot.api.circle(cid)
      assert_equal cid, r['data']['circle_id']
    end

    def test_update_circle
      created = MixinBot.api.create_circle(name: 'Old')
      cid = created['data']['circle_id']

      r = MixinBot.api.update_circle(cid, name: 'New')
      assert_equal 'New', r['data']['name']
    end

    def test_delete_circle
      created = MixinBot.api.create_circle(name: 'Temp')
      cid = created['data']['circle_id']

      r = MixinBot.api.delete_circle(cid)
      assert r['data']
    end

    def test_circle_conversations
      r = MixinBot.api.circle_conversations(@circle_id)
      assert r['data'].is_a?(Array)
    end

    def test_add_and_remove_user_from_circle
      created = MixinBot.api.create_circle(name: 'Friends')
      cid = created['data']['circle_id']

      r = MixinBot.api.add_user_to_circle(user_id: TEST_UID, circle_id: cid)
      assert_equal cid, r['data']['circle_id']

      r = MixinBot.api.remove_user_from_circle(user_id: TEST_UID, circle_id: cid)
      assert_equal 'REMOVE', r['data']['action']
    end

    def test_add_and_remove_conversation_from_circle
      created = MixinBot.api.create_circle(name: 'Groups')
      cid = created['data']['circle_id']
      conversation_id = MixinBot.api.unique_conversation_id(TEST_UID)

      r = MixinBot.api.add_conversation_to_circle(conversation_id:, circle_id: cid)
      assert_equal cid, r['data']['circle_id']

      r = MixinBot.api.remove_conversation_from_circle(conversation_id:, circle_id: cid)
      assert_equal 'REMOVE', r['data']['action']
    end
  end
end
