# frozen_string_literal: true

module MixinBot
  module Models
    ##
    # Typed view of a Mixin +User+ payload (+/me+, +/users/:id+, etc.).
    #
    class User < ApiEnvelope
    end
  end
end
