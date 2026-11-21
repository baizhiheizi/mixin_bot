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

    def test_upload_attachment_passes_configured_proxy_to_faraday
      previous_proxy = MixinBot.config.proxy
      MixinBot.config.proxy = 'http://alice:secret@127.0.0.1:7890'

      captured_options = nil
      original_new = Faraday.method(:new)
      Faraday.define_singleton_method(:new) do |*args, **kwargs, &block|
        captured_options = kwargs if args.empty? && kwargs[:url] == 'https://offline-upload.test/put'
        original_new.call(*args, **kwargs, &block)
      end

      file = File.open File.expand_path('../../fixtures/Mixin.png', __dir__)
      r = MixinBot.api.upload_attachment(file)

      assert r['attachment_id']
      assert_equal(
        { uri: URI.parse('http://127.0.0.1:7890').normalize, user: 'alice', password: 'secret' },
        captured_options[:proxy]
      )
    ensure
      Faraday.define_singleton_method(:new, original_new) if original_new
      MixinBot.config.proxy = previous_proxy
    end
  end
end
