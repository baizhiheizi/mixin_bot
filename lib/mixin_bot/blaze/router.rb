# frozen_string_literal: true

require 'json'

module MixinBot
  module Blaze
    # Routes decoded Blaze envelopes to handler classes — the dispatch layer
    # above {MixinBot::Blaze::Reactor}'s raw `blaze_handler` lambda contract.
    #
    # A router IS a handler: it answers #call with the decoded envelope Hash,
    # so it plugs straight into the configured Blaze handler:
    #
    #   router = MixinBot::Blaze::Router.new do
    #     on 'text', EchoHandler
    #     on 'transfer', DepositHandler
    #     on category: 'APP_CARD', handler: AppCardHandler
    #     on action: 'CREATE_MESSAGE', handler: ->(message) { ... }
    #   end
    #
    #   MixinBot.configure do
    #     self.blaze_handler = router
    #   end
    #
    # or per bot: MixinBot::Blaze::Router.new(api: MixinBot.bot(:shop)) { ... }
    #
    # Matching is first-registered-wins on the message category (aliases like
    # 'text' normalize to PLAIN_TEXT; raw categories pass through verbatim) or
    # on a Hash of conditions ({action:, category:}) that must all hold.
    # Unmatched envelopes are logged and ignored.
    #
    # Handler exceptions are logged (:handler_error) and re-raised: the
    # reactor owns containment (it logs and keeps the loop alive) and, under
    # `ack_policy: :after_handler`, withholds the acknowledgement so a failed
    # message is redelivered on reconnect. Swallowing here would turn that
    # policy into at-most-once.
    #
    # Handlers are one of:
    # - a Class with #initialize(message) + #call (see {Router::Base});
    #   instantiated per message, so handlers stay stateless;
    # - any object responding to #call(message) (proc, method, instance).
    #
    class Router
      ##
      # Decoded view of a Blaze envelope. Wraps the raw envelope Hash and the
      # bot API client that dispatched it, exposing decoded message data and
      # a reply helper over the HTTP message API (no WebSocket access).
      #
      class Message
        # Categories whose data_base64 payload is JSON (everything but
        # PLAIN_TEXT/PLAIN_POST, whose payloads are plain strings).
        JSON_CATEGORIES = %w[
          PLAIN_CONTACT
          PLAIN_STICKER
          PLAIN_LIVE
          PLAIN_LOCATION
          PLAIN_IMAGE
          PLAIN_DATA
          PLAIN_AUDIO
          PLAIN_VIDEO
          APP_CARD
          APP_BUTTON_GROUP
          SYSTEM_ACCOUNT_SNAPSHOT
          MESSAGE_RECALL
        ].freeze

        attr_reader :raw

        def initialize(raw, api:)
          @raw = raw.is_a?(Hash) ? raw : {}
          @api = api
        end

        def action
          @raw['action']
        end

        # The envelope's message params Hash (empty when absent).
        def params
          data = @raw['data']
          data.is_a?(Hash) ? data : {}
        end

        def category
          params['category']
        end

        def conversation_id
          params['conversation_id']
        end

        def recipient_id
          params['recipient_id']
        end

        def representative_id
          params['representative_id']
        end

        def message_id
          params['message_id']
        end

        # The message's sender (inbound messages carry the sender in user_id).
        def user_id
          params['user_id']
        end

        def quote_message_id
          params['quote_message_id']
        end

        ##
        # The decoded message payload: the base64-decoded string for text-like
        # categories, parsed JSON for structured ones. Decoded lazily, once.
        #
        def data
          return @data if defined?(@data)

          decoded = Base64.decode64(params['data_base64'].to_s)
          @data = JSON_CATEGORIES.include?(category) ? parse_json(decoded) : decoded
        end

        ##
        # Sends content back to the message's sender in its conversation over
        # the HTTP message API. Supports PLAIN_TEXT (default) and PLAIN_POST;
        # for anything richer, build params via the bound API (exposed by
        # {Blaze::API helpers} on the api client) and send directly.
        #
        # @param content [String] text or post content
        # @param category [String] 'PLAIN_TEXT' or 'PLAIN_POST'
        #
        def reply(content, category: 'PLAIN_TEXT')
          options = { conversation_id:, recipient_id: user_id, data: content }
          payload =
            case category
            when 'PLAIN_TEXT' then @api.plain_text(options)
            when 'PLAIN_POST' then @api.plain_post(options)
            else raise MixinBot::ArgumentError, "unsupported reply category #{category.inspect}"
            end

          @api.send_message(payload)
        end

        private

        def parse_json(str)
          JSON.parse(str)
        rescue JSON::ParserError, EncodingError
          str
        end
      end

      ##
      # Base class for message handlers: subclass, implement #handle, use
      # #reply / #message. Instantiated per message by the router.
      #
      class Base
        attr_reader :message

        def initialize(message)
          @message = message
        end

        def call
          handle
        end

        def handle
          raise NotImplementedError, "#{self.class} must implement #handle"
        end

        def reply(content, category: 'PLAIN_TEXT')
          message.reply(content, category:)
        end
      end

      # A compiled matcher paired with its handler.
      Route = Struct.new(:matcher, :handler) do
        def matches?(message)
          matcher.call(message)
        end
      end

      # Short aliases accepted by #on (in addition to raw categories, which
      # pass through verbatim when they start with PLAIN_/SYSTEM_/APP_/
      # MESSAGE_).
      CATEGORY_ALIASES = {
        'text' => 'PLAIN_TEXT',
        'post' => 'PLAIN_POST',
        'image' => 'PLAIN_IMAGE',
        'data' => 'PLAIN_DATA',
        'file' => 'PLAIN_DATA',
        'sticker' => 'PLAIN_STICKER',
        'contact' => 'PLAIN_CONTACT',
        'audio' => 'PLAIN_AUDIO',
        'video' => 'PLAIN_VIDEO',
        'live' => 'PLAIN_LIVE',
        'location' => 'PLAIN_LOCATION',
        'transfer' => 'SYSTEM_ACCOUNT_SNAPSHOT',
        'snapshot' => 'SYSTEM_ACCOUNT_SNAPSHOT',
        'app_card' => 'APP_CARD',
        'app_button_group' => 'APP_BUTTON_GROUP',
        'buttons' => 'APP_BUTTON_GROUP',
        'recall' => 'MESSAGE_RECALL'
      }.freeze

      attr_reader :api, :routes

      ##
      # @param api [MixinBot::API] bot client bound to this router; replies and
      #   handler-side API calls use its credentials
      # @param logger [#call, nil] called with (level, detail); defaults to
      #   $stderr (same shape as MixinBot::Blaze::Reactor's logger)
      # @yield the routing DSL (see #on)
      #
      def initialize(api: MixinBot.api, logger: nil, &)
        @api = api
        @routes = []
        @logger = logger || ->(level, detail) { warn "[mixin_blaze] #{level}: #{detail}" }
        instance_exec(&) if block_given?
      end

      ##
      # Registers a route. Matchers:
      # - a category alias or raw category string/symbol ('text', 'app_card',
      #   'PLAIN_TEXT', ...);
      # - a Hash of conditions, e.g. {action: 'CREATE_MESSAGE'} or
      #   {category: 'text'} — all conditions must hold.
      #
      # The handler is a Class (instantiated per message) or anything
      # responding to #call(message). Routes match in registration order;
      # the first match wins.
      #
      # @return [self] (chainable)
      #
      def on(matcher, handler = nil, &block)
        if matcher.is_a?(Hash) && matcher.key?(:handler)
          raise MixinBot::ArgumentError, 'handler given twice (positional and :handler key)' if handler || block

          handler = matcher[:handler]
          matcher = matcher.except(:handler)
        end
        handler ||= block
        raise MixinBot::ArgumentError, 'a handler class or callable is required' unless handler
        unless handler.is_a?(Class) || handler.respond_to?(:call)
          raise MixinBot::ArgumentError, "handler #{handler.inspect} must be a class or respond to #call"
        end

        @routes << Route.new(compile_matcher(matcher), handler)
        self
      end

      ##
      # Dispatches one decoded envelope Hash (the reactor's handler contract).
      # Unmatched envelopes are logged and ignored; handler exceptions are
      # logged and re-raised so the reactor's ack policy and containment
      # govern retry/redelivery.
      #
      # @param raw [Hash] decoded envelope with 'action' and 'data' keys
      # @raise [StandardError] when the matched handler raises
      #
      def call(raw)
        message = Message.new(raw, api: @api)
        route = @routes.find { |candidate| candidate.matches?(message) }

        if route.nil?
          @logger.call(:unmatched, "action=#{message.action.inspect} category=#{message.category.inspect}")
          return
        end

        dispatch(route.handler, message)
      end

      # Normalizes a category alias or raw category to its canonical form.
      #
      # @return [String]
      # @raise [MixinBot::ArgumentError] for unknown categories
      #
      def self.normalize_category(value)
        key = value.to_s.downcase
        return CATEGORY_ALIASES[key] if CATEGORY_ALIASES.key?(key)

        upcased = value.to_s.upcase
        return upcased if upcased.start_with?('PLAIN_', 'SYSTEM_', 'APP_', 'MESSAGE_')

        raise MixinBot::ArgumentError, "unknown message category #{value.inspect}"
      end

      private

      def dispatch(handler, message)
        if handler.is_a?(Class)
          handler.new(message).call
        elsif handler.respond_to?(:call)
          handler.call(message)
        else
          raise MixinBot::ArgumentError, "handler #{handler.inspect} must be a class or respond to #call"
        end
      rescue StandardError => e
        @logger.call(:handler_error, e)
        raise
      end

      def compile_matcher(matcher)
        case matcher
        when Hash
          conditions = matcher.map { |key, value| compile_condition(key, value) }
          ->(message) { conditions.all? { |condition| condition.call(message) } }
        when String, Symbol
          category = self.class.normalize_category(matcher)
          ->(message) { message.category == category }
        else
          raise MixinBot::ArgumentError,
                "matcher must be a category alias or a conditions Hash, got #{matcher.inspect}"
        end
      end

      def compile_condition(key, value)
        case key.to_sym
        when :category
          category = self.class.normalize_category(value)
          ->(message) { message.category == category }
        when :action
          action = value.to_s
          ->(message) { message.action == action }
        else
          raise MixinBot::ArgumentError,
                "unknown route condition #{key.inspect} (supported: :category, :action)"
        end
      end
    end
  end
end
