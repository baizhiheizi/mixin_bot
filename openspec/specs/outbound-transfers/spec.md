## Purpose

Sends assets to users through a persisted transfer ledger: creating a transfer record enqueues a job that executes the Safe transaction pipeline exactly once per trace, records the outcome in the record's state, and reconciles unknown outcomes before any retry.

## Requirements

### Requirement: Transfer records drive sending
Applications SHALL create a transfer record with recipient, asset, amount, memo, and trace id; record creation SHALL enqueue execution through the application's job queue. The generated model SHALL remain application-owned: applications can add columns and callbacks without touching gem code.

#### Scenario: Creating a record sends the transfer
- **WHEN** the application creates a transfer record with recipient, asset id, amount, and trace id
- **THEN** a job executes the Safe transfer pipeline with those parameters using the bot's API client

### Requirement: Transfer state machine
A transfer record SHALL progress through pending, broadcast, and a terminal state of confirmed or failed. A transfer whose send attempt ends with an indeterminate result (timeout, connection loss after submission) SHALL enter a reconciling state instead of failed. State transitions SHALL be recorded with the outcome (including the transaction hash and any error) on the record.

#### Scenario: Successful send
- **WHEN** the pipeline submits the transaction and the network accepts it
- **THEN** the record reaches confirmed with the transaction hash stored

#### Scenario: Rejected send
- **WHEN** the pipeline fails with a definitive error (insufficient funds, invalid request)
- **THEN** the record reaches failed with the error captured, and no retry re-sends funds

### Requirement: Trace id idempotency and reconciliation
All send attempts for one transfer record SHALL reuse the record's trace id, so network-side deduplication makes retries safe. A transfer in the reconciling state SHALL be resolved by looking up the trace id's snapshot before any further send attempt: if a snapshot exists the record becomes confirmed from the snapshot; only when no snapshot exists may the send be retried with the same trace id. The reconciliation SHALL be executable as a recurring job.

#### Scenario: Timeout after submission
- **WHEN** a send attempt times out after the transaction was submitted and the record enters reconciling
- **THEN** reconciliation finds the trace's snapshot and marks the record confirmed without sending again

#### Scenario: Safe retry after indeterminate failure
- **WHEN** reconciliation finds no snapshot for the trace id
- **THEN** the transfer is re-sent with the same trace id, and the network's deduplication prevents a double spend

### Requirement: Transfers generator scaffolds the ledger
`rails generate mixin_bot:transfers` SHALL create the transfers migration (recipient, asset id, amount, memo, trace id with uniqueness, state, transaction hash, error columns), a model that includes the runtime transfer behavior, and the execution job. Running the generator a second time SHALL NOT duplicate migrations or entries.

#### Scenario: Generated ledger round-trips a payment
- **WHEN** a developer runs the generator and creates a transfer record for a funded bot
- **THEN** the transfer is broadcast and the record ends confirmed with its transaction hash
