/-
# FVSquad

Lean 4 formal-verification squad for `baizhiheizi/mixin_bot`.

This library contains formal specifications and (eventually) implementation
models and proofs for the encoding / decoding targets identified in
`formal-verification/TARGETS.md`. It is intentionally light: the Tier 1
specs (UUID, Varint, UintCodec) use only `Init` and `Std`; the address /
transaction specs that follow may need `Mathlib` for byte-array reasoning.

## Layout

- `FVSquad/MainAddress.lean` — `MixinBot::MainAddress` (XIN-prefixed
  Ed25519 public-key addresses).
- More files to be added as the squad progresses through the target list.
-/

import FVSquad.MainAddress
