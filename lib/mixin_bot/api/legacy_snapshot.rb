# frozen_string_literal: true

module MixinBot
  class API
    module LegacySnapshot
      def network_snapshots(**kwargs)
        warn_legacy_mixin_api!('LegacySnapshot#network_snapshots')
        path = '/network/snapshots'
        params = {
          limit: kwargs[:limit],
          offset: kwargs[:offset],
          asset: kwargs[:asset],
          order: kwargs[:order]
        }

        client.get path, **params, access_token: kwargs[:access_token]
      end

      def snapshots(**kwargs)
        warn_legacy_mixin_api!('LegacySnapshot#snapshots')
        path = '/snapshots'

        params = {
          limit: kwargs[:limit],
          offset: kwargs[:offset],
          asset: kwargs[:asset],
          opponent: kwargs[:opponent],
          order: kwargs[:order]
        }

        client.get path, **params, access_token: kwargs[:access_token]
      end

      def network_snapshot(snapshot_id, **kwargs)
        warn_legacy_mixin_api!('LegacySnapshot#network_snapshot')
        path = format('/network/snapshots/%<snapshot_id>s', snapshot_id:)

        client.get path, access_token: kwargs[:access_token]
      end

      def snapshot(snapshot_id, access_token: nil)
        warn_legacy_mixin_api!('LegacySnapshot#snapshot')
        path = format('/snapshots/%<snapshot_id>s', snapshot_id:)
        client.get path, access_token:
      end
      alias snapshot_by_id snapshot

      def snapshot_by_trace_id(trace_id, access_token: nil)
        warn_legacy_mixin_api!('LegacySnapshot#snapshot_by_trace_id')
        path = format('/snapshots/trace/%<trace_id>s', trace_id:)
        client.get path, access_token:
      end
    end
  end
end
