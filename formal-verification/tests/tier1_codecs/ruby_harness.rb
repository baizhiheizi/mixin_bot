# frozen_string_literal: true
# 🔬 Lean Squad — automated formal verification for `baizhiheizi/mixin_bot`.
#
# Ruby correspondence harness for Tier 1 codecs.
#
# This script exercises the Ruby implementation of:
#   - `MixinBot::Utils::Encoder.encode_int` / `Decoder.decode_int`
#   - `MixinBot::Utils::Encoder.encode_uint16/32/64` / `Decoder.decode_uint16/32/64`
#   - `MixinBot::UUID#packed` / `UUID#unpacked`
#
# on a curated set of inputs, and emits a JSON fixture that lists the
# expected byte values for each input. The Lean harness (see
# `lean_harness.lean` and `correspondence_check.lean`) `#eval`s the Lean
# model on the same inputs and compares.
#
# Usage:
#   ruby formal-verification/tests/tier1_codecs/ruby_harness.rb \
#        > formal-verification/tests/tier1_codecs/fixtures.json

require 'json'
require 'active_support'
require 'active_support/core_ext'

$LOAD_PATH.unshift File.expand_path('../../../lib', __dir__)

# Load just what we need, bypassing mixin_bot.rb's MVM dependency
require 'mixin_bot/version'
require 'mixin_bot/errors'
require 'mixin_bot/utils/encoder'
require 'mixin_bot/utils/decoder'
require 'mixin_bot/uuid'

class Harness
  include MixinBot::Utils::Encoder
  include MixinBot::Utils::Decoder
end

H = Harness.new

# ----------------------------------------------------------------------
# Test fixtures — same set that the Lean model covers in its `example`s,
# plus a few additional values to widen coverage.
# ----------------------------------------------------------------------

VARINT_INPUTS = [
  0,
  1,
  2,
  127,
  128,
  255,
  256,
  257,
  1000,
  65_535,
  65_536,
  1_000_000,
  2**32,
  2**63
].freeze

UINT16_INPUTS = [0, 1, 127, 128, 255, 256, 1000, 32_767, 32_768, 65_535].freeze
UINT32_INPUTS = [0, 1, 65_535, 65_536, 2_147_483_647, 2_147_483_648, 4_294_967_295].freeze
UINT64_INPUTS = [
  0,
  1,
  4_294_967_295,
  4_294_967_296,
  2**62,
  2**63 - 1,
  2**63,
  2**64 - 1
].freeze

UUID_INPUTS = [
  '965e5c6e-434c-3fa9-b780-c50f43cd955c',
  '7ed9292d-7c95-4333-aa48-a8c640064186',
  'a67c6e87-1c9e-4a1c-b81c-47a9f4f1bff1',
  '00000000-0000-0000-0000-000000000000',
  'ffffffff-ffff-ffff-ffff-ffffffffffff',
  'c94ac88f-4671-3976-b60a-09064f1811e8'
].freeze

# ----------------------------------------------------------------------
# Build the fixture. Keys are symbolic so the Lean harness can match them
# without depending on the order of the inputs.
# ----------------------------------------------------------------------

fixture = {
  'varint' => VARINT_INPUTS.to_h { |n| [n.to_s, H.encode_int(n).map(&:to_i)] },
  'varint_roundtrip' => VARINT_INPUTS.to_h { |n| [n.to_s, H.decode_int(H.encode_int(n))] },
  'uint16' => UINT16_INPUTS.to_h { |n| [n.to_s, H.encode_uint16(n).map(&:to_i)] },
  'uint16_roundtrip' => UINT16_INPUTS.to_h { |n| [n.to_s, H.decode_uint16(H.encode_uint16(n))] },
  'uint32' => UINT32_INPUTS.to_h { |n| [n.to_s, H.encode_uint32(n).map(&:to_i)] },
  'uint32_roundtrip' => UINT32_INPUTS.to_h { |n| [n.to_s, H.decode_uint32(H.encode_uint32(n))] },
  'uint64' => UINT64_INPUTS.to_h { |n| [n.to_s, H.encode_uint64(n).map(&:to_i)] },
  'uint64_roundtrip' => UINT64_INPUTS.to_h { |n| [n.to_s, H.decode_uint64(H.encode_uint64(n))] },
  'uuid' => UUID_INPUTS.to_h do |hex|
    uuid = MixinBot::UUID.new(hex:)
    [
      hex,
      {
        'unpacked' => uuid.unpacked,
        'packed_hex' => uuid.packed.unpack1('H*'),
        'packed_bytes' => uuid.packed.bytes.map(&:to_i)
      }
    ]
  end
}

puts JSON.pretty_generate(fixture)
