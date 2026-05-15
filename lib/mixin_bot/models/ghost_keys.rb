# frozen_string_literal: true

module MixinBot
  module Models
    ##
    # Ghost key material returned by +/safe/keys+.
    #
    class GhostKeys < ApiEnvelope
    end

    class GhostKeyRequest < ApiEnvelope
    end
  end
end
