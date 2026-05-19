# frozen_string_literal: true

module MixinBot
  class CLI
    desc 'call METHOD', 'Invoke a MixinBot::API method with JSON keyword arguments'
    long_desc <<-LONGDESC
      Invoke any public API method (see `mixinbot list`).

      Examples:

        $ mixinbot call me -k ~/.mixinbot/keystore.json
        $ mixinbot call safe_outputs -k keystore.json -d '{"asset":"...","state":"unspent","limit":10}'
        $ mixinbot call user USER_ID -k keystore.json
        $ mixinbot call create_transfer -k keystore.json -d '{"members":"uuid","asset_id":"...","amount":"0.01"}'
    LONGDESC
    option :keystore, type: :string, aliases: '-k', desc: 'keystore JSON file path or inline JSON'
    option :data, type: :string, aliases: '-d', default: '{}', desc: 'JSON object of keyword arguments'
    option :data_only, type: :boolean, default: false, desc: 'Print only the data field of API responses'
    def call(method_name, *positional)
      setup_api_instance!
      kwargs = parse_json_data(options[:data])
      result = invoke_api(method_name, kwargs:, positional:)
      print_result(result, data_only: options[:data_only])
    end

    desc 'list [FILTER]', 'List callable MixinBot::API methods (optional substring filter)'
    def list(filter = nil)
      methods = CLIHelpers.api_callable_methods
      if filter.present?
        needle = filter.downcase
        methods = methods.select { |m| m.to_s.downcase.include?(needle) }
      end

      CLIHelpers.grouped_api_methods.each do |owner, names|
        filtered = names & methods
        next if filtered.empty?

        puts "#{owner}:"
        filtered.each { |m| puts "  #{m}" }
        puts
      end
    end
  end
end
