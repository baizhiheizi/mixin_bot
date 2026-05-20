# frozen_string_literal: true

require 'yaml'

module MixinBot
  # Monitoring helpers (parity with Go monitor package).
  module Monitor
    class AppMessage
      attr_accessor :project, :status, :data

      def initialize(project: nil, status: 0, data: [])
        @project = project
        @status = status
        @data = data
      end

      def self.load(yaml_str)
        h = YAML.safe_load(yaml_str, permitted_classes: [Symbol], aliases: true)
        new(
          project: h['project'],
          status: h['status'] || 0,
          data: Array(h['data'])
        )
      end

      def marshal
        YAML.dump(
          'project' => project,
          'status' => status,
          'data' => data
        )
      end
    end

    class << self
      def unmarshal_app_message(bytes)
        AppMessage.load(bytes)
      end

      def report_to_monitor(api, asset:, amount:, receivers:, threshold:, message:, trace: nil, **transfer_opts)
        memo = message.is_a?(AppMessage) ? message.marshal : message.to_s
        mix = MixinBot::MixAddress.from_members(members: receivers, threshold:)
        trace ||= MixinBot.utils.unique_object_id(mix.address, asset, amount, api.config.app_id, memo,
                                                  (Time.now.to_i / 60).to_s)
        existing = begin
          api.safe_transaction(trace)
        rescue StandardError
          nil
        end
        return existing if existing.present? && existing['data'].present?

        api.create_safe_transfer(
          members: receivers,
          threshold:,
          asset_id: asset,
          amount:,
          trace_id: trace,
          memo:,
          **transfer_opts
        )
      end

      def check_retryable_error(error)
        return false if error.nil?

        reason = error.message.to_s.downcase
        return true if reason.include?('timeout')
        return true if reason.include?('internal server')
        return true if reason.include?('insufficient')
        return true if reason.include?('inputs locked by')
        return true if reason.include?('by other transaction')

        false
      end
    end
  end
end
