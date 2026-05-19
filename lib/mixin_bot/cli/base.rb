# frozen_string_literal: true

module MixinBot
  ##
  # Registry and predicates for mixinbot `call` / `list` commands.
  #
  module CLIHelpers
    API_EXCLUDED_METHODS = %i[
      initialize
      client
      config
      utils
      client_id
      access_token
      sign_authentication_token
      sign_authentication_token_without_body
      sign_authentication_token_with_request_id
      encode_raw_transaction
      decode_raw_transaction
      generate_trace_from_hash
      encode_raw_transaction_native
      decode_raw_transaction_native
      warn_legacy_mixin_api!
      ensure_mixin_command_exist
      command?
    ].freeze

    INTERACTIVE_API_METHODS = %i[
      start_blaze_connect
      blaze
      upload_attachment
    ].freeze

    module_function

    def api_callable_methods
      methods = MixinBot::API.instance_methods(false)
      MixinBot::API.included_modules.each do |mod|
        next unless mod.name&.start_with?('MixinBot::API::')

        methods.concat(mod.instance_methods(false))
      end

      methods
        .map(&:to_sym)
        .uniq
        .select { |m| api_method_callable?(m) }
        .sort
    end

    def api_method_callable?(method_name)
      sym = method_name.to_sym
      return false if API_EXCLUDED_METHODS.include?(sym)
      return false if INTERACTIVE_API_METHODS.include?(sym)

      MixinBot::API.instance_methods.include?(sym) &&
        !sym.to_s.start_with?('_')
    end

    def utils_callable_methods
      MixinBot::Utils.singleton_methods(false).sort
    end

    def api_method_owner(method_name)
      sym = method_name.to_sym
      return 'MixinBot::API' if MixinBot::API.instance_methods(false).include?(sym)

      MixinBot::API.included_modules.find do |mod|
        mod.name&.start_with?('MixinBot::API::') && mod.instance_methods(false).include?(sym)
      end&.name || 'MixinBot::API'
    end

    def grouped_api_methods
      api_callable_methods.group_by { |m| api_method_owner(m) }.sort_by { |k, _| k }
    end
  end
end
