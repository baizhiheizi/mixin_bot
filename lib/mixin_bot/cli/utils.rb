# frozen_string_literal: true

module MixinBot
  class UtilsCLI < Thor
    include CLIOutput
    include CLIHelpers

    desc 'call METHOD', 'Invoke a MixinBot.utils method'
    option :data, type: :string, aliases: '-d', default: '{}', desc: 'JSON object of keyword arguments'
    def call(method_name, *positional)
      with_command_name('utils call') do
        kwargs = parse_utils_json_data(options[:data])
        result = invoke_utils_method(method_name, kwargs:, positional:)
        emit_success(result, command: 'utils call')
      end
    end

    desc 'list [FILTER]', 'List callable MixinBot.utils methods'
    option :limit, type: :numeric, default: 100, desc: 'Maximum items to return'
    option :offset, type: :numeric, default: 0, desc: 'Number of items to skip'
    option :fields, type: :string, default: 'name', desc: 'Comma-separated fields for JSON output'
    def list(filter = nil)
      with_command_name('utils list') do
        methods = CLIHelpers.utils_callable_methods
        if filter.present?
          needle = filter.downcase
          methods = methods.select { |m| m.to_s.downcase.include?(needle) }
        end

        items = methods.map { |name| { 'name' => name.to_s } }
        page, total, limit, offset = paginate_items(items, limit: options[:limit], offset: options[:offset])
        page = select_fields(page, options[:fields])

        if structured_output?
          emit_list(items: page, total:, limit:, offset:, command: 'utils list')
        else
          page.each { |item| puts item['name'] }
          emit_info("Showing #{page.size} of #{total} (limit=#{limit}, offset=#{offset})") if total > limit || offset.positive?
        end
      end
    end

    private

    def parse_utils_json_data(json_string, label: 'data')
      return {} if json_string.blank?

      parsed = JSON.parse(json_string)
      abort_with_error("#{label} must be a JSON object", kind: :invalid_args) unless parsed.is_a?(Hash)

      parsed.transform_keys(&:to_sym)
    rescue JSON::ParserError => e
      abort_with_error("invalid JSON for #{label}: #{e.message}", kind: :invalid_args)
    end

    def invoke_utils_method(method_name, kwargs: {}, positional: [])
      sym = method_name.to_sym
      unless CLIHelpers.utils_callable_methods.include?(sym)
        abort_with_error(
          format('unknown utils method: %<method>s', method: method_name),
          kind: :unsupported,
          hint: 'mixinbot utils list'
        )
      end

      MixinBot.utils.public_send(sym, *positional, **kwargs)
    rescue ::ArgumentError => e
      abort_with_error(
        format('invalid arguments for utils.%<method>s: %<error>s', method: method_name, error: e.message),
        kind: :invalid_args
      )
    end
  end

  class CLI
    desc 'utils', 'Utils dispatcher (call, list)'
    subcommand 'utils', UtilsCLI

    desc 'encrypt PIN', 'Encrypt PIN using session keys'
    option :keystore, type: :string, aliases: '-k', required: true, desc: 'keystore or keystore.json file path'
    option :iterator, type: :string, aliases: '-i', desc: 'Iterator'
    def encrypt(pin)
      with_command_name('encrypt') do
        setup_api_instance!
        emit_success(api_instance.encrypt_pin(pin.to_s, iterator: options[:iterator]), command: 'encrypt')
      end
    end

    desc 'unique UUIDS', 'Deterministic UUID from two or more UUIDs'
    def unique(*uuids)
      with_command_name('unique') do
        emit_success(MixinBot.utils.unique_uuid(*uuids), command: 'unique')
      end
    end

    desc 'generatetrace HASH', 'Trace UUID from transaction hash'
    option :index, type: :numeric, default: 0, desc: 'Output index'
    def generatetrace(hash)
      with_command_name('generatetrace') do
        emit_success(
          MixinBot.utils.generate_trace_from_hash(hash, options[:index]),
          command: 'generatetrace'
        )
      end
    end

    desc 'decodetx TRANSACTION', 'Decode raw transaction hex'
    def decodetx(transaction)
      with_command_name('decodetx') do
        emit_success(MixinBot.utils.decode_raw_transaction(transaction), command: 'decodetx')
      end
    end

    desc 'nftmemo', 'NFT mint memo'
    option :collection, type: :string, required: true, aliases: '-c', desc: 'Collection ID (UUID)'
    option :token, type: :numeric, required: true, aliases: '-t', desc: 'Token ID'
    option :hash, type: :string, required: true, aliases: '-h', desc: 'Metadata hash (256-bit hex)'
    def nftmemo
      with_command_name('nftmemo') do
        emit_success(
          MixinBot.utils.nft_memo(options[:collection], options[:token], options[:hash]),
          command: 'nftmemo'
        )
      end
    end

    desc 'rsa', 'Generate RSA key pair'
    def rsa
      with_command_name('rsa') do
        emit_success(MixinBot.utils.generate_rsa_key, command: 'rsa')
      end
    end

    desc 'ed25519', 'Generate Ed25519 key pair'
    def ed25519
      with_command_name('ed25519') do
        emit_success(MixinBot.utils.generate_ed25519_key, command: 'ed25519')
      end
    end
  end
end
