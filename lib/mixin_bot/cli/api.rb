# frozen_string_literal: true

module MixinBot
  class CLI
    desc 'api PATH', 'Signed GET/POST request to a Mixin API path'
    long_desc <<-LONGDESC
      Use `mixinbot api PATH` to call any Mixin REST endpoint via MixinBot::Client.

      Get user information:

      $ mixinbot api /me -k ~/.mixinbot/keystore.json

      Search user:

      $ mixinbot api /search/1051445 -k ~/.mixinbot/keystore.json

      POST with JSON body:

      $ mixinbot api /payments -k keystore.json -m POST -d '{"asset_id":"..."}'
    LONGDESC
    option :keystore, type: :string, aliases: '-k', required: true, desc: 'keystore or keystore.json file path'
    option :method, type: :string, aliases: '-m', default: 'GET', desc: 'HTTP method: GET or POST'
    option :params, type: :hash, aliases: '-p', desc: 'HTTP GET query parameters'
    option :data, type: :string, aliases: '-d', default: '{}', desc: 'HTTP POST JSON body (object or array)'
    option :accesstoken, type: :string, aliases: '-t', desc: 'Override JWT access token'
    option :data_only, type: :boolean, default: true, desc: 'Print only response data (default: true)'
    def api(path)
      setup_api_instance!
      verb = options[:method].to_s.upcase
      unless %w[GET POST].include?(verb)
        abort_with_error("unsupported HTTP method #{verb} (use GET or POST)")
      end

      path_with_query = path
      path_with_query = "#{path}?#{URI.encode_www_form(options[:params])}" if options[:params].present?

      payload = parse_api_body(options[:data])
      res = nil

      res = with_spinner("#{verb} #{path_with_query}") do
        case verb
        when 'GET'
          api_instance.client.get(
            path_with_query,
            access_token: options[:accesstoken]
          )
        when 'POST'
          post_via_client(path, payload, access_token: options[:accesstoken])
        end
      end

      print_result(res, data_only: options[:data_only])
    end

    desc 'authcode', 'OAuth authorization code for another Mixin account'
    option :keystore, type: :string, aliases: '-k', required: true, desc: 'keystore or keystore.json file path'
    option :app_id, type: :string, required: true, aliases: '-c', desc: 'client_id of the app to authorize'
    option :scope, type: :array, default: ['PROFILE:READ'], aliases: '-s', desc: 'OAuth scopes'
    def authcode
      setup_api_instance!
      res = nil
      res = with_spinner('POST /oauth/authorize') do
        api_instance.authorize_code(
          user_id: options[:app_id],
          scope: options[:scope],
          pin: keystore['pin']
        )
      end
      print_result(res, data_only: true)
    end

    desc 'updatetip PIN', 'Update TIP PIN'
    option :keystore, type: :string, aliases: '-k', required: true, desc: 'keystore or keystore.json file path'
    def updatetip(pin)
      setup_api_instance!
      profile = api_instance.me
      log UI.fmt "{{v}} #{profile['full_name']}, TIP counter: #{profile['tip_counter']}"

      counter = profile['tip_counter']
      key = api_instance.prepare_tip_key counter
      log UI.fmt "{{v}} Generated key: #{key[:private_key]}"

      res = api_instance.update_tip_pin(pin.to_s, key[:public_key])

      log({
            pin: key[:private_key],
            tip_key_base64: res['tip_key_base64']
          })
    rescue StandardError => e
      abort_with_error(e.message)
    end

    desc 'verifypin PIN', 'Verify PIN'
    option :keystore, type: :string, aliases: '-k', required: true, desc: 'keystore or keystore.json file path'
    def verifypin(pin)
      setup_api_instance!
      res = api_instance.verify_pin pin.to_s
      print_result(res)
    rescue StandardError => e
      abort_with_error(e.message)
    end

    desc 'transfer USER_ID', 'Safe transfer to USER_ID'
    option :asset, type: :string, required: true, desc: 'Asset ID'
    option :amount, type: :string, required: true, desc: 'Amount'
    option :memo, type: :string, required: false, desc: 'Memo'
    option :trace, type: :string, required: false, desc: 'Trace ID'
    option :spend_key, type: :string, required: false, desc: 'Spend private key (hex); defaults to keystore spend_key'
    option :keystore, type: :string, aliases: '-k', required: true, desc: 'keystore or keystore.json file path'
    def transfer(user_id)
      setup_api_instance!
      perform_safe_transfer(user_id)
    end

    desc 'legacy-transfer USER_ID', 'Legacy POST /transfers (deprecated)'
    option :asset, type: :string, required: true, desc: 'Asset ID'
    option :amount, type: :numeric, required: true, desc: 'Amount'
    option :memo, type: :string, required: false, desc: 'Memo'
    option :keystore, type: :string, aliases: '-k', required: true, desc: 'keystore or keystore.json file path'
    def legacy_transfer(user_id)
      setup_api_instance!
      warn_deprecated('legacy-transfer uses deprecated POST /transfers; use `transfer` (Safe API) instead')
      res = nil
      res = with_spinner("Legacy transfer #{options[:amount]} #{options[:asset]} to #{user_id}") do
        api_instance.create_transfer(
          keystore['pin'],
          asset_id: options[:asset],
          opponent_id: user_id,
          amount: options[:amount],
          memo: options[:memo]
        )
      end

      snapshot_id = res['snapshot_id'] if res.respond_to?(:[])
      if snapshot_id.present?
        log UI.fmt "{{v}} Finished: https://mixin.one/snapshots/#{snapshot_id}"
      else
        print_result(res)
      end
    end

    desc 'safetransfer USER_ID', 'Alias for transfer (deprecated name)'
    option :asset, type: :string, required: true, desc: 'Asset ID'
    option :amount, type: :string, required: true, desc: 'Amount'
    option :trace, type: :string, required: false, desc: 'Trace ID'
    option :memo, type: :string, required: false, desc: 'Memo'
    option :spend_key, type: :string, required: false, desc: 'Spend private key (hex)'
    option :keystore, type: :string, aliases: '-k', required: true, desc: 'keystore or keystore.json file path'
    def safetransfer(user_id)
      warn_deprecated('safetransfer is deprecated; use `transfer` instead')
      transfer(user_id)
    end

    desc 'saferegister', 'Register on SAFE network'
    option :spend_key, type: :string, required: true, desc: 'Spend private key'
    option :keystore, type: :string, aliases: '-k', required: true, desc: 'keystore or keystore.json file path'
    def saferegister
      setup_api_instance!
      res = api_instance.safe_register options[:spend_key]
      print_result(res)
    end

    desc 'pay', 'Generate Safe payment URL'
    option :members, type: :array, required: true, desc: 'Receivers (supports multisig)'
    option :threshold, type: :numeric, required: false, default: 1, desc: 'Multisig threshold'
    option :asset, type: :string, required: true, desc: 'Asset ID'
    option :amount, type: :string, required: true, desc: 'Amount'
    option :trace, type: :string, required: false, desc: 'Trace ID'
    option :memo, type: :string, required: false, desc: 'Memo'
    def pay
      setup_api_instance!
      url = api_instance.safe_pay_url(
        members: options[:members],
        threshold: options[:threshold],
        asset_id: options[:asset],
        amount: options[:amount],
        trace_id: options[:trace],
        memo: options[:memo]
      )

      log UI.fmt "{{v}} #{url}"
    end

    private

    def with_spinner(title)
      if spinner_enabled?
        CLI::UI::Spinner.spin(title) { |_spinner| yield }
      else
        yield
      end
    end

    def spinner_enabled?
      ENV['MIXINBOT_NO_SPINNER'].to_s != '1' && $stdout.tty?
    end

    def parse_api_body(json_string)
      return nil if json_string.blank? || json_string == '{}'

      JSON.parse(json_string)
    rescue JSON::ParserError => e
      abort_with_error("invalid JSON body: #{e.message}")
    end

    def post_via_client(path, payload, access_token: nil)
      client = api_instance.client
      token_opt = { access_token: access_token.presence }.compact

      if payload.is_a?(Array)
        client.fetch_post_array(path, payload, **token_opt)
      elsif payload.is_a?(Hash)
        client.fetch_post(path, body: payload, **token_opt)
      elsif payload.nil?
        client.post(path, **token_opt)
      else
        abort_with_error('POST body must be a JSON object or array')
      end
    end

    def perform_safe_transfer(user_id)
      transfer_opts = {
        members: [user_id],
        threshold: 1,
        asset_id: options[:asset],
        amount: options[:amount].to_s,
        memo: options[:memo] || ''
      }
      transfer_opts[:trace_id] = options[:trace] if options[:trace].present?
      spend = options[:spend_key] || keystore&.dig('spend_key')
      transfer_opts[:spend_key] = spend if spend.present?

      res = with_spinner(
        "Safe transfer #{transfer_opts[:amount]} #{transfer_opts[:asset_id]} to #{user_id}"
      ) do
        api_instance.create_safe_transfer(**transfer_opts)
      end

      data = res['data'] if res.respond_to?(:[])
      tx_hash = data.is_a?(Array) ? data.first&.dig('transaction_hash') : nil
      snapshot_id = res['snapshot_id'] if res.respond_to?(:[])

      if tx_hash.present?
        log UI.fmt "{{v}} Submitted: transaction_hash=#{tx_hash}"
      elsif snapshot_id.present?
        log UI.fmt "{{v}} Finished: https://mixin.one/snapshots/#{snapshot_id}"
      else
        print_result(res)
      end
    rescue StandardError => e
      abort_with_error(e.message)
    end
  end
end
