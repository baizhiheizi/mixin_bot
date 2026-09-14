## Purpose

Lets a mixin_bot application receive Blaze messages from inside its Puma web process tree — forked child or hosting thread — so that no standalone Blaze process needs to be deployed, supervised, or kept alive separately.

## Requirements

### Requirement: Plugin activation establishes a Blaze connection at boot
When a Puma configuration contains `plugin :mixin_blaze`, the server SHALL establish a Blaze WebSocket connection as part of Puma boot, without any further user configuration. When the connection is established, the plugin SHALL log the hosting process ID through Puma's log writer so operators can detect accidental duplicate connections.

#### Scenario: Minimal activation
- **WHEN** a Puma configuration contains only `plugin :mixin_blaze` and the server boots with mixin_bot credentials configured
- **THEN** a Blaze WebSocket connection is established and logged with the hosting PID

#### Scenario: Gem remains loadable without Puma
- **WHEN** the mixin_bot gem is required in a process where Puma is not installed
- **THEN** no error is raised and no plugin code is loaded

### Requirement: Received messages are dispatched to the configured handler
Messages received over the Blaze connection SHALL be decoded and delivered to the handler configured by the application. Handler resolution MUST be deferred until the host application has finished booting, so handlers may reference application code (models, services). Decoded envelopes and transport framing MUST be consistent with the existing `blaze_async` wire contract (gzip+JSON frames, `LIST_PENDING_MESSAGES` requested on open, `MESSAGE_ACK` per received message unless the ack policy defers it).

#### Scenario: Handler receives a message
- **WHEN** a Blaze message arrives for the app and a handler is configured
- **THEN** the handler is invoked with the decoded message envelope

#### Scenario: Handler is resolved after app boot
- **WHEN** the handler is defined in application code that loads during app initialization
- **THEN** the handler is available to the plugin and is invoked for messages arriving after boot

### Requirement: Run mode selects between forked child and in-process thread
The plugin SHALL support two run modes selected by a Puma configuration option:
- **fork** (default): the connection is hosted in a dedicated child process forked from the Puma launcher after boot.
- **async**: the connection is hosted in a background thread inside the Puma process itself, running its own fiber reactor.

#### Scenario: Default mode forks a child
- **WHEN** the plugin is activated without an explicit mode
- **THEN** the Blaze connection lives in a child process distinct from the Puma master/worker processes

#### Scenario: Async mode hosts the connection in-process
- **WHEN** the mode is configured to async
- **THEN** the Blaze connection lives in the Puma process itself (a background thread), with no child process spawned

### Requirement: Connection survives disconnects via automatic reconnection
When the Blaze connection drops (server close, network error, EOF), the plugin SHALL reconnect automatically with bounded exponential backoff, and SHALL request pending messages again upon reconnect. The connection MUST NOT be left in a state where a transient drop permanently ends message delivery for the process lifetime.

#### Scenario: Server closes the connection
- **WHEN** the Blaze server closes the connection while the host process is running
- **THEN** the plugin reconnects after a bounded delay and pending messages resume delivery

### Requirement: The connection is kept alive during quiet periods
The plugin SHALL send WebSocket pings on an interval while the connection is idle, so that intermediaries and the Blaze server do not drop a healthy but quiet connection.

#### Scenario: Idle connection stays alive
- **WHEN** no messages arrive for longer than the keepalive interval
- **THEN** the plugin continues sending pings and the connection remains established

### Requirement: Graceful shutdown tears down the connection and child
When Puma stops (SIGTERM/SIGINT) or restarts, the plugin SHALL close the Blaze connection cleanly, and in fork mode SHALL terminate the forked child. No Blaze child process SHALL outlive the Puma process.

#### Scenario: SIGTERM stops the child
- **WHEN** Puma receives SIGTERM while a forked Blaze child is running
- **THEN** the child is terminated and the WebSocket connection is closed before exit

#### Scenario: Restart re-establishes the connection
- **WHEN** Puma performs a hot restart (SIGUSR2)
- **THEN** the new Puma process establishes a fresh Blaze connection and the old one does not survive

### Requirement: A dead forked child stops Puma
In fork mode, if the Blaze child process dies while the plugin is active, the plugin SHALL stop the Puma process (as Solid Queue's plugin does), so that a process manager restarts the whole unit rather than serving requests while message reception is silently down.

#### Scenario: Child crashes
- **WHEN** the forked Blaze child exits unexpectedly
- **THEN** the plugin stops Puma, and the operator's process manager brings the unit back up with a fresh child

### Requirement: Handler failures do not end message delivery
An exception raised inside a message handler SHALL be reported (logged) without terminating the reactor loop, and the loop SHALL continue with subsequent messages.

#### Scenario: Handler raises
- **WHEN** a message handler raises an exception
- **THEN** the error is logged, the connection stays up, and subsequent messages are still delivered

### Requirement: Acknowledgement policy is explicit
The plugin SHALL support two acknowledgement policies:
- **on receipt** (default): each message is acknowledged to Mixin immediately on receipt, before the handler runs (at-most-once dispatch).
- **after handler**: a message is acknowledged only after its handler completes without raising (at-least-once dispatch; handlers must be idempotent because unacknowledged messages are redelivered on reconnect).

#### Scenario: Ack after handler failure
- **WHEN** the policy is after-handler and the handler raises
- **THEN** the message is not acknowledged and is redelivered after reconnect

### Requirement: Missing preconditions fail loudly
If the plugin is activated in an environment that cannot host the loop — notably Puma cluster mode without `preload_app!`, where the launcher process has no application code — the plugin SHALL report a clear, actionable error at boot (naming the fix) instead of starting a loop that cannot resolve handlers. The plugin SHALL NOT silently deliver zero messages in such an environment.

#### Scenario: Cluster mode without preload
- **WHEN** `plugin :mixin_blaze` runs in Puma cluster mode (workers > 0) without `preload_app!`
- **THEN** boot reports an explicit error instructing the operator to enable `preload_app!` (or drop to single mode)

#### Scenario: No handler configured
- **WHEN** the plugin activates but no message handler has been configured
- **THEN** boot reports a clear error naming the configuration entry that must be set
