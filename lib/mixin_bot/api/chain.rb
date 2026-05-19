# frozen_string_literal: true

module MixinBot
  class API
    module Chain
      CHAIN_NAMES = {
        '59c09123-95cc-3ffd-a659-0f9169074cee' => 'Lightning',
        'c6d0c728-2624-429b-8e0d-d9d19b6592fa' => 'Bitcoin',
        'fd11b6e3-0b87-41f1-a41f-f0e9b49e5bf0' => 'Bitcoin Cash',
        '574388fd-b93f-4034-a682-01c2bc095d17' => 'Bitcoin SV',
        '76c802a2-7c88-447f-a93e-c29c9e5dd9c8' => 'Litecoin',
        '43d61dcd-e413-450d-80b8-101d5e903357' => 'Ethereum',
        '2204c1ee-0ea2-4add-bb9a-b3719cfff93a' => 'Ethereum Classic',
        '1949e683-6a08-49e2-b087-d6b72398588f' => 'BNB Smart Chain',
        'b7938396-3f94-4e0a-9179-d3440718156f' => 'Polygon',
        '3fb612c5-6844-3979-ae4a-5a84e79da870' => 'Base',
        '60360611-370c-3b69-9826-b13db93f6aba' => 'OP Mainnet',
        '8c590110-1abc-3697-84f2-05214e6516aa' => 'Arbitrum One',
        'a0ffd769-5850-4b48-9651-d2ae44a3e64d' => 'Mixin Virtual Machine',
        '8f5caf2a-283d-4c85-832a-91e83bbf290b' => 'Decred',
        '23dfb5a5-5d7b-48b6-905f-3970e3176e27' => 'Ripple',
        '990c4c29-57e9-48f6-9819-7d986ea44985' => 'Siacoin',
        '6cfe566e-4aad-470b-8c9a-2fd35b49c68d' => 'EOS',
        '6770a1e5-6086-44d5-b60f-545f9d9e8ffd' => 'Dogecoin',
        '6472e7e3-75fd-48b6-b1dc-28d294ee1476' => 'Dash',
        'c996abc9-d94e-4494-b1cf-2a3fd3ac5714' => 'Zcash',
        '27921032-f73e-434e-955f-43d55672ee31' => 'NEM',
        '882eb041-64ea-465f-a4da-817bd3020f52' => 'Arweave',
        'a2c5d22b-62a2-4c13-b3f0-013290dbac60' => 'Horizen',
        '25dabac5-056a-48ff-b9f9-f67395dc407c' => 'TRON',
        '56e63c06-b506-4ec5-885a-4a5ac17b83c1' => 'Stellar',
        'b207bce9-c248-4b8e-b6e3-e357146f3f4c' => 'MassGrid',
        '443e1ef5-bc9b-47d3-be77-07f328876c50' => 'Bytom',
        '71a0e8b5-a289-4845-b661-2b70ff9968aa' => 'Bytom',
        '7397e9f1-4e42-4dc8-8a3b-171daaadd436' => 'Cosmos',
        '9c612618-ca59-4583-af34-be9482f5002d' => 'Akash',
        '17f78d7c-ed96-40ff-980c-5dc62fecbc85' => 'BNB Beacon Chain',
        '05c5ac01-31f9-4a69-aa8a-ab796de1d041' => 'Monero',
        'c99a3779-93df-404d-945d-eddc440aa0b2' => 'Starcoin',
        '05891083-63d2-4f3d-bfbe-d14d7fb9b25a' => 'Bitshares',
        '6877d485-6b64-4225-8d7e-7333393cb243' => 'Ravencoin',
        '1351e6bd-66cf-40c1-8105-8a8fe518a222' => 'Grin',
        'c3b9153a-7fab-4138-a3a4-99849cadc073' => 'VCash',
        '13036886-6b83-4ced-8d44-9f69151587bf' => 'Handshake',
        'd243386e-6d84-42e6-be03-175be17bf275' => 'Nervos',
        '5649ca42-eb5f-4c0e-ae28-d9a4e77eded3' => 'Tezos',
        'f8b77dc0-46fd-4ea1-9821-587342475869' => 'Namecoin',
        '64692c23-8971-4cf4-84a7-4dd1271dd887' => 'Solana',
        'd6ac94f7-c932-4e11-97dd-617867f0669e' => 'NEAR',
        '08285081-e1d8-4be6-9edc-e203afa932da' => 'Filecoin',
        'eea900a8-b327-488c-8d8d-1428702fe240' => 'MobileCoin',
        '54c61a72-b982-4034-a556-0d99e3c21e39' => 'Polkadot',
        '9d29e4f6-d67c-4c4b-9525-604b04afbe9f' => 'Kusama',
        '706b6f84-3333-4e55-8e89-275e71ce9803' => 'Algorand',
        'cbc77539-0a20-4666-8c8a-4ded62b36f0a' => 'Avalanche X-Chain',
        '1f67ac58-87ba-3571-9781-e9413c046f34' => 'Avalanche C-Chain',
        '163a2142-398d-3483-aee3-d47db8da4d10' => 'MarsChain',
        'b12bb04a-1cea-401c-a086-0be61f544889' => 'XDC Network',
        'd2c1c7e1-a1a9-4f88-b282-d93b0a08b42b' => 'Aptos',
        '2bd97283-2582-33a8-bcba-f4b8ed189572' => 'Sui',
        'ef660437-d915-4e27-ad3f-632bfb6ba0ee' => 'TON'
      }.freeze

      XIN_ASSET_ID = 'c94ac88f-4671-3976-b60a-09064f1811e8'
      VAULTA_ASSET_ID = 'ac2b79f3-ec9c-3d87-b4ca-3e825228dda5'

      def network_chain(chain_id)
        path = format('/network/chains/%<chain_id>s', chain_id:)
        client.get path, access_token: ''
      end
      alias read_network_chain_by_id network_chain

      def network_chains
        client.get '/network/chains', access_token: ''
      end
      alias read_network_chains network_chains

      def chain_name(chain_id)
        CHAIN_NAMES[chain_id] || 'Not Supported Chain'
      end
      alias get_chain_name chain_name

      def chain_id?(chain_id)
        CHAIN_NAMES.key?(chain_id)
      end
      alias is_chain_id chain_id?

      def full_chains
        CHAIN_NAMES.transform_values { true }.dup
      end
      alias get_full_chains full_chains
    end
  end
end
