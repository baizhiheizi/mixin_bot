# frozen_string_literal: true

require 'active_support/concern'

module MixinBot
  module Outputs
    ##
    # ActiveRecord concern for the generated +MixinPollerCursor+ model
    # (mixin_bot:outputs generator): one row per bot app id, remembering the
    # last absorbed output position (the outputs API's own created_at value).
    #
    #   class MixinPollerCursor < ApplicationRecord
    #     include MixinBot::Outputs::CursorModel
    #   end
    #
    # Required columns: bot_app_id (unique), value.
    #
    module CursorModel
      extend ActiveSupport::Concern

      class_methods do
        def value(bot_app_id:)
          find_by(bot_app_id:)&.value
        end

        def advance!(bot_app_id:, value:)
          record = find_or_initialize_by(bot_app_id:)
          record.update!(value:)
        end
      end
    end
  end
end
