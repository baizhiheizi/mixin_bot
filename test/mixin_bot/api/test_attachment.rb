# frozen_string_literal: true

require 'test_helper'

module MixinBot
  class TestAttachment < Minitest::Test
    def setup
    end

    def test_create_attachment
      r = MixinBot.api.create_attachment
      assert r['data']['type'] == 'attachment'
    end

    def test_upload_attachment
      file = File.open File.expand_path('../../fixtures/Mixin.png', __dir__)
      r = MixinBot.api.upload_attachment(file)
      assert r['attachment_id']
      assert r['view_url']
    end

    def test_attachment
      attachment = MixinBot.api.create_attachment
      attachment_id = attachment['data']['attachment_id']
      r = MixinBot.api.attachment(attachment_id)
      assert r['data']['attachment_id'] == attachment_id
    end
  end
end
