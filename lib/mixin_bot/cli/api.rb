# frozen_string_literal: true

module MixinBot
  class CLI < Thor
    desc 'api PATH', 'request PATH of Mixin API'
    long_desc <<-LONGDESC
      use `mixinbot api PATH` to request any Mixin API

      Get user infomation:

      $ mixinbot api /me -k ~/.mixinbot/keystore.json

      Search user infomation:

      $ mixinbot api /search/1051445 -k ~/.mixinbot/keystore.json

      Generate a multisig payment:

      $ mixinbot api /payments -k ~/.mixinbot/keystore.json -m POST -d '{"asset_id":"965e5c6e-434c-3fa9-b780-c50f43cd955c", "amount":"1", "trace_id": "37f16abb-0640-4d01-9423-a06121732d35", "memo":"test", "opponent_multisig":{"receivers":["0508a116-1239-4e28-b150-85a8e3e6b400", "7ed9292d-7c95-4333-aa48-a8c640064186", "a67c6e87-1c9e-4a1c-b81c-47a9f4f1bff1"], "threshold":2}}'
    LONGDESC
    option :keystore, type: :string, aliases: '-k', required: true, desc: 'keystore or keystore.json file path'
    option :method, type: :string, aliases: '-m', default: 'GET', desc: 'HTTP method, GET or POST'
    option :params, type: :hash, aliases: '-p', desc: 'HTTP GET params'
    option :data, type: :string, aliases: '-d', default: '{}', desc: 'HTTP POST data'
    option :accesstoken, type: :string, aliases: '-t', desc: 'Specify a accesstoken, or will generate by keystore'
    def api(path)
      path = "#{path}?#{URI.encode_www_form(options[:params])}" if options[:params].present?
      payload =
        begin
          JSON.parse options[:data]
        rescue JSON::ParserError => e
          log UI.fmt("{{x}} #{e.inspect}")
          {}
        end

      access_token = options[:accesstoken] || api_instance.access_token(options[:method].upcase, path,
                                                                        payload.blank? ? '' : payload.to_json)
      authorization = format('Bearer %<access_token>s', access_token:)
      res = {}

      CLI::UI::Spinner.spin("#{options[:method]} #{path}, payload: #{payload}") do |_spinner|
        res =
          case options[:method].downcase.to_sym
          when :post
            api_instance.client.post(path, headers: { Authorization: authorization }, json: payload)
          when :get
            api_instance.client.get(path, headers: { Authorization: authorization })
          end
      end

      log res['data']
    end

    desc 'authcode', 'code to authorize other mixin account'
    option :keystore, type: :string, aliases: '-k', required: true, desc: 'keystore or keystore.json file path'
    option :app_id, type: :string, required: true, aliases: '-c', desc: 'app_id of bot to authorize'
    option :scope, type: :array, default: ['PROFILE:READ'], aliases: '-s', desc: 'scope to authorize'
    def authcode
      res = {}
      CLI::UI::Spinner.spin('POST /oauth/authorize') do |_spinner|
        res =
          api_instance.authorize_code(
            user_id: options[:app_id],
            scope: options[:scope],
            pin: keystore['pin']
          )
      end
      log res['data']
    end

    desc 'updatetip PIN', 'update TIP pin'
    option :keystore, type: :string, aliases: '-k', required: true, desc: 'keystore or keystore.json file path'
    def updatetip(pin)
      profile = api_instance.me
      log UI.fmt "{{v}} #{profile['full_name']}, TIP counter: #{profile['tip_counter']}"

      counter = profile['tip_counter']
      key = api_instance.prepare_tip_key counter
      log UI.fmt "{{v}} Generated key: #{key[:private_key]}"

      res = api_instance.update_pin old_pin: pin.to_s, pin: key[:public_key]

      log({
            pin: key[:private_key],
            tip_key_base64: res['tip_key_base64']
          })
    rescue StandardError => e
      log UI.fmt "{{x}} #{e.inspect}"
    end

    desc 'verifypin PIN', 'verify pin'
    option :keystore, type: :string, aliases: '-k', required: true, desc: 'keystore or keystore.json file path'
    def verifypin(pin)
      res = api_instance.verify_pin pin.to_s

      log res
    rescue StandardError => e
      log UI.fmt "{{x}} #{e.inspect}"
    end

    desc 'transfer USER_ID', 'transfer asset to USER_ID'
    option :asset, type: :string, required: true, desc: 'Asset ID'
    option :amount, type: :numeric, required: true, desc: 'Amount'
    option :memo, type: :string, required: false, desc: 'memo'
    option :keystore, type: :string, aliases: '-k', required: true, desc: 'keystore or keystore.json file path'
    def transfer(user_id)
      res = {}

      CLI::UI::Spinner.spin "Try to transfer #{options[:amount]} #{options[:asset]} to #{user_id}" do |_spinner|
        res = api_instance.create_transfer(
          keystore['pin'],
          {
            asset_id: options[:asset],
            opponent_id: user_id,
            amount: options[:amount],
            memo: options[:memo]
          }
        )
      end

      return unless res['snapshot_id'].present?

      log UI.fmt "{{v}} Finished: https://mixin.one/snapshots/#{res['snapshot_id']}"
    end

    desc 'saferegister', 'register SAFE network'
    option :spend_key, type: :string, required: true, desc: 'spend_key'
    option :keystore, type: :string, aliases: '-k', required: true, desc: 'keystore or keystore.json file path'
    def saferegister
      res = api_instance.safe_register options[:spend_key]
      log res
    end

    desc 'pay', 'generate payment url'
    option :members, type: :array, required: true, desc: 'Reveivers, maybe multisig'
    option :threshold, type: :numeric, required: false, default: 1, desc: 'Threshold of multisig'
    option :asset, type: :string, required: true, desc: 'Asset ID'
    option :amount, type: :numeric, required: true, desc: 'Amount'
    option :trace, type: :string, required: false, desc: 'Trace ID'
    option :memo, type: :string, required: false, desc: 'memo'
    def pay
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

    desc 'safetransfer USER_ID', 'transfer asset to USER_ID with SAFE network'
    option :asset, type: :string, required: true, desc: 'Asset ID'
    option :amount, type: :numeric, required: true, desc: 'Amount'
    option :trace, type: :string, required: false, desc: 'Trace ID'
    option :memo, type: :string, required: false, desc: 'memo'
    option :keystore, type: :string, aliases: '-k', required: true, desc: 'keystore or keystore.json file path'
    def safetransfer(user_id)
      amount = options[:amount].to_d
      asset = options[:asset]
      memo = options[:memo] || ''

      # step 1: select inputs
      outputs = api_instance.safe_outputs(state: 'unspent', asset_id: asset, limit: 500)['data'].sort_by { |o| o['amount'].to_d }
      balance = outputs.sum(&->(output) { output['amount'].to_d })

      utxos = []
      outputs.each do |output|
        break if utxos.sum { |o| o['amount'].to_d } >= amount

        utxos.shift if utxos.size >= 255
        utxos << output
      end

      log UI.fmt "Step 1/7: {{v}} Found #{outputs.count} unspent outputs, balance: #{balance}, selected #{utxos.count} outputs"

      # step 2: build transaction
      tx = api_instance.build_safe_transaction(
        utxos:,
        receivers: [
          members: [user_id],
          threshold: 1,
          amount:
        ],
        extra: memo
      )
      raw = MixinBot::Utils.encode_raw_transaction tx
      log UI.fmt "Step 2/5: {{v}} Built raw: #{raw}"

      # step 3: verify transaction
      request_id = SecureRandom.uuid
      request = api_instance.create_safe_transaction_request(request_id, raw)['data']
      log UI.fmt "Step 3/5: {{v}} Verified transaction, request_id: #{request[0]['request_id']}"

      # step 4: sign transaction
      signed_raw = api_instance.sign_safe_transaction(
        raw:,
        utxos:,
        request: request[0]
      )
      log UI.fmt "Step 4/5: {{v}} Signed transaction: #{signed_raw}"

      # step 5: submit transaction
      r = api_instance.send_safe_transaction(
        request_id,
        signed_raw
      )
      log UI.fmt "Step 5/5: {{v}} Submit transaction, hash: #{r['data'].first['transaction_hash']}"
    rescue StandardError => e
      log UI.fmt "{{x}} #{e.inspect}"
    end
  end
end
