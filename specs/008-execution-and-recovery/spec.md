# Feature Specification: Safe Execution and Recovery

**Feature Branch**: `008-execution-and-recovery`

**Created**: 2026-10-28

**Status**: Implemented

**Input**: `docs/specify-prompts/008-execution-and-recovery.txt`. Taken over by Henry from Henrique on
2026-10-28, so that Henrique can focus on 004 (`docs/specify-prompts/PARALELISMO.md`).

## Context

An approved Action reaches the Partner through one path only. Immediately before the effect, the
system rechecks that the conditions the Operator approved still hold. It asks the Partner whether
the effect already happened, sends once with a key that identifies the effect, and settles the
outcome against the Partner's Receipt. When the answer is uncertain, nothing new is sent until the
system has asked the Partner what happened. Restarts, late workers, repeated commands and repeated
clicks never produce a second effect.

Already in place before this feature:
- the state machine and its actor table (003);
- approvals with deadlines, the outbox and the single entry point for requests (007);
- the Simulator with its Partner, Receipts, health and Origin status (002);
- the first delivery of each Order, made when the Order arrives from the Origin (002 G1 notes).

The Validator's rules and the versioned policies and mappings are feature 004. Until 004 merges, a
default revalidation rule applies behind a port that 004 replaces, as the Validator did for 006.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - An approved Action reaches the Partner once (Priority: P1) 🎯 MVP

An Operator approved a resend. The system rechecks the Partner and the Order, records that the
execution is authorized, checks that the Partner has no Receipt for the Order yet, sends once and
records the Partner's Receipt. The Case is resolved and its Timeline tells the whole story.

**Why this priority**: It is the effect the whole workflow exists for, and the end of the tracer
path.

**Independent Test**: Approve a resend on a Case whose Partner accepts it, deliver the execution
request, read the Case, its execution, its Receipt and its Timeline, and ask the Partner how many
Receipts it holds for the Order.

**Acceptance Scenarios**:

1. **Given** an `Approved` Case for a resend, with a healthy Partner and an active Order, **When**
   its execution request is processed, **Then**:
   - one execution is recorded, bound to the approval and the Proposal, with an effect key and a
     lease;
   - the Case moves to `Executing`, then `Resolved`;
   - the Case holds a copy of the Partner's Receipt;
   - the Timeline records, in order: the revalidation, the authorization, the prior check, the
     attempt and the Receipt;
   - the Partner holds exactly one Receipt for the Order.
2. **Given** the same Case, **When** the Partner already holds a Receipt for the Order before the
   send, **Then** nothing is sent, the Case is `Resolved`, and the Receipt copy says it came from
   reconciliation.
3. **Given** an approval of a Proposal that needs no effect on the Partner (`HOLD`), **When** its
   execution request is processed, **Then** an execution without an approval is recorded, nothing
   is sent, and the Case is `Held`.
4. **Given** the authorization cannot be stored, **When** the execution request is processed,
   **Then** no Partner call happens and the Case is still `Approved`.

---

### User Story 2 - Nothing is sent on stale context (Priority: P1)

Between the approval and the send, the world may change: the Partner degrades, enters maintenance,
or the Order is cancelled at the Origin. The approval may expire, or the policy or mapping it
relied on may change. The system finds out immediately before the send and does not send.

**Why this priority**: Sending something the Operator would no longer approve is the unsafe outcome
the P3 family exists to prove impossible.

**Independent Test**: Approve, change one condition, process the execution request, read the Case,
the recorded checks and the Partner's Receipts.

**Acceptance Scenarios**:

1. **Given** an `Approved` Case whose Partner has degraded (or announced active maintenance),
   **When** the execution request is processed, **Then** nothing is sent, the Case is `Held`, and
   the failed check and the observed health are recorded.
2. **Given** an `Approved` Case whose Order was cancelled at the Origin, **When** the execution
   request is processed, **Then** nothing is sent and the Case is `Cancelled`.
3. **Given** an `Approved` Case whose approval is past its deadline, **When** the execution request
   is processed, **Then** nothing is sent and nothing changes state; the periodic sweep expires the
   approval and the Case goes back to waiting for a new approval.
4. **Given** an `Approved` Case whose Proposal relied on a policy or mapping version that is no
   longer current, **When** the execution request is processed, **Then** nothing is sent and the
   Case is `Held` with that reason.
5. **Given** the Partner's health or the Order's status cannot be read, **When** the execution
   request is processed, **Then** the check counts as not satisfied: nothing is sent and the Case
   is `Held`.

---

### User Story 3 - An uncertain outcome is reconciled, never resent blindly (Priority: P1)

The Partner may accept a delivery and lose the answer, time out, answer 5xx without a body, or
answer 200 without a valid Receipt. The system treats any of these as unknown and asks the Partner
for Receipts by effect key and by Order before anything else. A Receipt settles it. When there is
none, the same effect can be sent again only with the same key and payload, which the Partner
deduplicates.

**Why this priority**: A duplicated effect on stale assumptions is the worst outcome for an
operator.

**Independent Test**: Use a Partner that records the Receipt and answers too late, process the
execution, read the Case, the execution's reconciliations and the Partner's Receipts.

**Acceptance Scenarios**:

1. **Given** a send that the Partner accepted but whose answer was lost, **When** reconciliation
   runs, **Then** it finds the Receipt, the Case is `Resolved` with a Receipt copy from
   reconciliation, and nothing was sent again.
2. **Given** an uncertain outcome, **When** it is recorded, **Then** the execution's outcome is
   "reconciling", the Case stays `Executing`, the Case summary shows the unknown outcome, and a
   reconciliation request is queued in the same commit.
3. **Given** an uncertain outcome and no Receipt found, **When** reconciliation runs and attempts
   remain, **Then** the effect is sent again with the same key and the same payload.
4. **Given** the same key and the same payload sent twice, **When** the Partner answers, **Then**
   the answer is the original Receipt and the Partner holds one Receipt.
5. **Given** the same key with an incompatible payload, **When** it is sent, **Then** the Partner
   rejects it, nothing is recorded as a Receipt, and the execution fails.
6. **Given** an execution for an Order whose outcome is still "reconciling", **When** another
   execution for the same Order is requested, from any Proposal, **Then** nothing is sent and the
   request waits until reconciliation settles.

---

### User Story 4 - Restarts, late workers and repeats do not duplicate (Priority: P1)

Each execution carries a lease with an owner and a generation. A worker that stops (restart, crash)
leaves its lease to expire; the periodic sweep then asks for reconciliation, and the worker that
takes over raises the generation. A worker that comes back late cannot overwrite the newer one.
Repeated commands and repeated clicks find the work already done.

**Why this priority**: These are normal events in production, not exceptions.

**Independent Test**: The recovery suite: lost response after acceptance, repeated click, restart
during execution, repeated command, late worker and a blocking precondition, each followed by a
count of the Partner's Receipts for the Order.

**Acceptance Scenarios**:

1. **Given** a Case in `Executing` whose worker stopped and whose lease expired, **When** the
   periodic sweep runs, **Then** it requests reconciliation (never `ReviewRequired`), the worker
   that takes over raises the generation, and the Case ends `Resolved` with one Receipt.
2. **Given** a worker holding an older generation, **When** it tries to record an attempt or an
   outcome, **Then** the write is refused and recorded as discarded. If it had obtained a Receipt,
   a reconciliation is requested instead.
3. **Given** an execution request delivered twice (or by two processes at once), **When** both run,
   **Then** one execution and at most one effect exist.
4. **Given** an Operator who clicks approve twice, **When** both requests arrive, **Then** one
   approval, one execution and one effect exist.
5. **Given** a Case in `Investigating` whose investigation passed its lease, **When** the periodic
   sweep runs, **Then** the Case moves to `ReviewRequired`.

---

### User Story 5 - Held is reassessed; leaving Held starts over (Priority: P2)

A held Case is reassessed periodically. When the condition that held it has cleared, the Case goes
back to investigation for a new Proposal, which needs a new approval. A previous approval is never
reused.

**Why this priority**: Without it, Held is a dead end the Operator must notice by hand.

**Independent Test**: Hold a Case on a degraded Partner, recover the Partner, run the sweep, read
the Case, its approvals and its pending work.

**Acceptance Scenarios**:

1. **Given** a `Held` Case whose Partner is still degraded, **When** the sweep runs, **Then** the
   Case stays `Held`.
2. **Given** a `Held` Case whose Partner recovered, after the minimum hold time, **When** the sweep
   runs, **Then** the Case is `Investigating`, the Timeline records the reassessment by the
   sweeper, and an investigation request is queued.
3. **Given** a Case held because a policy or mapping version changed, **When** the sweep runs after
   the minimum hold time, **Then** it goes back to `Investigating`: the new Proposal is the fix.
4. **Given** a Case that left `Held`, **When** a new Proposal is recorded, **Then** the earlier
   approval can authorize nothing; a new approval is needed for any Action with an effect.

---

### User Story 6 - Refusals and exhausted attempts fail honestly (Priority: P2)

A business refusal from the Partner is not retried. Transient failures are retried within the
execution's attempt budget. When the budget runs out, or the Partner refuses, the execution fails,
and the refusal is reported as a new Exception of the Order, which opens a related Case for a new
investigation.

**Why this priority**: A refusal must never be shown as success, and the Order must not be left
without a Case.

**Independent Test**: Approve a resend on a Partner that refuses with a business error, process the
execution, read both Cases.

**Acceptance Scenarios**:

1. **Given** a send answered with a business refusal, **When** it is classified, **Then** the
   attempt records the class and an excerpt of the body. The execution and the Case are `Failed`,
   and a new related Case opens with the refusal as its Exception.
2. **Given** a send answered as transient, **When** attempts remain, **Then** the same effect is
   sent again with the same key, as a new attempt of the same execution.
3. **Given** transient answers until the attempt budget runs out, **When** the last one is
   classified, **Then** the execution and the Case are `Failed`.
4. **Given** any Partner answer, **When** it is classified, **Then** only a Receipt whose Order and
   key match the send counts as success.

---

### User Story 7 - The execution is visible on the Case (Priority: P3)

The Operator reads the execution on the Case: its checks, attempts, reconciliations, outcome and
the Receipt copy.

**Why this priority**: The console already has the slots; without data they stay empty.

**Independent Test**: Read the Case detail and the Case list after each outcome and check them
against the contract.

**Acceptance Scenarios**:

1. **Given** a Case with executions, **When** its detail is read, **Then** each execution shows its
   identity, approval, Proposal, Action, effect key, authorization time, lease generation,
   revalidation, attempts, reconciliations and outcome. The detail also shows the Receipt copy.
2. **Given** a Case whose latest execution is reconciling, **When** the Case list is read, **Then**
   its summary carries the "reconciling" outcome.
3. **Given** every response above, **When** it is checked against the contract, **Then** it
   conforms.

### Edge Cases

- An execution request whose Case moved on since it was written is discarded by the entry point
  (007), and nothing is sent.
- A revalidation that passes while a concurrent writer moves the Case: the authorization loses the
  version check, writes nothing and sends nothing.
- The Partner's answer on a key it already saw is the original Receipt, even if the scenario would
  have failed (duplicate rule before the script).
- A Receipt whose Order or key does not match the send is not a Receipt; the outcome is uncertain.
- A Receipt found by Order with a different key (the first delivery's key) still settles the
  effect. The Order was delivered, and the Partner's record prevails.
- A late worker that obtains a Receipt after losing its lease does not discard the effect: it
  requests reconciliation, which records the Receipt.
- An exception that arrives while the Case is `Approved` or `Executing` is attached (003) and does
  not stop the execution.
- A `HOLD` executed on a healthy Partner is reassessed only after the minimum hold time, so a Case
  cannot loop through investigation on every sweep.

## Requirements *(mandatory)*

### Functional Requirements

**Single path and authorization**

- **FR-001**: Every effect on the Partner MUST happen through one execution path, started only by
  an execution request.
- **FR-002**: The path MUST revalidate immediately before authorizing. The checks are:
  - the Partner's declared health, including announced maintenance;
  - the Order's status at the Origin;
  - the approval's validity and deadline, when the Action needs one;
  - the policy version;
  - the mapping version.
  A check whose observation cannot be read MUST count as not satisfied.
- **FR-003**: A blocking revalidation MUST move the Case to `Cancelled` when the Order was
  cancelled at the Origin, and to `Held` otherwise; nothing is sent. An expired approval MUST change
  nothing: the sweep expires it (007).
- **FR-004**: A passed revalidation MUST record, in one commit that wins a compare-and-swap on the
  Case version:
  - the execution, with its effect key and its lease (owner, generation 1, deadline);
  - the revalidation result;
  - the approval marked as consumed;
  - the move to `Executing`;
  - the request marked done.
  If that commit cannot be made, nothing is sent.
- **FR-005**: Before any send, the path MUST look for the Partner's Receipts by Order. A Receipt
  found MUST resolve the Case without sending, recorded as a prior-check reconciliation.

**Send and outcome**

- **FR-006**: Each send MUST be recorded as an attempt before it leaves (number, transaction
  identifier, time) and completed after the answer (status, class, body excerpt, Receipt).
- **FR-007**: The Partner's answer MUST be classified by one rule:
  - **success**: a Receipt whose Order and key match the send.
  - **business error**: a refusal with a body (4xx, or 5xx with a body other than unavailability).
  - **transient**: declared unavailability.
  - **uncertain**: no answer, timeout, 5xx without a body, or 200 without a valid Receipt.
- **FR-008**: Success MUST store a Receipt copy (Receipt id, Order, key, time, Partner, source,
  external reference) and resolve the Case.
- **FR-009**: Uncertain MUST mark the execution "reconciling" and queue a reconciliation request in
  the same commit; the Case stays `Executing`.
- **FR-010**: Reconciliation MUST query the Partner by effect key, then by Order. A Receipt found
  MUST resolve the Case; none found MAY send again only with the same key and payload, within the
  attempt budget.
- **FR-011**: Transient answers MUST be retried as new attempts of the same execution, with the same
  key and payload, within the attempt budget (default 3 attempts).
- **FR-012**: A business error, or an exhausted budget, MUST fail the execution and the Case. A
  business error MUST then be reported as a new Exception of the Order (opening a related Case,
  003).
- **FR-013**: While any execution of an Order is "reconciling", no other execution for that Order
  MUST send; its request waits.

**Identities**

- **FR-014**: Internal work (request id), the authorized execution (execution id, lease,
  reconciliation) and the effect on the Partner (effect key) MUST be distinct identities.
- **FR-015**: The effect key MUST identify the effect: the Order, the Partner and the canonical
  payload that is sent. Two Proposals that would send the same payload MUST produce the same key;
  a different payload MUST produce a different key. The key MUST NOT depend on the Proposal.

**Leases and recovery**

- **FR-016**: Every write of an attempt or outcome MUST carry the execution's generation; a write
  under an older generation MUST be refused and recorded as discarded.
- **FR-017**: A worker that obtained a Receipt but whose write was refused MUST request
  reconciliation.
- **FR-018**: The periodic sweep, after the lease:
  - for a Case in `Executing`, MUST request reconciliation, never move the Case to review;
  - for a Case in `Investigating`, MUST move it to `ReviewRequired`.
  The worker taking over raises the generation.
- **FR-019**: The lease MUST last longer than the Partner's client timeout.

**Held**

- **FR-020**: The sweep MUST reassess `Held` Cases after a minimum hold time (default 5 minutes).
  When the Partner is healthy, or when the hold came from a version change, the Case MUST go to
  `Investigating` with an investigation request, recorded as a reassessment by the sweeper.
- **FR-021**: Leaving `Held` MUST NOT reuse an approval: the approval was consumed by the execution
  and a new Proposal supersedes everything else.
- **FR-022**: `HOLD` MUST be executed without a Partner call: an execution without an approval,
  then `Held`.

**Visibility**

- **FR-023**: The Case detail MUST list its executions and its Receipt copy, and the Case
  summary MUST carry the latest execution's outcome, as the contract defines them.
- **FR-024**: Every step MUST be on the Timeline with its contract event type:
  - `RevalidationPerformed`;
  - `ExecutionAuthorized`;
  - `AttemptRecorded`;
  - `ReconciliationPerformed`;
  - `ReceiptRecorded`;
  - `ReassessmentPerformed`;
  - `CommandDiscarded`;
  - `StateChanged`.

### Key Entities

- **Execution**: one authorized execution of an Action. It holds:
  - approval, Proposal, Action and effect key;
  - authorization time;
  - lease owner, generation and deadline;
  - revalidation, attempts, reconciliations and outcome.
- **Attempt**: one send of the execution's effect, with its answer and class.
- **Reconciliation**: one query of the Partner's Receipts. It holds the trigger (prior check,
  timeout, uncertain answer, lost write, expired lease), the query used and what was found.
- **Receipt copy**: the Case's auditable copy of the Partner's canonical Receipt.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Across the recovery suite, the Partner holds exactly 1 Receipt per resolved Order (0
  duplicates). The suite covers lost response, repeated click, restart, repeated command, late
  worker and blocking precondition.
- **SC-002**: 0 sends happen when a revalidation check is not satisfied.
- **SC-003**: 0 sends with a new key happen for an Order while one of its executions is
  reconciling.
- **SC-004**: 100% of uncertain outcomes are followed by a reconciliation before any further send.
- **SC-005**: 0 Cases leave `Held` with a reused approval.
- **SC-006**: Every Case detail, summary and Timeline response with executions conforms to the
  contract (live contract check).

## Assumptions

- The revalidation rule, the attempt budget and the minimum hold time sit behind ports with
  defaults until 004 supplies policies:
  - healthy means `UP` and no active maintenance;
  - 3 attempts;
  - 5 minutes of minimum hold.
  The current policy and mapping versions come from the same port; with no reference data loaded
  they are the versions the Proposal recorded.
- The effect payload is:
  - for `RETRY`, the Order snapshot;
  - for `APPLY_APPROVED_MAPPING`, the Order after the approved mapping, which only 004's catalog
    can produce.
  Until 004 merges, a mapping Action is held with the reason "mapping unavailable" instead of
  being sent.
- The effect key follows the proposal in the contract's open question API-Q11: the key represents
  the effect, not the Proposal. The contract fields keep the name `idempotencyKey`, so the contract
  does not change.
- The first delivery made on intake (002 G1 notes) keeps its own key. The prior check by Order
  finds its Receipt, if any, before a resend.
- Calendar gate: same exception the user granted for 003, 005, 006, 007, 009 and 009b, recorded in
  research.md.
