# lib/mixin_bot/transaction.rb

Constants: REFERENCES_TX_VERSION=0x04, SAFE_TX_VERSION=0x05, DEAULT_VERSION=5, MAGIC=[0x77,0x77], TX_VERSION=2, MAX_ENCODE_INT=0xFFFF, MAX_EXTRA_SIZE=512, NULL_BYTES=[0x00,0x00], AGGREGATED_SIGNATURE_PREFIX=0xFF01, AGGREGATED_SIGNATURE_ORDINAY_MASK=[0x00], AGGREGATED_SIGNATURE_SPARSE_MASK=[0x01].

Fields: version, asset, inputs, outputs, extra, signatures, aggregated, references, hex, hash.

`encode` → Encoder, `decode` → Decoder. `to_h` compacts to a payload hash. Requires Buffer, Encoder, Decoder under lib/mixin_bot/transaction/.