# frozen_string_literal: true

module MVM
  class Nft
    attr_reader :rpc, :mirror

    def initialize(rpc_url: MVM::RPC_URL, mirror_address: MVM::MIRROR_ADDRESS)
      @rpc = Eth::Client.create rpc_url
      @mirror = Eth::Contract.from_abi name: 'Mirror', address: mirror_address,
                                       abi: File.read(File.expand_path('./abis/mirror.json', __dir__))
    end

    def collection_from_contract(address)
      collection = @rpc.call @mirror, 'collections', address
      return if collection.zero?

      MixinBot::UUID.new(hex: collection.to_fs(16)).unpacked
    end

    def contract_from_collection(uuid)
      collection = uuid.to_s.gsub('-', '').to_i(16)
      contract = @rpc.call @mirror, 'contracts', collection
      address = Eth::Address.new contract
      return unless address.valid?

      address.checksummed
    end

    def owner_of(collection_id, token_id)
      address = contract_from_collection collection_id
      return if address.blank? || address.to_i(16).zero?

      contract = Eth::Contract.from_abi name: 'Collectible', address:, abi: File.read(File.expand_path('./abis/erc721.json', __dir__))
      owner = @rpc.call contract, 'ownerOf', token_id.to_i
      address = Eth::Address.new owner
      return unless address.valid?

      address.checksummed
    rescue IOError
      nil
    end

    def token_of_owner_by_index(contract, owner, index)
      contract = Eth::Contract.from_abi name: 'Collectible', address: contract,
                                        abi: File.read(File.expand_path('./abis/erc721.json', __dir__))

      @rpc.call contract, 'tokenOfOwnerByIndex', owner, index
    rescue IOError
      nil
    end
  end
end
