## Purpose

Delivers every Mixin output (inbound and outbound transfer) to application processors exactly once, via a standalone polling process that tracks a cursor and deduplication receipts and dispatches work to the application's job queue.

## ADDED Requirements

### Requirement: Standalone polling loop process
The integration layer SHALL provide a polling process command that boots the application and loops: fetch a page of outputs from the outputs API ordered oldest-first, process new outputs, advance the cursor, sleep a configurable interval, repeat. The process SHALL shut down gracefully on SIGTERM/SIGINT, finishing the in-flight page before exiting. Polling parameters (interval, page size, asset filter, members/threshold) SHALL be configurable per bot.

#### Scenario: Loop runs until signalled
- **WHEN** the polling process is started and left running
- **THEN** it repeatedly fetches outputs and enqueues processing, and on SIGTERM it stops after completing the in-flight fetch

### Requirement: Cursor advances per bot and survives restarts
The poller SHALL persist a cursor per bot `app_id` and SHALL resume from that cursor after restart with no gap and no reliance on in-memory state. The cursor SHALL advance only after every output in a fetched page has been recorded; a failure mid-page SHALL leave the cursor at the previous value so the page is re-fetched.

#### Scenario: Restart resumes where it left off
- **WHEN** the poller restarts after having advanced to a cursor value C
- **THEN** its first fetch requests outputs after C and no output before C is re-enqueued for processing

### Requirement: Receipts deduplicate outputs
Each newly observed output SHALL be recorded in a receipts store keyed by bot `app_id` and output id under a uniqueness constraint, before any processing is enqueued. Outputs already recorded SHALL NOT be enqueued again, even when re-fetched due to cursor overlap, restart, or API timestamp skew. Receipt recording and enqueue SHALL race safely against concurrent pollers for the same bot.

#### Scenario: Same output fetched twice
- **WHEN** the outputs API returns an output the poller has already recorded
- **THEN** no new processing work is enqueued for it

### Requirement: Output envelope bridges to snapshot data
Processors SHALL receive an envelope exposing the output's amount (as a decimal number), asset id, state (spent or unspent), transaction hash and index, plus snapshot-derived fields — memo, counterparty, and trace id — fetched on demand from the snapshot notification API. If the snapshot lookup fails, the envelope SHALL expose nil memo with the failure logged, and the output SHALL still be processed; the snapshot data SHALL be fetched at most once per output.

#### Scenario: Memo-based routing
- **WHEN** a deposit output arrives whose snapshot memo matches a processor's predicate
- **THEN** that processor receives the envelope with the decoded memo and amount

### Requirement: Predicate processors dispatch through the job queue
Processors SHALL be application classes that answer a class-level predicate (`matches?`) against the envelope and implement a processing method. For each new output, the poller SHALL enqueue a job for every processor whose predicate matches, through the application's configured ActiveJob backend; outputs matching no processor SHALL be recorded only. Processor selection SHALL NOT require a central registry file.

#### Scenario: Two processors match one output
- **WHEN** an output's memo and amount satisfy two different processors' predicates
- **THEN** two jobs are enqueued, one per processor, each receiving the envelope

#### Scenario: No processor matches
- **WHEN** an output matches no processor predicate
- **THEN** the output is recorded as received and no job is enqueued

### Requirement: Outputs generator scaffolds the receipts store and an example processor
`rails generate mixin_bot:outputs` SHALL create the receipts migration (bot app id, unique output id, and snapshot reference columns), an example processor, and the polling process entry point, without manual editing. Running the generator a second time SHALL NOT duplicate migrations or entries.

#### Scenario: Generated setup processes a first payment
- **WHEN** a developer runs the generator, starts the poller and job queue, and a deposit arrives
- **THEN** the deposit is recorded and the example processor runs with memo, amount, and asset id available
