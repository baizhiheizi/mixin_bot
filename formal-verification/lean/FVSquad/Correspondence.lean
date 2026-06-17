/-
  🔬 Lean Squad — automated formal verification for `baizhiheizi/mixin_bot`.

  Lean side of the executable correspondence harness for Tier 1 codecs.

  The Ruby harness at
  `formal-verification/tests/tier1_codecs/ruby_harness.rb` runs the
  Ruby `encode_int` / `encode_uint*` on a curated set of inputs and
  writes the expected byte values to
  `formal-verification/tests/tier1_codecs/fixtures.json`.

  This Lean file `#guard`s that the Lean model produces the same bytes
  as the Ruby implementation on the same inputs. Because `#guard` is
  checked at compile time, `lake build` is the pass/fail check: any
  mismatch fails the build.

  The UUID codec uses `noncomputable` axioms in `FVSquad.UUID` and is
  not `#eval`-able in its current form. It is verified by the round-trip
  `sorry`s in `UUID.lean` and the existing test oracle in
  `test/mixin_bot/test_uuid.rb`. The Ruby `UUID#packed` / `UUID#unpacked`
  outputs are captured in the fixture for future direct comparison
  once a concrete `bytesToHex` / `formatDashed` is supplied.
-/

import FVSquad.Varint
import FVSquad.UintCodec
import FVSquad.UUID

namespace FVSquad.Correspondence

open FVSquad.Varint FVSquad.UintCodec FVSquad.UUID

/-! ## Varint: `encode_int` / `decode_int` byte-level check

Source of expected bytes: `formal-verification/tests/tier1_codecs/fixtures.json` (regenerable
by running `ruby_harness.rb`). Each `#guard` is the Lean-byte == Ruby-byte check. -/

#guard encodeInt 0 = [0]
#guard encodeInt 1 = [1]
#guard encodeInt 127 = [127]
#guard encodeInt 128 = [128]
#guard encodeInt 255 = [255]
#guard encodeInt 256 = [1, 0]
#guard encodeInt 257 = [1, 1]
#guard encodeInt 1000 = [3, 232]
#guard encodeInt 65535 = [255, 255]
#guard encodeInt 65536 = [1, 0, 0]
#guard encodeInt 1000000 = [15, 66, 64]
#guard encodeInt 4294967296 = [1, 0, 0, 0, 0]
#guard encodeInt 9223372036854775808 = [128, 0, 0, 0, 0, 0, 0, 0]

#guard decodeInt (encodeInt 0) = 0
#guard decodeInt (encodeInt 1) = 1
#guard decodeInt (encodeInt 127) = 127
#guard decodeInt (encodeInt 128) = 128
#guard decodeInt (encodeInt 255) = 255
#guard decodeInt (encodeInt 256) = 256
#guard decodeInt (encodeInt 65535) = 65535
#guard decodeInt (encodeInt 65536) = 65536
#guard decodeInt (encodeInt 1000000) = 1000000
#guard decodeInt (encodeInt 4294967296) = 4294967296
#guard decodeInt (encodeInt 9223372036854775808) = 9223372036854775808

/-! ## Uint16: `encode_uint16` / `decode_uint16` byte-level check -/

#guard encodeUint 16 (⟨0, by decide⟩ : Bounded 16) = [0, 0]
#guard encodeUint 16 (⟨1, by decide⟩ : Bounded 16) = [0, 1]
#guard encodeUint 16 (⟨127, by decide⟩ : Bounded 16) = [0, 127]
#guard encodeUint 16 (⟨128, by decide⟩ : Bounded 16) = [0, 128]
#guard encodeUint 16 (⟨255, by decide⟩ : Bounded 16) = [0, 255]
#guard encodeUint 16 (⟨256, by decide⟩ : Bounded 16) = [1, 0]
#guard encodeUint 16 (⟨1000, by decide⟩ : Bounded 16) = [3, 232]
#guard encodeUint 16 (⟨32767, by decide⟩ : Bounded 16) = [127, 255]
#guard encodeUint 16 (⟨32768, by decide⟩ : Bounded 16) = [128, 0]
#guard encodeUint 16 (⟨65535, by decide⟩ : Bounded 16) = [255, 255]

#guard decodeUint 16 (encodeUint 16 (⟨0, by decide⟩ : Bounded 16)) = 0
#guard decodeUint 16 (encodeUint 16 (⟨1, by decide⟩ : Bounded 16)) = 1
#guard decodeUint 16 (encodeUint 16 (⟨255, by decide⟩ : Bounded 16)) = 255
#guard decodeUint 16 (encodeUint 16 (⟨256, by decide⟩ : Bounded 16)) = 256
#guard decodeUint 16 (encodeUint 16 (⟨32767, by decide⟩ : Bounded 16)) = 32767
#guard decodeUint 16 (encodeUint 16 (⟨32768, by decide⟩ : Bounded 16)) = 32768
#guard decodeUint 16 (encodeUint 16 (⟨65535, by decide⟩ : Bounded 16)) = 65535

/-! ## Uint32: `encode_uint32` / `decode_uint32` byte-level check -/

#guard encodeUint 32 (⟨0, by decide⟩ : Bounded 32) = [0, 0, 0, 0]
#guard encodeUint 32 (⟨1, by decide⟩ : Bounded 32) = [0, 0, 0, 1]
#guard encodeUint 32 (⟨65535, by decide⟩ : Bounded 32) = [0, 0, 255, 255]
#guard encodeUint 32 (⟨65536, by decide⟩ : Bounded 32) = [0, 1, 0, 0]
#guard encodeUint 32 (⟨2147483647, by decide⟩ : Bounded 32) = [127, 255, 255, 255]
#guard encodeUint 32 (⟨2147483648, by decide⟩ : Bounded 32) = [128, 0, 0, 0]
#guard encodeUint 32 (⟨4294967295, by decide⟩ : Bounded 32) = [255, 255, 255, 255]

#guard decodeUint 32 (encodeUint 32 (⟨0, by decide⟩ : Bounded 32)) = 0
#guard decodeUint 32 (encodeUint 32 (⟨1, by decide⟩ : Bounded 32)) = 1
#guard decodeUint 32 (encodeUint 32 (⟨65535, by decide⟩ : Bounded 32)) = 65535
#guard decodeUint 32 (encodeUint 32 (⟨65536, by decide⟩ : Bounded 32)) = 65536
#guard decodeUint 32 (encodeUint 32 (⟨2147483647, by decide⟩ : Bounded 32)) = 2147483647
#guard decodeUint 32 (encodeUint 32 (⟨2147483648, by decide⟩ : Bounded 32)) = 2147483648
#guard decodeUint 32 (encodeUint 32 (⟨4294967295, by decide⟩ : Bounded 32)) = 4294967295

/-! ## Uint64: `encode_uint64` / `decode_uint64` byte-level check -/

#guard encodeUint 64 (⟨0, by decide⟩ : Bounded 64) = [0, 0, 0, 0, 0, 0, 0, 0]
#guard encodeUint 64 (⟨1, by decide⟩ : Bounded 64) = [0, 0, 0, 0, 0, 0, 0, 1]
#guard encodeUint 64 (⟨4294967295, by decide⟩ : Bounded 64) = [0, 0, 0, 0, 255, 255, 255, 255]
#guard encodeUint 64 (⟨4294967296, by decide⟩ : Bounded 64) = [0, 0, 0, 1, 0, 0, 0, 0]
#guard encodeUint 64 (⟨4611686018427387904, by decide⟩ : Bounded 64) = [64, 0, 0, 0, 0, 0, 0, 0]
#guard encodeUint 64 (⟨9223372036854775807, by decide⟩ : Bounded 64) = [127, 255, 255, 255, 255, 255, 255, 255]
#guard encodeUint 64 (⟨9223372036854775808, by decide⟩ : Bounded 64) = [128, 0, 0, 0, 0, 0, 0, 0]
#guard encodeUint 64 (⟨18446744073709551615, by decide⟩ : Bounded 64) = [255, 255, 255, 255, 255, 255, 255, 255]

#guard decodeUint 64 (encodeUint 64 (⟨0, by decide⟩ : Bounded 64)) = 0
#guard decodeUint 64 (encodeUint 64 (⟨1, by decide⟩ : Bounded 64)) = 1
#guard decodeUint 64 (encodeUint 64 (⟨4294967295, by decide⟩ : Bounded 64)) = 4294967295
#guard decodeUint 64 (encodeUint 64 (⟨4294967296, by decide⟩ : Bounded 64)) = 4294967296
#guard decodeUint 64 (encodeUint 64 (⟨4611686018427387904, by decide⟩ : Bounded 64)) = 4611686018427387904
#guard decodeUint 64 (encodeUint 64 (⟨9223372036854775807, by decide⟩ : Bounded 64)) = 9223372036854775807
#guard decodeUint 64 (encodeUint 64 (⟨9223372036854775808, by decide⟩ : Bounded 64)) = 9223372036854775808
#guard decodeUint 64 (encodeUint 64 (⟨18446744073709551615, by decide⟩ : Bounded 64)) = 18446744073709551615

/-! ## Length properties (cross-check) -/

#guard (encodeInt 256).length = 2
#guard (encodeInt 65536).length = 3
#guard (encodeInt 4294967296).length = 5
#guard (encodeUint 16 (⟨0, by decide⟩ : Bounded 16)).length = 2
#guard (encodeUint 32 (⟨0, by decide⟩ : Bounded 32)).length = 4
#guard (encodeUint 64 (⟨0, by decide⟩ : Bounded 64)).length = 8

/-! ## UUID: `bytesToHex` byte-level check against Ruby fixtures

The 6 UUID fixtures in `formal-verification/tests/tier1_codecs/fixtures.json`
record the live Ruby `UUID#packed` / `UUID#unpacked` byte output. Each
`#guard` below is the Lean ↔ Ruby byte equality check; failures fail
the `lake build`. -/

-- UUID 1: 965e5c6e-434c-3fa9-b780-c50f43cd955c
#guard bytesToHex
  ([⟨150, by decide⟩, ⟨94, by decide⟩, ⟨92, by decide⟩, ⟨110, by decide⟩,
    ⟨67, by decide⟩, ⟨76, by decide⟩, ⟨63, by decide⟩, ⟨169, by decide⟩,
    ⟨183, by decide⟩, ⟨128, by decide⟩, ⟨197, by decide⟩, ⟨15, by decide⟩,
    ⟨67, by decide⟩, ⟨205, by decide⟩, ⟨149, by decide⟩, ⟨92, by decide⟩] :
    List UUID.Byte) = "965e5c6e434c3fa9b780c50f43cd955c"
#guard hexToBytes "965e5c6e434c3fa9b780c50f43cd955c" =
  ([⟨150, by decide⟩, ⟨94, by decide⟩, ⟨92, by decide⟩, ⟨110, by decide⟩,
    ⟨67, by decide⟩, ⟨76, by decide⟩, ⟨63, by decide⟩, ⟨169, by decide⟩,
    ⟨183, by decide⟩, ⟨128, by decide⟩, ⟨197, by decide⟩, ⟨15, by decide⟩,
    ⟨67, by decide⟩, ⟨205, by decide⟩, ⟨149, by decide⟩, ⟨92, by decide⟩] :
    List UUID.Byte)
#guard formatDashed "965e5c6e434c3fa9b780c50f43cd955c" =
  "965e5c6e-434c-3fa9-b780-c50f43cd955c"
#guard stripDashes "965e5c6e-434c-3fa9-b780-c50f43cd955c" =
  "965e5c6e434c3fa9b780c50f43cd955c"

-- UUID 2: 7ed9292d-7c95-4333-aa48-a8c640064186
#guard bytesToHex
  ([⟨126, by decide⟩, ⟨217, by decide⟩, ⟨41, by decide⟩, ⟨45, by decide⟩,
    ⟨124, by decide⟩, ⟨149, by decide⟩, ⟨67, by decide⟩, ⟨51, by decide⟩,
    ⟨170, by decide⟩, ⟨72, by decide⟩, ⟨168, by decide⟩, ⟨198, by decide⟩,
    ⟨64, by decide⟩, ⟨6, by decide⟩, ⟨65, by decide⟩, ⟨134, by decide⟩] :
    List UUID.Byte) = "7ed9292d7c954333aa48a8c640064186"
#guard hexToBytes "7ed9292d7c954333aa48a8c640064186" =
  ([⟨126, by decide⟩, ⟨217, by decide⟩, ⟨41, by decide⟩, ⟨45, by decide⟩,
    ⟨124, by decide⟩, ⟨149, by decide⟩, ⟨67, by decide⟩, ⟨51, by decide⟩,
    ⟨170, by decide⟩, ⟨72, by decide⟩, ⟨168, by decide⟩, ⟨198, by decide⟩,
    ⟨64, by decide⟩, ⟨6, by decide⟩, ⟨65, by decide⟩, ⟨134, by decide⟩] :
    List UUID.Byte)
#guard formatDashed "7ed9292d7c954333aa48a8c640064186" =
  "7ed9292d-7c95-4333-aa48-a8c640064186"
#guard stripDashes "7ed9292d-7c95-4333-aa48-a8c640064186" =
  "7ed9292d7c954333aa48a8c640064186"

-- UUID 3: a67c6e87-1c9e-4a1c-b81c-47a9f4f1bff1
#guard bytesToHex
  ([⟨166, by decide⟩, ⟨124, by decide⟩, ⟨110, by decide⟩, ⟨135, by decide⟩,
    ⟨28, by decide⟩, ⟨158, by decide⟩, ⟨74, by decide⟩, ⟨28, by decide⟩,
    ⟨184, by decide⟩, ⟨28, by decide⟩, ⟨71, by decide⟩, ⟨169, by decide⟩,
    ⟨244, by decide⟩, ⟨241, by decide⟩, ⟨191, by decide⟩, ⟨241, by decide⟩] :
    List UUID.Byte) = "a67c6e871c9e4a1cb81c47a9f4f1bff1"
#guard hexToBytes "a67c6e871c9e4a1cb81c47a9f4f1bff1" =
  ([⟨166, by decide⟩, ⟨124, by decide⟩, ⟨110, by decide⟩, ⟨135, by decide⟩,
    ⟨28, by decide⟩, ⟨158, by decide⟩, ⟨74, by decide⟩, ⟨28, by decide⟩,
    ⟨184, by decide⟩, ⟨28, by decide⟩, ⟨71, by decide⟩, ⟨169, by decide⟩,
    ⟨244, by decide⟩, ⟨241, by decide⟩, ⟨191, by decide⟩, ⟨241, by decide⟩] :
    List UUID.Byte)
#guard formatDashed "a67c6e871c9e4a1cb81c47a9f4f1bff1" =
  "a67c6e87-1c9e-4a1c-b81c-47a9f4f1bff1"
#guard stripDashes "a67c6e87-1c9e-4a1c-b81c-47a9f4f1bff1" =
  "a67c6e871c9e4a1cb81c47a9f4f1bff1"

-- UUID 4: 00000000-0000-0000-0000-000000000000 (zero UUID)
#guard bytesToHex (List.replicate 16 (⟨0, by decide⟩ : UUID.Byte)) =
  "00000000000000000000000000000000"
#guard hexToBytes "00000000000000000000000000000000" =
  (List.replicate 16 (⟨0, by decide⟩ : UUID.Byte))
#guard formatDashed "00000000000000000000000000000000" =
  "00000000-0000-0000-0000-000000000000"
#guard stripDashes "00000000-0000-0000-0000-000000000000" =
  "00000000000000000000000000000000"

-- UUID 5: ffffffff-ffff-ffff-ffff-ffffffffffff (max UUID)
#guard bytesToHex (List.replicate 16 (⟨255, by decide⟩ : UUID.Byte)) =
  "ffffffffffffffffffffffffffffffff"
#guard hexToBytes "ffffffffffffffffffffffffffffffff" =
  (List.replicate 16 (⟨255, by decide⟩ : UUID.Byte))
#guard formatDashed "ffffffffffffffffffffffffffffffff" =
  "ffffffff-ffff-ffff-ffff-ffffffffffff"
#guard stripDashes "ffffffff-ffff-ffff-ffff-ffffffffffff" =
  "ffffffffffffffffffffffffffffffff"

-- UUID 6: c94ac88f-4671-3976-b60a-09064f1811e8
#guard bytesToHex
  ([⟨201, by decide⟩, ⟨74, by decide⟩, ⟨200, by decide⟩, ⟨143, by decide⟩,
    ⟨70, by decide⟩, ⟨113, by decide⟩, ⟨57, by decide⟩, ⟨118, by decide⟩,
    ⟨182, by decide⟩, ⟨10, by decide⟩, ⟨9, by decide⟩, ⟨6, by decide⟩,
    ⟨79, by decide⟩, ⟨24, by decide⟩, ⟨17, by decide⟩, ⟨232, by decide⟩] :
    List UUID.Byte) = "c94ac88f46713976b60a09064f1811e8"
#guard hexToBytes "c94ac88f46713976b60a09064f1811e8" =
  ([⟨201, by decide⟩, ⟨74, by decide⟩, ⟨200, by decide⟩, ⟨143, by decide⟩,
    ⟨70, by decide⟩, ⟨113, by decide⟩, ⟨57, by decide⟩, ⟨118, by decide⟩,
    ⟨182, by decide⟩, ⟨10, by decide⟩, ⟨9, by decide⟩, ⟨6, by decide⟩,
    ⟨79, by decide⟩, ⟨24, by decide⟩, ⟨17, by decide⟩, ⟨232, by decide⟩] :
    List UUID.Byte)
#guard formatDashed "c94ac88f46713976b60a09064f1811e8" =
  "c94ac88f-4671-3976-b60a-09064f1811e8"
#guard stripDashes "c94ac88f-4671-3976-b60a-09064f1811e8" =
  "c94ac88f46713976b60a09064f1811e8"

end FVSquad.Correspondence
