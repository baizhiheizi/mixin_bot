# frozen_string_literal: true

module MixinBot
  module Models
    ##
    # Wraps a raw Mixin API JSON object so callers can use both:
    # - +response['data']['user_id']+ (envelope shape)
    # - +response['user_id']+ (flattened shape, matching legacy +merge!+ behaviour)
    #
    class ApiEnvelope < SimpleDelegator
      def [](key)
        k = key.is_a?(Symbol) ? key.to_s : key
        inner = __getobj__
        return inner[k] if inner.key?(k)

        data = inner['data']
        return data[k] if data.is_a?(Hash) && data.key?(k)

        nil
      end

      def dig(*keys)
        return nil if keys.empty?

        k0 = keys[0]
        k0 = k0.to_s if k0.is_a?(Symbol)
        inner = __getobj__

        if inner.key?(k0)
          v = inner[k0]
          return v if keys.size == 1

          return v.dig(*keys[1..]) if v.respond_to?(:dig)
        end

        data = inner['data']
        return nil unless data.is_a?(Hash) && data.key?(k0)

        v = data[k0]
        return v if keys.size == 1

        v.respond_to?(:dig) ? v.dig(*keys[1..]) : nil
      end

      def key?(key)
        k = key.is_a?(Symbol) ? key.to_s : key
        inner = __getobj__
        inner.key?(k) || (inner['data'].is_a?(Hash) && inner['data'].key?(k))
      end

      alias include? key?
      alias has_key? key?

      def with_indifferent_access
        inner = __getobj__
        base = inner.dup
        d = base['data']
        merged = d.is_a?(Hash) ? base.merge(d) : base
        merged.with_indifferent_access
      end

      def to_h
        __getobj__
      end
    end
  end
end
