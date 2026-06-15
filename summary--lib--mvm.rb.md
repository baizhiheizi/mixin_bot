# lib/mvm.rb

MVM module. Constants: RPC_URL='https://geth.mvm.dev', MIRROR_ADDRESS='0xC193486e6Bf3E8461cb8fcdF178676a5D75c066A', REGISTRY_ADDRESS='0x3c84B6C98FBeB813e05a7A7813F0442883450B1F'.

Errors: MVM::Error (base), MVM::HttpError, MVM::ResponseError.

Singletons: MVM.bridge, MVM.scan, MVM.nft(**params), MVM.registry(**params).

Sub-modules: Bridge, Client, Nft, Registry, Scan under lib/mvm/. ABIs under lib/mvm/abis/: erc20.json, erc721.json, bridge.json, mirror.json, registry.json.