# Feature Specification: Order Intake and Case Lifecycle

**Feature Branch**: `003-order-case-lifecycle`

**Created**: 2026-10-25

**Status**: Draft

**Input**: User description: "Order intake and Case lifecycle." (full description:
`docs/specify-prompts/003-order-case-lifecycle.txt`)

## Context

Signal Noir watches synthetic lab Orders on their way from the Origin to the Partner. This feature
is the part that turns a failing Order into a durable Case and keeps that Case honest for the rest
of its life: it receives and checks Orders, opens a Case on the first Exception, holds the single
state machine every later feature moves through, records a Timeline that is never rewritten, and
serves the read views the Operator console and the Benchmark poll.

Its consumers are:

- **The inbound entry of the Production**, which hands over each Order read from the Origin feed
  and reports the outcome of each delivery attempt.
- **Later features** (Investigation, Validator, Approval, Execution, Review Dossier, Benchmark),
  which only ever change a Case through the transition and attachment commands defined here.
- **The Operator console and the Benchmark runner**, which read the Case list, the Case detail and
  the incremental Timeline under the normative contract `contracts/openapi-signalnoir.yaml`.

All data is synthetic and every projection says so. Investigation, Validator rules, Approval
decisions, Execution, the console screens and the Simulator are other features; this one defines
the states, the transitions, who may trigger each one and what must hold before and after.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - A synthetic Order is checked and correlated on arrival (Priority: P1)

The inbound entry hands over a synthetic Order as the Origin emitted it, together with the
Origin's transaction identifier. Signal Noir checks the Order's structure before anything is sent
to the Partner. A malformed Order is refused with a recorded reason and never reaches the Partner.
A well-formed Order is kept as an immutable snapshot, receives a correlation identifier and a
canonical equivalence key, and is tied to its business orderId and every transaction identifier
it has arrived with.

**Why this priority**: It is the first step of the tracer path. Invalid input must never reach the
Partner, and every later step depends on a stable, correlated Order.

**Independent Test**: Hand over one malformed and one well-formed Order. Check that the malformed
one is refused with a reason, produced no delivery attempt and no Case; check that the well-formed
one is stored unchanged, has a correlation identifier and a canonical equivalence key, and that the
same Order handed over again with another transaction identifier is correlated to the same record.

**Acceptance Scenarios**:

1. **Given** an Order missing a required field (for example no exam, no specimen, or a missing
   orderId), **When** it is handed over, **Then** it is refused with a reason naming the field, the
   refusal is recorded, no delivery attempt happens and no Case exists.
2. **Given** a well-formed Order, **When** it is handed over, **Then** it is accepted, its snapshot
   is stored exactly as received, it carries a correlation identifier and the transaction
   identifier it arrived with, and it is released for delivery.
3. **Given** two Orders whose equivalence-relevant fields differ only in exam-code order, letter
   case or the time-zone offset of the collection time, **When** both are accepted, **Then** their
   equivalence keys are identical.
4. **Given** an Order already accepted, **When** the same orderId arrives again with a different
   transaction identifier, **Then** the existing Order record gains the new transaction identifier,
   its original snapshot is unchanged, and no second Order record exists.
5. **Given** an Order that carries free text resembling an instruction, **When** it is accepted,
   **Then** the text is kept as data in the snapshot and changes nothing in how the Order is
   processed.

---

### User Story 2 - The first Exception opens a Case; later Exceptions join it (Priority: P1)

When a delivery attempt for an accepted Order ends without a valid Receipt, that is an Exception.
The first Exception of an Order opens a Case in `Open`, with the Order snapshot, the Exception and
the correlation identifiers, and the Timeline shows the failure. A further Exception for the same
orderId while its Case is not terminal joins that Case instead of opening another one. An Exception
after the Case has reached a terminal state starts a new episode: a new Case, related to the
previous one, which stays terminal.

**Why this priority**: The Case is the unit everything else works on. "One live Case per Order" and
"terminal never reopens" are the two rules the rest of the system relies on.

**Independent Test**: Feed one accepted Order a failed delivery, then a second failure, then
drive its Case to a terminal state and feed a third failure. Count Cases and read the Timelines.

**Acceptance Scenarios**:

1. **Given** an accepted Order, **When** a delivery attempt succeeds with a valid Receipt, **Then**
   no Case is opened.
2. **Given** an accepted Order, **When** a delivery attempt fails (timeout, HTTP error, success
   status without a valid Receipt, business rejection or processing error), **Then** one Case is
   opened in `Open`, and its Timeline shows the Case opening and the Exception with its kind,
   status, body and the moment it was observed.
3. **Given** a Case that is not terminal, **When** another Exception for the same orderId arrives,
   **Then** it is appended to that Case, the Case lists two Exceptions, and no second Case exists.
4. **Given** a Case in a terminal state, **When** a new Exception for the same orderId arrives,
   **Then** a new Case is opened that references the previous Case, and the previous Case is
   unchanged.
5. **Given** two Exceptions for the same orderId arriving at the same moment and no Case yet,
   **When** both are processed, **Then** exactly one non-terminal Case exists and it holds both
   Exceptions.
6. **Given** two different Orders that both fail, **When** their Exceptions are processed,
   **Then** two Cases exist.

---

### User Story 3 - One state machine, with visible losers (Priority: P1)

Every change of a Case's state goes through one state machine. Each transition names its origin,
its destination, the actors allowed to trigger it, its preconditions, the Timeline event it
writes and the follow-up work it schedules. A transition that is not in the table, or is asked by
an actor not allowed for it, is refused and nothing is written. A writer whose expected Case
version, expected state or expected target no longer holds loses visibly and writes nothing; the
new state, its Timeline event and its follow-up work are always written together or not at all.

**Why this priority**: "Two writers can never both win the same transition" is a success criterion
of this feature and a guarantee every later feature (Approval, Execution, sweeper) depends on.

**Independent Test**: Drive a Case along a path of allowed transitions, then try a forbidden
transition, a transition by an unauthorized actor, and two concurrent transitions from the same
version. Read the Case and Timeline after each step.

**Acceptance Scenarios**:

1. **Given** a Case in `Open`, **When** the system moves it to `Investigating`, **Then** the state
   changes, the Case version increases by one, the Timeline shows a state change from `Open` to
   `Investigating` with the actor and the new version, and an investigation request is pending.
2. **Given** a Case in `Open`, **When** any actor asks to move it to `Executing`, **Then** the
   request is refused as an invalid transition and the Case, its version and its Timeline are
   unchanged.
3. **Given** a Case in `PendingApproval`, **When** the `agent` actor asks to move it to
   `Approved`, **Then** the request is refused as an unauthorized actor and nothing is written.
4. **Given** a Case read at version 7, **When** another writer has already moved it to version 8
   and a command arrives expecting version 7, **Then** the command is refused as stale, the
   response carries the current version, state, last event sequence and server time, and nothing
   is written.
5. **Given** two commands that both expect the same version and the same state of one Case,
   **When** they are processed concurrently, **Then** exactly one succeeds and the other is refused
   as stale.
6. **Given** a transition whose write fails part-way, **When** the failure happens, **Then** neither
   the new state, nor its Timeline event, nor its follow-up work is visible.
7. **Given** a Case in a terminal state, **When** any actor asks for any transition, **Then** it is
   refused; only a new Exception can start a new, related Case.
8. **Given** a Case in `Held`, **When** any actor asks to move it anywhere except `Investigating`,
   **Then** it is refused.

---

### User Story 4 - Cases survive a restart (Priority: P2)

The persisted Case is the truth. After a restart, every Case is back in the same state, with the
same version, the same Timeline and the same pending follow-up work. A Case that was interrupted in
the middle of an investigation does not stay orphaned in `Investigating`.

**Why this priority**: Restarts are normal. Without durability no other guarantee survives a demo.

**Independent Test**: Create Cases in `Open`, `Investigating`, `PendingApproval` and `Held`,
restart, and compare state, version, Timeline and pending work with the snapshot taken before.

**Acceptance Scenarios**:

1. **Given** Cases in `Open`, `PendingApproval` and `Held` with their Timelines, **When** the
   system restarts, **Then** each reappears in the same state, with the same version and an
   identical Timeline.
2. **Given** a Case in `Investigating` whose investigation was interrupted by the restart, **When**
   the system comes back, **Then** the Case moves to `ReviewRequired` with the reason "investigation
   interrupted", recorded on its Timeline.
3. **Given** follow-up work recorded but not yet picked up before the restart, **When** the system
   comes back, **Then** the work is still pending and is picked up once.

---

### User Story 5 - Read views for the console and the Benchmark (Priority: P2)

The Operator console and the Benchmark read Cases through three views: a Case list paged by
cursor, which can also be polled for what changed since a cursor; a Case detail; and a Timeline
read incrementally from a known sequence number. Every response carries the Case version, the last
event sequence and the server time, and every Case is labelled synthetic.

**Why this priority**: The console and the Benchmark cannot exist without these views; they come
after the write path because they only report what it recorded.

**Independent Test**: Create several Cases, page through the list, poll it for changes, open a
detail, read a Timeline from sequence 0 and then from the last sequence seen, and validate every
response against `contracts/openapi-signalnoir.yaml`.

**Acceptance Scenarios**:

1. **Given** more Cases than one page holds, **When** the list is read page by page with the
   returned cursor, **Then** every Case appears exactly once, newest activity first.
2. **Given** a list cursor taken earlier, **When** the list is polled for newer changes, **Then**
   every Case that changed since the cursor appears, oldest change first, and a cursor for the next
   poll is returned.
3. **Given** a Case, **When** its detail is read, **Then** it shows the Order, its Exceptions, its
   Case version, its last event sequence, its labels (`synthetic` true, `replay` as recorded), the
   current Proposal and pending Approval when any, and the outcome of its latest Execution or none.
4. **Given** a Timeline read up to sequence N, **When** it is read again from N, **Then** only
   events after N are returned, in ascending order, and the reader is told whether more remain.
5. **Given** an event whose write started before another event but was confirmed after it, **When**
   the Timeline is polled incrementally, **Then** the reader never skips it: an event becomes
   visible only once every event with a lower sequence number is visible.
6. **Given** an unknown caseId, **When** its detail or Timeline is read, **Then** the response is a
   not-found error, not an empty success.
7. **Given** any list, detail or Timeline response, **When** it is checked against
   `contracts/openapi-signalnoir.yaml`, **Then** it conforms.

---

### User Story 6 - Rejection and expiry have a destination and a limit (Priority: P3)

A rejected Proposal does not loop forever: after the first rejection the Case goes back to a new
Investigation carrying the reason as Evidence; after the second it goes to `ReviewRequired`. An
expired Approval never authorizes anything: the Case goes back to a state that needs a new
Approval, and the expired one cannot be reused.

**Why this priority**: These rules bound the lifecycle. They matter once Approval (feature 007)
exists; this feature fixes their destinations and limits so 007 only has to call them.

**Independent Test**: Drive a Case to `Rejected` twice through the transition commands, and drive
another to `Approved` and expire it, reading state, rejection count and Timeline after each step.

**Acceptance Scenarios**:

1. **Given** a Case rejected for the first time, **When** the rejection is processed, **Then** the
   Case moves to `Investigating`, its rejection count is 1, and a new investigation request is
   pending that carries the rejection reason, so the Investigation can record it as Evidence.
2. **Given** a Case rejected for the second time, **When** the rejection is processed, **Then** the
   Case moves to `ReviewRequired` with the reason "second rejection", and no new investigation is
   requested.
3. **Given** a Case in `Approved` whose Approval deadline has passed, **When** the expiry is
   processed by the sweeper, **Then** the Case moves to `PendingApproval`, the Timeline records the
   expiry, and the expired Approval can no longer authorize an Execution.
4. **Given** a Case in `Approved`, **When** any actor other than the sweeper asks for the expiry
   transition, **Then** it is refused as an unauthorized actor.

---

### Edge Cases

- An Order whose `synthetic` flag is missing or false is refused at intake: only synthetic data is
  accepted.
- An Order with a collection time that cannot be read as a timestamp is refused at intake; the
  equivalence key is never computed from a guess.
- An Exception reported for an orderId that was never accepted is refused and recorded; it does not
  open a Case.
- A new Exception that arrives while the Case is in `Approved` or `Executing` is attached to the
  Case and does not change its state; it is visible for later reassessment.
- A new Exception that arrives while the Case is `Investigating` is attached and does not start a
  second investigation.
- A new Exception on any other non-terminal Case (`Open`, `DecisionProposed`, `PendingApproval`,
  `Rejected`, `Held`, `ReviewRequired`) is attached and moves the Case to `Investigating`.
- A list cursor that cannot be decoded is refused as invalid input, not treated as "start over".
- A Timeline read with a negative or non-numeric `sinceSeq` is refused as invalid input.
- An attachment (Evidence, Exception during Execution, annotation) advances the last event
  sequence and the last activity time but never the Case version.
- The Timeline is never edited or shortened: correcting a fact is a new event.

## Requirements *(mandatory)*

### Functional Requirements

**Intake and correlation**

- **FR-001**: The system MUST receive synthetic Orders in the Origin's Order shape through one
  defined inbound entry point, together with the Origin's transaction identifier.
- **FR-002**: The system MUST check an Order's structure before any delivery attempt. Required:
  orderId, partnerId, patient with patientId, at least one exam with a code, specimen with
  specimenId and a readable collection time, request time, and `synthetic` true.
- **FR-003**: A structurally invalid Order MUST be refused with a recorded reason naming what is
  wrong, and MUST produce no delivery attempt, no Order record and no Case.
- **FR-004**: An accepted Order MUST keep an immutable snapshot exactly as received, including
  fields the system does not use.
- **FR-005**: Every accepted Order MUST receive a correlation identifier carried by every later
  event and record about it, and MUST keep every transaction identifier it has arrived with.
- **FR-006**: The equivalence key MUST be computed only by the core rules from patientId, exam
  codes (deduplicated, ordered, case-normalized), collection time (normalized to UTC) and
  specimenId. It MUST be deterministic.
- **FR-007**: The same orderId arriving again MUST be correlated to the existing Order record, not
  duplicated; its snapshot MUST NOT change.
- **FR-008**: Text inside an Order MUST be treated as data and MUST NOT change processing.

**Exceptions and Case opening**

- **FR-009**: A delivery attempt that does not end with a valid Receipt MUST be recorded as an
  Exception of one closed kind: `timeout`, `http_error`, `invalid_receipt`, `business_rejection` or
  `processing_error`, with status, body, the moment observed and the attempt reference.
- **FR-010**: The first Exception of an Order MUST open a Case in `Open` holding the Order, the
  Exception and the correlation identifiers; the Timeline MUST show the opening and the Exception.
- **FR-011**: At most one non-terminal Case MUST exist per orderId at any moment, including under
  concurrent Exceptions.
- **FR-012**: An Exception for an orderId whose Case is non-terminal MUST be appended to that Case.
  It moves the Case to `Investigating` only from `Open`, `DecisionProposed`, `PendingApproval`,
  `Rejected`, `Held` or `ReviewRequired`; in `Investigating`, `Approved` or `Executing` it is an
  attachment only.
- **FR-013**: An Exception for an orderId whose latest Case is terminal MUST open a new Case that
  references the previous one; the previous Case MUST stay unchanged.

**State machine**

- **FR-014**: The Case MUST use exactly these states: `Open`, `Investigating`, `DecisionProposed`,
  `PendingApproval`, `Approved`, `Rejected`, `Executing`, `Held`, `ReviewRequired`, `Resolved`,
  `ResolvedByPriorReceipt`, `Cancelled`, `Failed`. `Resolved`, `ResolvedByPriorReceipt`,
  `Cancelled` and `Failed` are terminal.
- **FR-015**: Only the transitions in the table below MUST be allowed, each only for its listed
  actors. Any other transition MUST be refused as an invalid transition; an unlisted actor MUST be
  refused as unauthorized. A refusal writes nothing.

  | From | To | Authorized actors | Trigger | Follow-up work |
  |---|---|---|---|---|
  | (none) | `Open` | system | First Exception of the Order | — |
  | `Open` | `Investigating` | system | Case routed to Investigation | investigate |
  | `Open` | `ReviewRequired` | system | No investigation possible (e.g. provider unavailable) | — |
  | `Investigating` | `DecisionProposed` | agent, rules, replay | Proposal recorded | — |
  | `Investigating` | `ReviewRequired` | system | Budget exceeded, invalid answer, provider unavailable, interrupted by restart | — |
  | `Investigating` | `ResolvedByPriorReceipt` | system | Validator confirms a prior Receipt | — |
  | `DecisionProposed` | `ResolvedByPriorReceipt` | system | Validator confirms a prior Receipt | — |
  | `DecisionProposed` | `PendingApproval` | system | Validator accepts, Approval required | — |
  | `DecisionProposed` | `Executing` | system | Validator accepts, no Approval required | execute |
  | `DecisionProposed` | `ReviewRequired` | system | Validator blocks or asks for review | — |
  | `PendingApproval` | `Approved` | operator:\<name\>, benchmark | Approval recorded | execute |
  | `PendingApproval` | `Rejected` | operator:\<name\>, benchmark | Rejection recorded | — |
  | `Rejected` | `Investigating` | system | First rejection | investigate |
  | `Rejected` | `ReviewRequired` | system | Second rejection | — |
  | `Approved` | `Executing` | system | Revalidation passed | — |
  | `Approved` | `Held` | system | Revalidation: Partner unstable or maintenance window | — |
  | `Approved` | `Cancelled` | system | Revalidation: Order cancelled at the Origin | — |
  | `Approved` | `PendingApproval` | sweeper | Approval expired or a declared precondition became false | — |
  | `Executing` | `Held` | system | `HOLD` executed | — |
  | `Executing` | `Resolved` | system | Valid Receipt, directly or through Reconciliation | — |
  | `Executing` | `Failed` | system | Policy attempts exhausted | — |
  | `Held` | `Investigating` | sweeper | Reassessment: the waiting condition ended | investigate |
  | `ReviewRequired` | `DecisionProposed` | operator:\<name\> | Operator resolution with an Action | — |
  | `ReviewRequired` | `Cancelled` | operator:\<name\> | Operator resolution cancelling the Case | — |
  | `Open`, `DecisionProposed`, `PendingApproval`, `Rejected`, `Held`, `ReviewRequired` | `Investigating` | system | New Exception of the same Order | investigate |

- **FR-016**: Terminal states MUST NOT be left by any transition. `Held` MUST be left only towards
  `Investigating`.
- **FR-017**: Each transition MUST record a Timeline event stating origin state, destination
  state, actor, reason and the Case version after the change.
- **FR-018**: A transition MUST commit its new state, its Timeline event and its follow-up work
  record together, in one short unit that performs no external call; a failure MUST leave none of
  them visible.
- **FR-019**: A transition command MUST state the Case version it expects, and MAY state the state
  and the target record (Proposal or Execution) it expects. If any expectation no longer holds, the
  command MUST be refused as stale, MUST write nothing, and the refusal MUST report the current
  version, state, last event sequence and server time.
- **FR-020**: Of two commands expecting the same version of the same Case, at most one MUST
  succeed.
- **FR-021**: A transition MUST increase the Case version by exactly one. An attachment MUST NOT
  change the Case version or the state.

**Records and Timeline**

- **FR-022**: Order, Exception, Evidence, Diagnosis, Proposal, Approval, Execution and Receipt MUST
  be separate records linked to their Case; this feature creates the Order and Exception records
  and the links, and leaves the others to their features.
- **FR-023**: The Timeline MUST be append-only. Each event MUST carry a sequence number unique and
  increasing within its Case and never reused, a UTC timestamp, a type from the contract's closed
  event types, an actor, a reference to the related record when there is one, and a factual
  payload with no secret.
- **FR-024**: The Case MUST count rejections. The first rejection leads to `Investigating` with the
  reason handed to the new investigation, which records it as Evidence; the second leads to
  `ReviewRequired`. The count MUST NOT exceed 2.
- **FR-025**: An expired Approval MUST NOT authorize anything after expiry; only the sweeper may
  apply the expiry transition.

**Durability**

- **FR-026**: Orders, Cases, Exceptions, Timelines and pending follow-up work MUST survive a
  restart unchanged.
- **FR-027**: After a restart, a Case left in `Investigating` by an interrupted investigation MUST
  move to `ReviewRequired` with the reason "investigation interrupted".

**Read views**

- **FR-028**: The system MUST provide a Case list paged by an opaque cursor over (last activity
  time, caseId): newest first by default, or ascending changes since a cursor for polling, with a
  head cursor for the next poll, and the filters the contract defines (state, status, pending
  approval, run, include benchmark).
- **FR-029**: The system MUST provide a Case detail with the Order, its Exceptions, labels, Case
  version, last event sequence, current Proposal and pending Approval when any, rejection count and
  latest Execution outcome or none.
- **FR-030**: The system MUST provide the Timeline of a Case from a given sequence number, ascending,
  with a page limit, a "more remain" flag and the next sequence to ask for.
- **FR-031**: An incremental Timeline reader MUST never miss an event: an event MUST NOT become
  visible before every event of the same Case with a lower sequence number is visible.
- **FR-032**: Every list, detail and Timeline response MUST carry the Case version (per Case), the
  last event sequence and the server time, MUST label every Case as synthetic, and MUST conform to
  `contracts/openapi-signalnoir.yaml`.
- **FR-033**: Failures MUST be returned as result values with a code from the contract's closed
  list (`STALE_VERSION`, `INVALID_TRANSITION`, `INVALID_ACTOR`, `VALIDATION_FAILED`, `NOT_FOUND`);
  a refusal MUST NEVER appear as success.

### Key Entities

- **Order**: a synthetic lab Order as received. Immutable snapshot, business orderId, partnerId,
  correlation identifier, the transaction identifiers it arrived with, canonical equivalence key,
  arrival time, synthetic label.
- **Intake refusal**: the record of an Order refused at intake: reason, the moment, and whatever
  identifier the input carried. Never becomes a Case.
- **Exception**: a delivery attempt that did not end with a valid Receipt: kind, status, body (data,
  never instruction), the moment observed, attempt reference, whether it arrived during Execution.
- **Case**: one resolution episode of one Order. State, Case version, last event sequence, last
  activity time, labels, rejection count, review reason when in `ReviewRequired`, reference to the
  previous Case when it is a new episode.
- **Timeline event**: an append-only fact about a Case: sequence, time, type, actor, related
  record, payload.
- **Follow-up work**: a pending request (investigate, execute, and later kinds) created by a
  transition together with it, consumed once.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 100% of structurally invalid Orders in the test set are refused with a reason, and 0
  of them produce a delivery attempt or a Case.
- **SC-002**: For every failing Order in the test set, exactly one non-terminal Case exists at any
  time, and its Timeline contains the opening and every Exception, in order.
- **SC-003**: In repeated concurrent trials (at least 100) of two writers on the same Case version,
  exactly one writer wins every time and the loser writes nothing.
- **SC-004**: After a restart, 100% of Cases match their pre-restart state, version, Timeline and
  pending work, except Cases interrupted in `Investigating`, which are all in `ReviewRequired` with
  the reason "investigation interrupted".
- **SC-005**: An incremental Timeline reader polling while events are written, including events
  confirmed out of start order, ends with exactly the full Timeline: no gap, no duplicate.
- **SC-006**: 100% of list, detail and Timeline responses produced by the test suite validate
  against `contracts/openapi-signalnoir.yaml` and label the Case as synthetic.
- **SC-007**: Every transition not in the table, and every allowed transition asked by an
  unauthorized actor, is refused in the test suite with no write.

## Assumptions

- The Order shape is the Origin's synthetic Order of `contracts/openapi-sim.yaml`; the transaction
  identifier and run identifier come from the feed envelope.
- The first delivery of an accepted Order is part of intake and goes through the Partner port; it
  is not an Execution and needs no Approval. Its classification as success or Exception uses the
  same closed Exception kinds. Execution, retries under a Policy and Reconciliation are feature 008.
- The link from a new-episode Case to the previous one is recorded in the new Case's opening
  Timeline event, because the contract's Case detail has no field for it; no contract change is
  needed for the behavior.
- The rejection reason travels as Evidence; producing Evidence records belongs to Investigation and
  Approval (006/007). This feature fixes the count, the destinations and the attachment path.
- Expiry returns the Case to `PendingApproval` (PRD FR-18): the Proposal stays, a new Approval is
  required, and the expired one is void. Whether the Proposal must also be re-issued is decided by
  feature 007 within this destination.
- The PRD's architecture note that a failed Execution with Exceptions attached during it is
  reassessed (`Failed` → `Investigating`) conflicts with the Constitution (terminal states never
  reopen). The Constitution prevails: such Exceptions stay on the `Failed` Case, and a later
  Exception opens a related Case.
- The actors are those of the contract: `system`, `agent`, `rules`, `replay`, `benchmark`,
  `sweeper` and `operator:<name>`. Automatic Approval by `benchmark` is only allowed inside a
  Benchmark run; enforcing that is feature 010.
- Investigation interrupted by restart is detected at start-up from persisted state; the timing of
  that check belongs to the Production start, already in place from feature 001.
