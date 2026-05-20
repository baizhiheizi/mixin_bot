# frozen_string_literal: true

require 'uri'

module MixinBot
  # Deep link URL schemes (parity with Go url_scheme.go).
  module UrlScheme
    SCHEME = 'mixin'

    module_function

    def scheme_users(user_id)
      URI("#{SCHEME}://users/#{user_id}").to_s
    end

    def scheme_transfer(user_id)
      URI("#{SCHEME}://transfer/#{user_id}").to_s
    end

    def scheme_pay(asset_id:, trace_id:, recipient_id:, memo:, amount:)
      q = URI.encode_www_form(
        asset: asset_id,
        trace: trace_id,
        amount: amount.to_s,
        recipient: recipient_id,
        memo: memo.to_s
      )
      "#{SCHEME}://pay?#{q}"
    end

    def scheme_codes(code_id)
      URI("#{SCHEME}://codes/#{code_id}").to_s
    end

    def scheme_snapshots(snapshot_id: nil, trace_id: nil)
      u = URI("#{SCHEME}://snapshots")
      u.path = "/#{snapshot_id}" if snapshot_id.present?
      u.query = URI.encode_www_form(trace: trace_id) if trace_id.present?
      u.to_s
    end

    def scheme_conversations(conversation_id: nil, user_id: nil)
      u = URI("#{SCHEME}://conversations")
      u.path = "/#{conversation_id}" if conversation_id.present?
      u.query = URI.encode_www_form(user: user_id) if user_id.present?
      u.to_s
    end

    def scheme_apps(app_id:, action: nil, params: {})
      u = URI("#{SCHEME}://apps/#{app_id}")
      q = { action: action.presence || 'open' }.merge(params || {})
      u.query = URI.encode_www_form(q)
      u.to_s
    end

    def scheme_send(category:, data: nil, conversation_id: nil)
      q = { category: category.to_s }
      q[:data] = URI.encode_www_form_component(Base64.strict_encode64(data)) if data.present?
      q[:conversation] = conversation_id if conversation_id.present?
      "#{SCHEME}://send?#{URI.encode_www_form(q)}"
    end
  end
end
