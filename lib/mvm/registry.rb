# frozen_string_literal: true

module MVM
  class Registry
    attr_reader :rpc, :registry

    def initialize(rpc_url: MVM::RPC_URL, registry_address: MVM::REGISTRY_ADDRESS)
      @rpc = Eth::Client.create rpc_url
      @registry = Eth::Contract.from_abi name: 'Registry', address: registry_address,
                                         abi: File.read(File.expand_path('./abis/registry.json', __dir__))
    end

    def pid
      hex = @rpc.call(@registry, 'PID').to_s(16)
      MixinBot::UUID.new(hex:).unpacked
    end

    def version
      @rpc.call @registry, 'VERSION'
    end

    def asset_from_contract(contract)
      hex = @rpc.call(@registry, 'assets', contract).to_s(16)
      MixinBot::UUID.new(hex:).unpacked
    end

    def users_from_contract(contract)
      bytes = @rpc.call(@registry, 'users', contract).bytes
      members = []
      length = bytes.shift(2).reverse.pack('C*').unpack1('S*')
      length.times do
        members << MixinBot::UUID.new(raw: bytes.shift(16).pack('C*')).unpacked
      end
      threshold = bytes.shift(2).reverse.pack('C*').unpack1('S*')
      {
        members:,
        threshold:
      }.with_indifferent_access
    end

    def user_from_contract(contract)
      group = users_from_contract contract
      group[:members].first
    end

    def contract_from_asset(asset_id)
      @rpc.call @registry, 'contracts', asset_id.gsub('-', '').to_i(16)
    end

    def contract_from_user(user_id)
      contract_from_multisig [user_id], 1
    end

    def contract_from_multisig(user_ids, threshold)
      bytes = []
      bytes += MixinBot.utils.encode_uint16(user_ids.length)
      bytes += [user_ids.sort.join.gsub('-', '')].pack('H*').bytes
      bytes += MixinBot.utils.encode_uint16(threshold)

      hash = Eth::Util.bin_to_prefixed_hex(Eth::Util.keccak256(bytes.pack('C*')))
      @rpc.call @registry, 'contracts', hash.to_i(16)
    end
  end
end
