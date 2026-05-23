# frozen_string_literal: true

require 'test_helper'

module MixinBot
  class TestConversation < Minitest::Test
    def setup
      @conversation_id = MixinBot.api.unique_conversation_id(TEST_UID)
      MixinBot.config.debug = true
    end

    def teardown
      MixinBot.config.debug = false
    end

    def test_unique_conversation_id_format
      cid = MixinBot.api.unique_conversation_id(TEST_UID)
      assert_match(/\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i, cid)
    end

    def test_conversation
      r = MixinBot.api.conversation @conversation_id

      assert r['data']['conversation_id'] == @conversation_id
    end

    def test_conversation_by_user_id
      r = MixinBot.api.conversation_by_user_id TEST_UID

      assert r['data']['conversation_id'] == @conversation_id
    end

    def test_create_contact_conversation
      r = MixinBot.api.create_contact_conversation TEST_UID

      assert r['data']['conversation_id'] == @conversation_id
    end

    def test_create_group_conversation_and_manage
      # create group
      group = MixinBot.api.create_group_conversation(
        user_ids: [TEST_UID, TEST_UID_2],
        name: 'Created Group by test',
        announcement: 'Announcement: Attention'
      )
      refute_nil group['data']['conversation_id']

      # update name
      name = "Updated at #{Time.now}"
      r = MixinBot.api.update_group_conversation_name(
        name:,
        conversation_id: group['data']['conversation_id']
      )
      assert r['data']['name'] == name

      # update announcement
      announcement = 'Announcement: Attention'
      r = MixinBot.api.update_group_conversation_announcement(
        announcement:,
        conversation_id: group['data']['conversation_id']
      )
      assert r['data']['announcement'] == announcement

      # add role
      r = MixinBot.api.update_conversation_participants_role(
        conversation_id: group['data']['conversation_id'],
        participants: [
          { user_id: TEST_UID, role: 'ADMIN' }
        ]
      )
      assert r['data']['participants'].find(&->(user) { user['user_id'] == TEST_UID })['role'] == 'ADMIN'

      # remove role
      r = MixinBot.api.update_conversation_participants_role(
        conversation_id: group['data']['conversation_id'],
        participants: [
          { user_id: TEST_UID, role: '' }
        ]
      )
      assert r['data']['participants'].find(&->(user) { user['user_id'] == TEST_UID })['role'] == ''

      # rotate conversation
      r = MixinBot.api.rotate_conversation group['data']['conversation_id']
      assert r['data']['code_id'] != group['data']['code_id']

      # add participants
      r = MixinBot
          .api
          .remove_conversation_participants(
            conversation_id: group['data']['conversation_id'],
            user_ids: [TEST_UID]
          )
      assert r['data']['participants'].find(&->(user) { user['user_id'] == TEST_UID }).nil?

      # remove participants
      r = MixinBot
          .api
          .add_conversation_participants(
            conversation_id: group['data']['conversation_id'],
            user_ids: [TEST_UID]
          )
      assert r['data']['participants'].find(&->(user) { user['user_id'] == TEST_UID }).present?

      # exit conversation
      r = MixinBot.api.exit_conversation group['data']['conversation_id']
      assert r['data'].nil?
    end

    def test_mute_and_unmute_conversation
      group = MixinBot.api.create_group_conversation(
        user_ids: [TEST_UID, TEST_UID_2],
        name: 'Mute Test Group'
      )
      cid = group['data']['conversation_id']

      r = MixinBot.api.mute_conversation(cid, duration: 3600)
      assert_equal 3600, r['data']['duration']

      r = MixinBot.api.unmute_conversation(cid)
      assert_equal 0, r['data']['duration']
    end

    def test_set_conversation_disappear_duration
      group = MixinBot.api.create_group_conversation(
        user_ids: [TEST_UID, TEST_UID_2],
        name: 'Disappear Test Group'
      )
      cid = group['data']['conversation_id']

      r = MixinBot.api.set_conversation_disappear_duration(cid, duration: 86_400)
      assert_equal 86_400, r['data']['duration']
    end

    def test_update_conversation
      group = MixinBot.api.create_group_conversation(
        user_ids: [TEST_UID, TEST_UID_2],
        name: 'Update Test Group'
      )
      cid = group['data']['conversation_id']

      r = MixinBot.api.update_conversation(conversation_id: cid, name: 'Renamed', announcement: 'Hello')
      assert_equal 'Renamed', r['data']['name']
      assert_equal 'Hello', r['data']['announcement']
    end
  end
end
