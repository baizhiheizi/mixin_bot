# frozen_string_literal: true

module MixinBot
  class API
    module LegacyOutput
      def read_multisigs(**kwargs)
        warn_legacy_mixin_api!('LegacyOutput#read_multisigs')
        legacy_outputs(**kwargs)
      end

      def legacy_outputs(**kwargs)
        warn_legacy_mixin_api!('LegacyOutput#legacy_outputs')
        limit = kwargs[:limit] || 100
        offset = kwargs[:offset] || ''
        state = kwargs[:state] || ''
        members_hash = MixinBot.utils.hash_members(kwargs[:members] || [])
        threshold = kwargs[:threshold] || ''
        access_token = kwargs[:access_token]

        path = '/multisigs/outputs'
        params = {
          limit:,
          offset:,
          state:,
          members: members_hash,
          threshold:
        }.compact_blank

        client.get path, **params, access_token:
      end
      alias multisigs legacy_outputs
      alias multisig_outputs legacy_outputs

      def create_output(receivers:, index:, hint: nil, access_token: nil)
        warn_legacy_mixin_api!('LegacyOutput#create_output')
        path = '/outputs'
        payload = {
          receivers:,
          index:,
          hint:
        }
        client.post path, **payload, access_token:
      end

      def build_output(receivers:, index:, amount:, threshold:, hint: nil)
        warn_legacy_mixin_api!('LegacyOutput#build_output')
        _output = create_output(receivers:, index:, hint:)
        {
          amount: format('%.8f', amount.to_d.to_r),
          script: build_threshold_script(threshold),
          mask: _output['mask'],
          keys: _output['keys']
        }
      end
    end
  end
end
