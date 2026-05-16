# frozen_string_literal: true

require 'test_helper'
require 'fastimage'

module MixinBot
  class TestMessage < Minitest::Test
    def setup
      @conversation_id = MixinBot.api.unique_uuid(TEST_UID)
    end

    def test_write_ws_message
      params = MixinBot.api.plain_text(conversation_id: @conversation_id, data: 'test from MixinBot')
      msg = MixinBot.api.write_ws_message(params:)

      refute_nil msg
    end

    def test_send_text_message
      message_id = SecureRandom.uuid
      res = MixinBot.api.send_text_message(
        message_id:,
        conversation_id: @conversation_id,
        data: 'test from MixinBot'
      )

      assert_equal res['message_id'], message_id
    end

    def test_send_post_message
      message_id = SecureRandom.uuid
      res = MixinBot.api.send_post_message(
        conversation_id: @conversation_id,
        message_id:,
        data: <<~POST
          # H1
          ## H2
          ### H3

          Hello World in text.

          ![hello world in image](https://developers.mixin.one/assets/f13631293a7e272401e5d500eb1e4d9c.png)

          [hello world in link](https://ohmy.xin)

          ```ts
          console.log('hello world in ts')
          ```

          ```ruby
          puts 'hello world in Ruby'
          ```

          ```mermaid
          A[module A] --> |call| B{module B}
          B --> |failed| C(throw error)
          B --> |success| D(return)
          ```
        POST
      )

      assert_equal res['message_id'], message_id
    end

    def test_quote_message
      quote_message_id = SecureRandom.uuid
      message_id = SecureRandom.uuid

      MixinBot.api.send_text_message(
        message_id: quote_message_id,
        conversation_id: @conversation_id,
        data: 'test from MixinBot'
      )

      quoted_res =
        MixinBot.api.send_text_message(
          conversation_id: @conversation_id,
          data: 'quote the last message',
          message_id:,
          quote_message_id:
        )

      assert_equal quoted_res['message_id'], message_id
    end

    def test_send_contact_message
      message_id = SecureRandom.uuid
      res = MixinBot.api.send_contact_message(
        conversation_id: @conversation_id,
        message_id:,
        data: {
          user_id: TEST_UID
        }
      )

      assert_equal res['message_id'], message_id
    end

    def test_send_app_card_message
      message_id = SecureRandom.uuid

      res = MixinBot.api.send_app_card_message(
        conversation_id: @conversation_id,
        message_id:,
        data: {
          icon_url: 'https://mixin.one/assets/98b586edb270556d1972112bd7985e9e.png',
          title: 'Mixin',
          description: 'A free and lightning fast peer-to-peer transactional network for digital assets.',
          action: 'https://mixin.one'
        }
      )

      assert_equal res['message_id'], message_id
    end

    def test_send_button_group_message
      message_id = SecureRandom.uuid
      res = MixinBot.api.send_app_button_group_message(
        conversation_id: @conversation_id,
        message_id:,
        data: [
          {
            label: 'Mixin Website',
            color: '#ABABAB',
            action: 'https://mixin.one'
          },
          {
            label: 'Flowin Websit',
            color: '#1296db',
            action: 'https://flowin.xin'
          }
        ]
      )

      assert_equal res['message_id'], message_id
    end

    def test_send_messages
      messages = [
        MixinBot.api.plain_text(
          conversation_id: @conversation_id,
          recipient_id: TEST_UID,
          data: 'test from MixinBot (1/3)'
        ),
        MixinBot.api.plain_text(
          conversation_id: @conversation_id,
          recipient_id: TEST_UID,
          data: 'test from MixinBot (2/3)'
        ),
        MixinBot.api.plain_text(
          conversation_id: @conversation_id,
          recipient_id: TEST_UID,
          data: 'test from MixinBot (3/3)'
        )
      ]
      res = MixinBot.api.send_message(messages)

      assert_nil res['error']
    end

    def test_recall_message
      message_id = SecureRandom.uuid
      MixinBot.api.send_text_message(
        conversation_id: @conversation_id,
        data: 'test from MixinBot',
        message_id:
      )

      res = MixinBot.api.recall_message(message_id, recipient_id: TEST_UID, conversation_id: @conversation_id)

      assert_nil res['error']
    end

    def test_send_image_message
      file_path = File.expand_path('../../fixtures/Mixin.png', __dir__)

      sizes = FastImage.size file_path
      image_type = FastImage.type file_path

      image = File.open file_path
      attachment = MixinBot.api.upload_attachment(image)

      message_id = SecureRandom.uuid
      res = MixinBot.api.send_image_message(
        conversation_id: @conversation_id,
        message_id:,
        data: {
          attachment_id: attachment['attachment_id'],
          mime_type: "images/#{image_type}",
          size: image.size,
          width: sizes[0],
          height: sizes[1]
        }
      )

      assert_equal res['message_id'], message_id
    end

    def test_send_file_message
      file_path = File.expand_path('../../fixtures/Mixin.png', __dir__)

      file = File.open file_path
      attachment = MixinBot.api.upload_attachment(file)

      message_id = SecureRandom.uuid
      res = MixinBot.api.send_file_message(
        conversation_id: @conversation_id,
        message_id:,
        data: {
          attachment_id: attachment['attachment_id'],
          size: file.size,
          name: file.path.split('/').last
        }
      )

      assert_equal res['message_id'], message_id
    end
  end
end
