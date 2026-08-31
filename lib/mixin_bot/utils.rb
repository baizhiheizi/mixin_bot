# frozen_string_literal: true

require_relative 'utils/address'
require_relative 'utils/amount'
require_relative 'utils/crypto'
require_relative 'utils/decoder'
require_relative 'utils/encoder'

module MixinBot
  ##
  # Utility module providing various helper methods for Mixin Network operations.
  #
  # This module aggregates utility methods from several sub-modules:
  #
  # == Sub-modules
  #
  # [MixinBot::Utils::Address] Address-related utilities
  #   - Main address handling
  #   - Ghost key derivation
  #   - Address validation
  #
  # [MixinBot::Utils::Crypto] Cryptographic operations
  #   - JWT token generation
  #   - Key generation and management
  #   - Transaction signing
  #   - PIN encryption
  #   - UUID generation
  #
  # [MixinBot::Utils::Decoder] Data decoding utilities
  #   - Integer decoding
  #   - Transaction decoding
  #   - Key decoding
  #
  # [MixinBot::Utils::Encoder] Data encoding utilities
  #   - Integer encoding
  #   - Transaction encoding
  #   - Binary packing
  #
  # == Usage
  #
  # Access utilities through the MixinBot.utils shortcut:
  #
  #   # Generate a unique UUID
  #   uuid = MixinBot.utils.unique_uuid(uuid1, uuid2)
  #
  #   # Generate access token
  #   token = MixinBot.utils.access_token('GET', '/me', '')
  #
  #   # Encode a transaction
  #   raw = MixinBot.utils.encode_raw_transaction(txn)
  #
  #   # Decode a key
  #   key = MixinBot.utils.decode_key(encoded_key)
  #
  module Utils
    extend MixinBot::Utils::Address
    extend MixinBot::Utils::Amount
    extend MixinBot::Utils::Crypto
    extend MixinBot::Utils::Decoder
    extend MixinBot::Utils::Encoder
  end
end
