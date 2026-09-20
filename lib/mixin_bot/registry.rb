# frozen_string_literal: true

module MixinBot
  ##
  # Named registry for running several bots (keystores) inside one process.
  #
  # The default bot stays on the global configuration (+MixinBot.configure+ /
  # +MixinBot.api+). Additional bots register under a name and return a
  # dedicated +MixinBot::API+ whose configuration is frozen after registration:
  #
  #   MixinBot.register_bot :shop,
  #                        app_id: '...',
  #                        session_id: '...',
  #                        session_private_key: '...',
  #                        server_public_key: '...'
  #
  #   MixinBot.bot(:shop).me
  #
  # Integration components built on top of the SDK (router, poller, transfers,
  # notifications) accept the bot name and default to the global API client.
  module Registry
    ##
    # Registers a bot under +name+ with {MixinBot::API#initialize} kwargs and
    # freezes the resulting client's configuration.
    #
    # @param name [Symbol, String] registry key
    # @param kwargs [Hash] bot credentials (see {Configuration#initialize});
    #   empty kwargs would alias the global configuration and are rejected
    # @return [MixinBot::API] the registered client
    # @raise [MixinBot::ArgumentError] when the name is already registered or
    #   no credentials are given
    #
    def register_bot(name, **kwargs)
      raise MixinBot::ArgumentError, 'register_bot requires bot credentials' if kwargs.empty?
      raise MixinBot::ArgumentError, "bot #{name.inspect} is already registered" if bots.key?(name.to_sym)

      api = MixinBot::API.new(**kwargs)
      api.config.freeze
      bots[name.to_sym] = api
    end

    ##
    # Returns the API client registered under +name+.
    #
    #   MixinBot.bot(:shop).assets
    #
    # @param name [Symbol, String] registry key
    # @return [MixinBot::API]
    # @raise [KeyError] when nothing is registered under that name
    #
    def bot(name)
      bots.fetch(name.to_sym)
    end

    ##
    # Finds a bot client by its app id: the default API when the app id is
    # the global configuration's, else the registered bot carrying it.
    #
    # @param app_id [String, nil]
    # @return [MixinBot::API, nil] nil when no bot carries that app id
    #
    def bot_by_app_id(app_id)
      return nil if app_id.nil?
      return api if config.app_id == app_id

      bots.each_value.find { |client| client.config.app_id == app_id }
    end

    ##
    # Returns the registry contents (bot name => API client). The hash is
    # exposed for introspection; mutate it only between registrations.
    #
    # @return [Hash{Symbol => MixinBot::API}]
    #
    def bots
      @bots ||= {}
    end
  end
end
