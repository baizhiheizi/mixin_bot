## Context

`API#blaze_async` (PR #216) returns a connected `Async::WebSocket` connection and leaves the loop to the caller — `examples/blaze_async.rb` is that loop (connect, keepalive ping, `LIST_PENDING_MESSAGES` on open, read → decode → ack, `Async`-fiber based, no EventMachine). Today the only hosted option is the EM-based `start_blaze_connect`, which forces a standalone process. See proposal.md for motivation.

Facts verified against Puma source that constrain the design:

- Plugin `start(launcher)` fires **once in the launcher process** (`Launcher#run → plugins.fire_starts`), before the runner starts. In cluster mode that is the master; workers are forked later and never run plugin code.
- `in_background` blocks become threads via `Plugins.fire_background`, which runs **after the app is loaded** (`load_and_bind` precedes it in both `Single#run` and preload-mode `Cluster#run`) — so the loop can resolve handlers referencing app code.
- Ruby threads do not survive `fork`; Puma 7 renamed lifecycle events (`on_booted/on_stopped/on_restart` → `after_booted/after_stopped/before_restart`). Solid Queue's plugin branches on `Gem::Version.new(Puma::Const::VERSION) < "7"`.
- Top-level `Async {}` (async 2.x) hosts its own reactor and blocks the current thread (`Fiber.blocking`), so `Thread.new { Async { ... } }` needs no Puma fiber integration on any Puma version.

## Goals / Non-Goals

**Goals:**
- One-line adoption (`plugin :mixin_blaze`) with sensible defaults; no standalone process.
- Solid Queue parity: dual-mode plugin, fork-supervision model, Puma 6/7 compatibility, monitor threads.
- The Blaze loop becomes a reusable, offline-testable class rather than example code.

**Non-Goals:**
- Not replacing `blaze` / `start_blaze_connect` (EM users keep working unchanged).
- Not making Puma a gem dependency; not per-worker hosting; not cross-process message passing between the web workers and the Blaze host (workers send via REST `create_message`).
- No delivery-semantics guarantees beyond what Mixin's redelivery model offers (see ack policy decision).

## Decisions

### D1: Dual-mode plugin, fork default (mirrors Solid Queue)
`mixin_blaze_mode` Puma DSL option (`:fork` default, `:async`), implemented by extending `Puma::DSL` from the plugin file exactly as `solid_queue.rb` does.

- *fork* (default): `booted` hook forks a child running the reactor; an `in_background` thread supervises it (`Process.waitpid … WNOHANG`; on child death, `Process.kill(:INT, $$)` stops Puma so the unit manager restarts everything). The child runs `Thread.new { monitor puma master via Process.ppid }` + the reactor, then `exit!` (skip at-exit finalization, same DB-handle-deadlock rationale as Solid Queue).
- *async*: `booted` hook starts the reactor in the launcher process; `stopped`/`restart` hooks stop it.

Alternatives: async-only (the literal ask) — rejected as default because cluster mode would host handlers in the Puma master (subtler AR/memory story, handler staleness); fork-only — rejected because it forfeits the "lives in the web process" goal for single-mode apps (the majority).

### D2: One reactor class, two hosts
Extract the example loop into `MixinBot::Blaze::Reactor` (name approximate): injectable API instance and connection factory, so tests stub the wire. The plugin file (`lib/puma/plugin/mixin_blaze.rb`) contains only Puma wiring; fork/async hosts call the same `Reactor`. Loop behavior: connect (`endpoint_options: { timeout: 10 }`), keepalive fiber (`send_ping` every 30 s), `list_pending_message` on open, serial read loop, reconnect with bounded exponential backoff (1 s → 30 s cap, reset after a stable period).

### D3: Handler and options via MixinBot config, resolved lazily
`MixinBot.blaze_handler` (callable, set in a Rails initializer) plus `MixinBot.blaze_ack_policy = :on_receipt` (default) or `:after_handler`. Resolved when the loop starts (after app boot — verified ordering above). Alternatives considered: Puma-DSL string handler (`mixin_blaze_handler "MyHandler"`, constantize) — more moving parts for no gain; ENV-based constant name — weaker typing, same lazy-resolution need.

### D4: Serial handler execution inside the reactor thread
Handlers run one-at-a-time between reads, never in concurrent fibers: ActiveRecord pools are per-thread, and two fibers sharing one connection would interleave protocol frames. The keepalive fiber never touches AR. A `Queue` + dedicated consumer thread is the documented escape hatch for slow handlers, not the default.

### D5: Loud precondition checks at boot
At `start`: cluster mode (`launcher.options[:workers] > 0`) without `options[:preload_app]` → `log_writer.error` naming the fix, loop not started. Handler unset at loop start → same treatment. (Not raising: a plugin exception during `fire_starts` aborts boot in ways that are hard to diagnose; a puma-level error line plus a no-op plugin is diagnosable and matches Solid Queue's soft style.)

### D6: Puma 6/7 event-name branching, no event-object monkey patching
Same `Gem::Version.new(Puma::Const::VERSION) < "7"` branch as Solid Queue; hook names chosen per version (`on_booted`/`on_stopped`/`on_restart` vs `after_booted`/`after_stopped`/`before_restart`).

### D7: Packaging and testing without a Puma dependency
`lib/puma/plugin/mixin_blaze.rb` is inert unless Puma requires it (plugin files are loaded by Puma's own registry, path-derived name is mandatory). Puma is added only as a Gemfile dev/test dependency for plugin smoke tests (`Puma::Launcher` boot with a stub app); the reactor itself is unit-tested with a fake connection. No gemspec dependency changes.

## Risks / Trade-offs

- [Phased restart keeps old handler code (master/child never reloads)] → document; full restart picks up handler changes. Same trade-off as Solid Queue.
- [Async mode in cluster runs the loop in the master (shared unit with workers)] → default is fork, which isolates; async mode documented as single-mode-first.
- [Accidental duplicate connections (old standalone process + plugin)] → PID-bearing connect log line; docs warn to remove the old process first.
- [Multi-connection delivery semantics undocumented by Mixin (fan-out vs load-balance)] → open question; does not change this design (one connection per host either way).
- [Child death stops the whole unit (fail-fast)] → deliberate: silent non-reception is worse than a visible restart; matches Solid Queue.
- [async-websocket API drift (~> 0.30 pinned)] → reactor isolates the wire calls; example code already documents the read/write contract.

## Migration Plan

1. Enable `plugin :mixin_blaze` (+ `mixin_blaze_mode` if non-default) and configure `MixinBot.blaze_handler` / `blaze_ack_policy` in the app.
2. **Remove the standalone Blaze process** from Procfile/systemd/docker-compose in the same deploy, or deliveries duplicate.
3. Rollback: remove the plugin line, restore the standalone process.

## Open Questions

- Mixin's multi-connection behavior (fan-out vs load-balance, and whether an ACK clears pending state app-globally) — verify once with a live two-connection experiment; affects docs only.
- Whether a Puma-DSL handler option is worth adding alongside `MixinBot.blaze_handler` — defer until real usage shows a need.
