# frozen_string_literal: true

module MixinBot
  class API
    ##
    # Shared helpers for legacy 6-digit PIN vs TIP (+pin_base64+) payloads.
    #
    module PinPayload
      private

      ##
      # @return [Hash] either +{ pin: ... }+ or +{ pin_base64: ... }+
      #
      def tip_or_legacy_pin_payload(pin, tip_action, *tip_params)
        p = pin
        raise ArgumentError, 'pin is required' if p.blank?

        if p.to_s.length > 6
          { pin_base64: encrypt_tip_pin(p, tip_action, *tip_params) }
        else
          { pin: encrypt_pin(p) }
        end
      end
    end
  end
end
