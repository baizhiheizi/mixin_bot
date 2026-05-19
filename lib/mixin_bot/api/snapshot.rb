# frozen_string_literal: true

module MixinBot
  class API
    module Snapshot
      def safe_snapshots(**options)
        path = '/safe/snapshots'
        params = {
          limit: options[:limit],
          offset: options[:offset],
          asset: options[:asset],
          opponent: options[:opponent],
          app: options[:app_id],
          order: options[:order]
        }

        client.get path, **params
      end

      def safe_snapshot(snapshot_id, access_token: nil)
        path = format('/safe/snapshots/%<snapshot_id>s', snapshot_id:)
        client.get path, access_token:
      end
      alias safe_snapshot_by_id safe_snapshot

      def create_safe_snapshot_notification(**kwargs)
        path = '/safe/snapshots/notifications'

        payload = {
          transaction_hash: kwargs[:transaction_hash],
          output_index: kwargs[:output_index],
          receiver_id: kwargs[:receiver_id]
        }

        client.post path, **payload, access_token: kwargs[:access_token]
      end
    end
  end
end
