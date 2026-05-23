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
    option :force, type: :boolean, default: false, desc: 'Skip billing preflight for create_user (see -d force to override)'
    option :data_only, type: :boolean, default: false, desc: 'Print only the data field of API responses'
    def call(method_name, *positional)
      with_command_name('call') do
        setup_api_instance!
        kwargs = parse_json_data(options[:data])
        kwargs = merge_call_force_kwargs(method_name, kwargs)
        result = invoke_api(method_name, kwargs:, positional:)
        print_result(result, data_only: options[:data_only], command: 'call')
      end
    end

    desc 'list [FILTER]', 'List callable MixinBot::API methods (optional substring filter)'
    option :limit, type: :numeric, default: 100, desc: 'Maximum items to return'
    option :offset, type: :numeric, default: 0, desc: 'Number of items to skip'
    option :fields, type: :string, desc: 'Comma-separated fields for JSON output (name,owner)'
    def list(filter = nil)
      with_command_name('list') do
        methods = CLIHelpers.api_callable_methods
        if filter.present?
          needle = filter.downcase
          methods = methods.select { |m| m.to_s.downcase.include?(needle) }
        end

        items = methods.map do |name|
          { 'name' => name.to_s, 'owner' => CLIHelpers.api_method_owner(name) }
        end
        items = items.sort_by { |item| [item['owner'], item['name']] }

        page, total, limit, offset = paginate_items(items, limit: options[:limit], offset: options[:offset])
        page = select_fields(page, options[:fields])

        if structured_output?
          emit_list(items: page, total:, limit:, offset:, command: 'list')
        else
          print_pretty_list(page, total, limit, offset)
        end
      end
    end

    private

    def merge_call_force_kwargs(method_name, kwargs)
      return kwargs unless method_name.to_sym == :create_user
      return kwargs if kwargs.key?(:force)
      return kwargs unless options[:force]

      kwargs.merge(force: true)
    end

    def print_pretty_list(items, total, limit, offset)
      grouped = items.group_by { |item| item['owner'] }
      grouped.sort_by { |owner, _| owner }.each do |owner, names|
        puts "#{owner}:"
        names.sort_by { |n| n['name'] }.each { |n| puts "  #{n['name']}" }
        puts
      end

      return unless total > limit || offset.positive?

      emit_info("Showing #{items.size} of #{total} (limit=#{limit}, offset=#{offset})")
    end
  end
end
