## Why

Receiving Blaze messages currently requires a standalone process: the EventMachine-based `start_blaze_connect` loop must be given its own Procfile entry / systemd unit / container command. Since `blaze_async` (fiber-based, EventMachine-free) landed, the connection can instead be hosted inside the process mixin_bot apps actually run in — a Rails app under Puma — exactly the way Solid Queue hosts its supervisor via its official Puma plugin. This removes an entire deployment artifact.

## What Changes

- Ship a Puma plugin, `lib/puma/plugin/mixin_blaze.rb`, enabled with `plugin :mixin_blaze` in `config/puma.rb`.
- Dual run modes, mirroring Solid Queue's plugin:
  - **fork** (default): `on_booted` forks a dedicated Blaze child process running the reactor loop; a background thread monitors the child and stops Puma if it dies; `on_stopped`/`on_restart` terminate the child.
  - **async** (in-process): the reactor loop runs in a Puma background thread inside its own `Async` reactor — the web process hosts Blaze directly, no child process.
- New `mixin_blaze_mode` Puma DSL option (`:fork` default, `:async`), plus Puma 6/7 lifecycle-event compatibility (`on_booted` vs `after_booted` naming).
- New reusable Blaze reactor loop (connect, keepalive ping, read → handler → ack, reconnect with backoff) wrapping `API#blaze_async`; extracted from `examples/blaze_async.rb` so the plugin shell stays thin and the loop is unit-testable offline.
- Handler resolution from `MixinBot` configuration, resolved lazily after app boot; explicit ack policy (on-receipt vs after-handler).
- Docs: README + `docs/agent/` section "Running Blaze inside Puma".
- No changes to existing `blaze` / `blaze_async` public APIs. No new gem dependencies; Puma is intentionally NOT added as a gem dependency (the plugin file is only loaded by Puma itself when `plugin :mixin_blaze` is present).

## Capabilities

### New Capabilities
- `blaze-puma-plugin`: Hosting the Blaze WebSocket connection inside a Puma-served process — mode selection (fork/async), Puma lifecycle integration and graceful shutdown, handler dispatch and ack policy, reconnection behavior, and required-environment constraints (preload_app in cluster mode).

### Modified Capabilities

## Impact

- **Code**: new `lib/puma/plugin/mixin_blaze.rb`; new `lib/mixin_bot/blaze/` (reactor loop + supervisor classes); existing `API#blaze_async` consumed as-is. Gemspec `s.files` glob (`lib/**/*`) already ships both paths.
- **Dependencies**: none added. Requires host Ruby >= 3.2 (already the gem floor) and a host running Puma (host-app concern, not a gem dependency).
- **Deployment constraints** (verified against Puma source): plugins run in the launcher process — cluster mode requires `preload_app!` for handler code to exist at loop start (must fail loudly if absent); fork mode inherits the preloaded app; phased restarts keep the master's loop/handler until a full restart.
- **Ops**: one connection per Puma master — eliminates duplicate-delivery risk from forgotten standalone processes only if the old process is removed; docs must call this out.
