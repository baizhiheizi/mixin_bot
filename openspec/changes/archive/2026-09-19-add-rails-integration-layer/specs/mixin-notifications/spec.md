## Purpose

Delivers application notifications as Mixin messages by providing a Noticed delivery channel, so applications can notify users through Mixin with the same notification classes they already use for other channels.

## ADDED Requirements

### Requirement: Mixin delivery channel for Noticed
The integration layer SHALL provide a Noticed delivery channel that sends a Mixin message (text, post, or app card) to a recipient determined by the notification class, using the HTTP message API with the bot's credentials. The channel SHALL follow Noticed's delivery contract, including per-delivery error capture: a failed Mixin delivery SHALL be recorded by Noticed's error handling without aborting sibling channels.

#### Scenario: Notification delivered as a Mixin message
- **WHEN** an application notification configured with the Mixin channel is delivered
- **THEN** the recipient receives the message content built by the notification class

#### Scenario: Delivery failure is captured, not raised
- **WHEN** the message API rejects the send
- **THEN** the failure is recorded on the delivery per Noticed's contract and other channels still deliver

### Requirement: Channel loads only with Noticed
The channel code SHALL load only when Noticed is already defined, and requiring the integration layer without Noticed SHALL neither raise nor add a dependency on Noticed. The generator SHALL add Noticed to the host Gemfile when it is absent.

#### Scenario: No Noticed in the bundle
- **WHEN** the integration layer is required in an application whose bundle does not include Noticed
- **THEN** boot succeeds and no notification code is loaded

### Requirement: Notifications generator scaffolds an example
`rails generate mixin_bot:notifications` SHALL add the Noticed dependency when absent, install the Mixin channel, and create one example notification configured for Mixin delivery. Running the generator a second time SHALL NOT duplicate Gemfile entries or files.

#### Scenario: Generated notification round-trips
- **WHEN** a developer runs the generator and delivers the example notification to a user id
- **THEN** that user receives the example message via the bot
