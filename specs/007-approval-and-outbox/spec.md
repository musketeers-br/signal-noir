# Feature Specification: Approval and the Transactional Outbox

**Feature Branch**: `007-approval-and-outbox`

**Created**: 2026-10-28

**Status**: Implemented

**Input**: `docs/specify-prompts/007-approval-and-outbox.txt`. Taken over by Henry from Henrique on
2026-10-28 to rebalance the waves (`docs/specify-prompts/PARALELISMO.md`).

## Context

An Operator approves or denies the exact Proposal a Case waits on. An approval is the only thing
that authorizes an Action with an external effect; it is durable, bound to one immutable Proposal,
and valid for a limited time. Every transition that needs follow-up work leaves that work in an
outbox written with the transition, and a single entry point carries it out at most once, even when
it is delivered again.

Already in place before this feature: the state machine and its actor table, the outbox record
written with every transition (003), the destinations after a denial (003), and the approval record
created by the Operator's review resolution (009). Revalidation and Execution are feature 008; the
Validator's rules and the BenchmarkRun store are features 004 and 010.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Approve the exact Proposal (Priority: P1) 🎯 MVP

An Operator sees a Case waiting for approval and approves the Proposal on screen. The Case is
approved, the approval names the Operator, the Proposal and its deadline, and the work that will
carry the Action out is queued with it. If anything changed since the screen was loaded, nothing is
recorded and the Operator is told why.

**Why this priority**: No effect may happen without it, and the console already offers the button.

**Independent Test**: Put a Case in `PendingApproval` with a current Proposal, approve it with the
current version, read the Case, its approvals, its Timeline and its pending work.

**Acceptance Scenarios**:

1. **Given** a Case in `PendingApproval` with Proposal P at version v, **When** an Operator approves
   P with version v, **Then** the Case is `Approved`, one approval binds P with the Operator, the
   moment and a deadline, the Timeline records it, one execution request is pending, and all of it
   survives a restart.
2. **Given** the same Case, **When** the Operator approves with an older version, or approves a
   Proposal that is no longer current, **Then** the answer is a version conflict that names the
   current Proposal and nothing is recorded.
3. **Given** a Case that is not waiting for approval, **When** an Operator approves, **Then** the
   answer is a state conflict and nothing is recorded.
4. **Given** a Case already `Approved` for P, **When** the same Proposal is approved again (even
   with an old version, even by another Operator), **Then** the existing approval is returned as a
   replay and nothing new is recorded or queued.
5. **Given** two Operators approving P at the same moment, **When** both requests arrive, **Then**
   exactly one approval exists and one execution request is queued; the other request receives the
   replay.
6. **Given** a request that is not well formed (unknown decision, no Operator name, a version that
   is not a whole number), **When** it arrives, **Then** it is refused as invalid and nothing is
   recorded.

---

### User Story 2 - Deny with a reason (Priority: P1)

An Operator disagrees with the Proposal and says why. The Case is rejected, the reason becomes
evidence for what happens next, and the system follows the limits fixed in 003: the first denial
starts a new investigation, the second sends the Case to human review.

**Why this priority**: Without a denial path the Operator can only approve or wait.

**Independent Test**: Deny a Case in `PendingApproval` with a reason, process its pending work,
read the Case, its evidence and its Timeline; repeat for a second denial.

**Acceptance Scenarios**:

1. **Given** a Case in `PendingApproval`, **When** an Operator denies without a reason, **Then** the
   request is refused as invalid and nothing is recorded.
2. **Given** a Case in `PendingApproval` (first denial), **When** an Operator denies with a reason,
   **Then** the Case is `Rejected`, the denial is recorded with the reason and no deadline, the
   reason is recorded as Evidence from the Operator, and follow-up work is queued; when that work is
   processed the Case goes to `Investigating` and the reason travels with the new investigation.
3. **Given** a Case denied once before, **When** it is denied again and its follow-up work is
   processed, **Then** the Case is in `ReviewRequired` with a Review Dossier and no new
   investigation is requested.

---

### User Story 3 - Approval has a deadline (Priority: P1)

An approval is valid for a limited time. An approval that expires before the Action is carried out
must never authorize it; the Case goes back to waiting for a new approval. New information that does
not falsify anything the Proposal relied on does not expire it.

**Why this priority**: A stale authorization is an unsafe authorization.

**Independent Test**: Approve, move the clock past the deadline, run the periodic sweep, read the
Case, the approval and the pending work.

**Acceptance Scenarios**:

1. **Given** an approved Case whose approval passed its deadline, **When** the periodic sweep runs,
   **Then** the approval is marked expired, the Timeline records the expiry by the sweeper, the Case
   is back in `PendingApproval`, and the queued execution request is discarded when processed.
2. **Given** that Case, **When** the Operator approves the same Proposal again, **Then** a new
   approval with a new deadline is recorded (an expired approval is never replayed).
3. **Given** an approved Case within its deadline, **When** new Evidence or a new Exception is
   recorded that falsifies no precondition, **Then** the approval stays valid.
4. **Given** an approval for a Proposal that a newer Proposal replaced, **When** the replacement is
   recorded, **Then** the old approval is marked superseded and can authorize nothing.

---

### User Story 4 - Follow-up work happens once (Priority: P1)

Every transition that needs work downstream leaves a request in the same commit. After the commit
the request is delivered to one entry point; a periodic sweep delivers again whatever is still
pending. The entry point handles each request at most once and ignores a request whose Case has
moved on since the request was written.

**Why this priority**: A committed decision that loses its downstream work is a silent failure; a
duplicated one is a double effect.

**Independent Test**: Commit a transition, deliver its request twice, deliver a request whose Case
moved on, lose a delivery and run the sweep.

**Acceptance Scenarios**:

1. **Given** a transition that needs follow-up work, **When** it commits, **Then** the new state,
   the Timeline event and the request exist together, or none of them do.
2. **Given** a pending request, **When** it is delivered twice (or by two processes at once),
   **Then** it is processed once; the second delivery does nothing.
3. **Given** a request whose Case has moved to another version, **When** it is delivered, **Then**
   it is discarded with a Timeline event saying why, and nothing else happens.
4. **Given** a request whose delivery was lost, **When** the periodic sweep runs, **Then** it is
   delivered again.
5. **Given** a request type whose handler belongs to a later feature (Execution), **When** it is
   delivered, **Then** it stays pending, unchanged, and is reported as waiting for its handler.
6. **Given** the authorization cannot be recorded (a storage failure in the same commit), **When**
   the Operator approves, **Then** nothing is recorded: no approval, no state change, no request.

---

### User Story 5 - Benchmark approval and actor rules (Priority: P2)

Inside a BenchmarkRun, approvals are automatic: the process that runs the Case approves on behalf of
the run, the approval says so, and nothing outside a run can do that. Every transition keeps its
authorized actors.

**Why this priority**: The benchmark needs unattended runs; the operation must never see them.

**Independent Test**: Route a Proposal that needs approval on a Case of a BenchmarkRun and on a
normal Case; try the benchmark actor outside a run.

**Acceptance Scenarios**:

1. **Given** a Case of a BenchmarkRun whose Proposal needs approval, **When** the Validator accepts
   it, **Then** the Case is approved by `benchmark`, the approval is labelled as automatic, and the
   execution request is queued, in the same commit.
2. **Given** a normal Case, **When** the same Proposal is accepted, **Then** the Case waits in
   `PendingApproval` for an Operator.
3. **Given** any Case outside a BenchmarkRun, **When** a transition is requested by the actor
   `benchmark`, **Then** it is refused with `INVALID_ACTOR` and nothing is recorded.
4. **Given** the decision entry point, **When** a request tries to act as `benchmark`, **Then** it
   cannot: the decision always acts as `operator:<name>`.
5. **Given** a Case in `PendingApproval`, **When** any path tries to reach `Approved` or `Rejected`
   without a recorded decision for the current Proposal, **Then** it is refused and nothing is
   recorded.

### Edge Cases

- Approving a Proposal whose Case moved to `Approved` through a different Proposal: version conflict
  (not a replay, which is only for the same Proposal).
- Denying twice in a row with the same request: the second finds the Case in `Rejected` and gets a
  state conflict.
- An approval replay after the Case moved on (e.g. `Executing`): still the replay, no new effect.
- A request type that does not exist: the entry point refuses it without changing it.
- The sweep finds an expired approval whose Case is no longer `Approved` (already executing): the
  Case is not touched; whether execution may proceed is decided by revalidation (008).
- A Case that is benchmark-flagged but whose Proposal needs no approval (`HOLD`): no automatic
  approval is recorded.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: An Operator MUST be able to approve or deny the current Proposal of a Case in
  `PendingApproval`, naming the Proposal and the Case version they saw.
- **FR-002**: An approval MUST record the Proposal, the decision, the author (`operator:<name>` or
  `benchmark`), the moment, and, for an approval, a deadline; a denial records its reason and no
  deadline.
- **FR-003**: An approval MUST be accepted only for the current Proposal at the current Case
  version; otherwise the answer is a version conflict naming the current Proposal, with nothing
  recorded. A Case not in `PendingApproval` MUST give a state conflict, with nothing recorded.
- **FR-004**: Approving a Proposal that already has a valid or used approval MUST return that
  approval as a replay, whatever the version sent, and record or queue nothing.
- **FR-005**: Concurrent approvals of the same Proposal MUST result in exactly one approval and one
  execution request.
- **FR-006**: A denial MUST require a reason. The reason MUST be recorded as Evidence from the
  Operator. The Case MUST become `Rejected` with follow-up work that, when processed, applies the
  003 destinations (first denial → new investigation carrying the reason; second → review).
- **FR-007**: `Approved` and `Rejected` MUST be reachable from `PendingApproval` only with a
  recorded decision for the current Proposal, in the same commit.
- **FR-008**: An approval MUST have a deadline (default 15 minutes until the 004 policy supplies
  it). Only the periodic sweep MAY expire it; expiry moves the Case back to `PendingApproval`,
  records the expiry, and the pending execution request is discarded when delivered.
- **FR-009**: An expired, superseded or denied approval MUST never be replayed and MUST never
  authorize anything. New Evidence alone MUST NOT expire an approval.
- **FR-010**: When a Proposal is replaced, its valid approvals MUST be marked superseded in the same
  commit.
- **FR-011**: Every transition that requires downstream work MUST write, in the same commit, the
  state, the Timeline event and a request carrying its id, type, Case and the Case version after
  the transition. No I/O inside that commit.
- **FR-012**: There MUST be a single entry point for requests. It MUST process each request at most
  once, MUST discard a request whose Case version differs from the version it carries (recording
  why), and MUST leave a request whose handler does not exist yet untouched and pending.
- **FR-013**: After the decision commits, the decision MUST deliver its request; a periodic sweep
  MUST deliver again any request still pending after a short grace period.
- **FR-014**: Inside a BenchmarkRun, a Proposal accepted by the Validator that needs approval MUST
  be approved automatically by `benchmark` in the same commit; outside one, the actor `benchmark`
  MUST receive `INVALID_ACTOR` on every transition. The decision entry point MUST NOT accept the
  `benchmark` actor.
- **FR-015**: If the approval, the transition or the request cannot be stored, none of them MUST be
  stored.
- **FR-016**: The decision answers MUST follow the contract: `201` with the approval and the Case
  acknowledgement (with the request id when one was queued), `200` with `idempotentReplay: true`
  for a replay, `400`, `403`, `404` and `409` with the closed error envelope.

### Key Entities

- **Approval**: a decision on one exact Proposal: decision, author, moment, deadline, status
  (valid, expired, consumed, superseded), reason.
- **Outbox request**: work queued by a transition: id, type, Case, Case version after, status
  (pending, dispatched, done), payload facts.
- **Sweep**: the single periodic job that redelivers pending requests and expires approvals.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 0 Cases reach `Approved` without a recorded approval of the current Proposal, across
  the whole test suite.
- **SC-002**: In repeated and concurrent approval tests, exactly 1 approval and 1 execution request
  exist per approved Proposal.
- **SC-003**: 100% of transitions that queue work commit state, event and request together; an
  injected storage failure leaves 0 of the three.
- **SC-004**: A request delivered twice, or after its Case moved on, causes 0 additional state
  changes.
- **SC-005**: An approval past its deadline authorizes 0 executions; after the sweep the Case waits
  for a new approval.
- **SC-006**: Every decision response conforms to the contract schemas (live contract check).

## Assumptions

- The approval deadline and the benchmark admission rule (`Admit(actor, run)`) are 004's surface.
  Until 004 merges, a default policy applies: 15 minutes, and `benchmark` is admitted only on a Case
  that carries a `runId`. The default sits behind one port that 004 replaces.
- The BenchmarkRun store is 010's; a Case's `runId` is set at intake (003) and is the provenance
  this feature reads.
- "Consumed" is set when an approval authorizes an execution, which is 008's step; this feature
  defines the status and never sets it.
- The handlers for `Execute`, `Reconcile`, `Expire` and `Resume` belong to 008 and 010; this
  feature routes `Investigate` and the follow-up of a denial.
- Calendar gate: same exception the user granted for 003, 005, 006, 009 and 009b, recorded in
  research.md.
