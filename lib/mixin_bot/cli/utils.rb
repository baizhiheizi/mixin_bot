# frozen_string_literal: true

module MixinBot
  class UtilsCLI < Thor
    desc 'call METHOD', 'Invoke a MixinBot.utils method'
    option :data, type: :string, aliases: '-d', default: '{}', desc: 'JSON object of keyword arguments'
    def call(method_name, *positional)
      kwargs = parent.send(:parse_json_data, options[:data])
      result = parent.send(:invoke_utils, method_name, kwargs:, positional:)
      parent.send(:log, result)
    end

    desc 'list [FILTER]', 'List callable MixinBot.utils methods'
    def list(filter = nil)
      methods = CLIHelpers.utils_callable_methods
      if filter.present?
        needle = filter.downcase
        methods = methods.select { |m| m.to_s.downcase.include?(needle) }
      end
      methods.each { |m| puts m }
    end
  end

  class CLI
    desc 'utils', 'Utils dispatcher (call, list)'
    subcommand 'utils', UtilsCLI

    desc 'encrypt PIN', 'Encrypt PIN using session keys'
    option :keystore, type: :string, aliases: '-k', required: true, desc: 'keystore or keystore.json file path'
    option :iterator, type: :string, aliases: '-i', desc: 'Iterator'
    def encrypt(pin)
      setup_api_instance!
      log api_instance.encrypt_pin pin.to_s, iterator: options[:iterator]
    end

    desc 'unique UUIDS', 'Deterministic UUID from two or more UUIDs'
    def unique(*uuids)
      log MixinBot.utils.unique_uuid(*uuids)
    end

    desc 'generatetrace HASH', 'Trace UUID from transaction hash'
    option :index, type: :numeric, default: 0, desc: 'Output index'
    def generatetrace(hash)
      log MixinBot.utils.generate_trace_from_hash(hash, options[:index])
    end

    desc 'decodetx TRANSACTION', 'Decode raw transaction hex'
    def decodetx(transaction)
      log MixinBot.utils.decode_raw_transaction(transaction)
    end

    desc 'nftmemo', 'NFT mint memo'
    option :collection, type: :string, required: true, aliases: '-c', desc: 'Collection ID (UUID)'
    option :token, type: :numeric, required: true, aliases: '-t', desc: 'Token ID'
    option :hash, type: :string, required: true, aliases: '-h', desc: 'Metadata hash (256-bit hex)'
    def nftmemo
      log MixinBot.utils.nft_memo(options[:collection], options[:token], options[:hash])
    end

    desc 'rsa', 'Generate RSA key pair'
    def rsa
      log MixinBot.utils.generate_rsa_key
    end

    desc 'ed25519', 'Generate Ed25519 key pair'
    def ed25519
      log MixinBot.utils.generate_ed25519_key
    end
  end
end
