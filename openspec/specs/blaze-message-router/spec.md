## Purpose

Routes decoded Blaze message envelopes to application handler classes with a routing DSL, a decoded message object, and reply helpers, so applications stop hand-writing per-message dispatch inside a single lambda.

## Requirements

### Requirement: Route messages to handlers via a DSL
The integration layer SHALL provide a routing DSL where applications register handler classes against message keys (e.g. `on 'text', TextHandler`), and the router SHALL dispatch each decoded envelope to the handler registered for its message kind. When a message matches no route, the router SHALL ignore it and log the unmatched kind; unmatched messages SHALL NOT raise. Route registration order SHALL determine precedence: the first matching route wins.

#### Scenario: Registered kind is dispatched
- **WHEN** an envelope whose message kind has a registered handler arrives over Blaze
- **THEN** the router invokes that handler with a wrapped message object and the message is acknowledged per the configured ack policy

#### Scenario: Unmatched message is ignored
- **WHEN** an envelope whose kind has no registered route arrives
- **THEN** the router logs the unmatched kind and does not raise, and delivery of subsequent messages continues

### Requirement: Handlers receive a decoded message object
Handlers SHALL receive a message object exposing the decoded message data (data payload decoded from base64), the message kind, conversation id, sender and message ids, and the raw envelope. Handler exceptions SHALL be contained: logged, not propagated into the connection loop, and consistent with the reactor's handler-error behavior.

#### Scenario: Decoded payload is available
- **WHEN** a text message arrives with a base64-encoded data payload
- **THEN** the handler reads the decoded payload as plain text from the message object without decoding it itself

### Requirement: Handlers can reply over HTTP
The base handler SHALL provide a reply helper that sends a plain-text (or other category) message back to the message's conversation and sender using the HTTP message API, so handlers never need to hold or share the Blaze socket. Sending SHALL NOT require the Blaze connection to be in the same process.

#### Scenario: Replying from a handler
- **WHEN** a handler calls the reply helper with text content
- **THEN** a message is delivered to the originating conversation via the HTTP API and no WebSocket frame is written by the handler

### Requirement: Routing is bound to a bot API client
A router SHALL be constructible with an explicit API client, and reply/sends issued through its handlers SHALL use that client. Applications SHALL be able to run multiple routers, each with its own bot credentials, alongside each other in one process.

#### Scenario: Two bots in one process
- **WHEN** an application configures two bots and dispatches a message to each bot's router
- **THEN** each handler's replies are sent with its own bot's credentials and access tokens

### Requirement: Blaze generator scaffolds routing
`rails generate mixin_bot:blaze` SHALL create an initializer registering routes with at least one working example handler, and SHALL add the `mixin_blaze` Puma plugin line to the Puma configuration when not already present. Running the generator a second time SHALL NOT duplicate initializer registrations or Puma configuration lines.

#### Scenario: Generator output boots and routes
- **WHEN** a developer runs the generator and starts the application with the Puma plugin enabled
- **THEN** the example handler receives messages of its registered kind and the example reply is delivered
