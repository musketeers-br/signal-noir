# Feature Specification: Case state machine Core (Phase B)

**Feature Branch**: `002-case-state-machine-core` (no branch created; spec directory only)

**Created**: 2026-10-22

**Status**: Draft — specification only. Code may start before 2026-10-26 (Constitution 1.2.0, pending team review); the Plan should still wait for the 10/25 spike (see Assumptions).

**Input**: User description: "Phase B of the normative Case state machine: the Core that enforces it at runtime (Signal Noir, epic-caso-e-decisao; follows story 2.2 / specs/001-case-state-machine). A pure Core decision with no I/O, the single Application command path that records its result atomically, and a parity test proving the Core equals contracts/case-state-machine.yaml. Starts on 2026-10-26, after the 10/25 spike answers Q-F." (The start date was later relaxed by Constitution 1.2.0.)

**Epic**: `epic-caso-e-decisao`, B06 (Case transactional commands, Approval bound to the exact version, outbox). Owner: José. Normative source: `contracts/case-state-machine.yaml` and [specs/001-case-state-machine/spec.md](../001-case-state-machine/spec.md).

## User Scenarios & Testing *(mandatory)*

The users of this feature are the components that change a Case — the Production flow, the HTTP API, the sweeper and the Benchmark — and, through them, Carla, the Operator. Today the table exists only as a frozen document; this feature makes every command against a real Case obey it, through one path, so no component carries its own copy of a transition rule.

### User Story 1 - Every command against a Case obeys the normative table (Priority: P1)

A component sends a command for a Case (for example "approve this Proposal" or "Revalidation failed with the Partner unstable"). The system decides, from the Case as it is now, whether the command is a transition, an attachment or a refusal, exactly as the normative table says, and records the outcome.

**Why this priority**: it is the reason the feature exists. Without it, the table is advice and each front reimplements rules (Constitution Principle I, AD-1, AD-24).

**Independent Test**: for each of the 29 table rows, build a Case that satisfies the row's preconditions, send the row's command with the row's actor, and check the resulting state, Timeline events and follow-up work against the table; then send every (state, target) pair that is not in the table and check that each is refused.

**Acceptance Scenarios**:

1. **Given** a Case in `PendingApproval` with a current Proposal, **When** `operator:Carla` approves that Proposal with the current version, **Then** the Case is in `Approved`, the Timeline gains `ApprovalRecorded` and `StateChanged {from: PendingApproval, to: Approved, reason, caseVersionAfter}`, `caseVersion` grows by one, and an `Execute` work item is queued — all or nothing.
2. **Given** a Case in `Executing` whose Revalidation reports both `ORDER_ACTIVE_AT_ORIGIN` and `PARTNER_HEALTHY_WINDOW` false, **When** the result is submitted, **Then** the Case goes to `Cancelled` (precedence `Cancelled` > `Investigating` > `Held`), the Execution closes as `cancelled` and its authorization is voided.
3. **Given** a Case in `Executing`, **When** a new Exception for the same Order arrives, **Then** it is recorded as an attachment: state and `caseVersion` do not change, and the Exception is kept for reassessment at the end of the Execution.

---

### User Story 2 - A disallowed command changes nothing and leaves a trace (Priority: P1)

A command that asks for a transition outside the table, comes from an actor not allowed for that transition, carries a stale version, or tries to execute with an expired Approval is refused with its code. The Case does not change, and the refusal is recorded on its Timeline.

**Why this priority**: it is the guarantee the Operator and the reviewers rely on (spec 001 User Story 2, FR-012), and a refusal must never look like success (Principle VII).

**Independent Test**: send `Open → Executing`, an Approval by `benchmark` outside a BenchmarkRun, an Approval with a stale version, and an `Execute` after the Approval expired; check the four refusal codes, unchanged state and `caseVersion`, and one `CommandDiscarded` per refusal.

**Acceptance Scenarios**:

1. **Given** a Case in `Open`, **When** a command asks for `Executing`, **Then** it is refused with `INVALID_TRANSITION`, the Case is unchanged, and `CommandDiscarded {command, actor, currentState, requestedState, code}` is on the Timeline.
2. **Given** a Case in `Approved` whose Approval expired, **When** `Execute` arrives, **Then** it is refused with `APPROVAL_EXPIRED` and the Case stays in `Approved` until the sweeper expires it (`Approved → PendingApproval`).
3. **Given** a Proposal already approved, **When** the same approval arrives again (another tab or another Operator), **Then** the existing Approval is returned, nothing is refused, and no new transition, event or work item is produced.

---

### User Story 3 - The journeys of the Operator run end to end through the Core (Priority: P2)

The four Operator journeys of EXPERIENCE.md (UJ-1 to UJ-4) can be replayed step by step against the Core, with the actors listed in the table's `journeyTrace`, and each step lands in the state the journey describes.

**Why this priority**: it proves the table and the Core agree on the flows the demo and the judges will see; it is the bridge from per-row correctness to user-visible behavior.

**Independent Test**: for each journey, start from the Case the journey begins with, apply the commands of its trace in order with the listed actors, and compare the final state, Timeline and work items with the journey.

**Acceptance Scenarios**:

1. **Given** UJ-2 (a `RETRY` approved for a sincere 503), **When** the commands of its trace run with the Partner turning unstable before the send and recovering later, **Then** the Case goes `Approved → Executing → Held → Investigating → DecisionProposed → PendingApproval`, nothing is sent while held, and the old Approval is never reused.
2. **Given** UJ-4 (ambiguous identity), **When** Carla tries `RETRY` and the Validator blocks it, **Then** only the verdict is recorded and the Case stays in `ReviewRequired`; **When** she then cancels with a reason, **Then** the Case is `Cancelled` with `operator:Carla` on the Timeline.

---

### User Story 4 - Terminal Cases never reopen and new episodes stay linked (Priority: P3)

A Case in a terminal state accepts no transition; an Exception for the same Order after it opens a new Case linked to the previous one; corrections to a terminal Case's Receipt are annotations only.

**Why this priority**: it keeps one truth per episode (Principle V); it shows up less in the demo than Stories 1–3.

**Independent Test**: with a `Resolved` Case, send a new Exception for the same Order and a Receipt correction; check that a new Case opens with `previousEpisodeCaseId`, that the old one keeps its state and `caseVersion`, and that only `Annotation` entries were added to it.

**Acceptance Scenarios**:

1. **Given** a `Resolved` Case for Order X, **When** a new Exception for X arrives, **Then** a new Case opens in `Open` linked to the previous one, and the previous Case gains only a `new_episode_opened` annotation.
2. **Given** a Case in `Executing` that received an Exception during the Execution, **When** the Policy Attempts are exhausted, **Then** the Case is `Failed` and, in the same operation, a new linked Case opens with that Exception.

---

### Edge Cases

- **Two writers on the same Case at once** (for example Approval and a new Exception in `PendingApproval`): exactly one wins; the other is refused with `STALE_VERSION` or becomes an attachment according to the state it finds — never both applied, never neither recorded.
- **Recording fails mid-way** (state written but events or work item not): nothing is kept; the command is reported as failed, not as applied.
- **A command whose preconditions match two rows** for the same (from, to) pair: treated as a defect of the table, not resolved silently; the parity test must make it impossible to ship.
- **A late answer from the proposer** after the sweeper moved the Case to `ReviewRequired`: refused and recorded; the closed Investigation is not changed.
- **A second non-terminal Case for the same Order** attempted by two concurrent first Exceptions: only one Case is created; the other Exception is attached to it.
- **The normative table changes later** (new version of `contracts/case-state-machine.yaml`): the parity test fails until the Core is updated; the Core never reads the table at runtime.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The system MUST decide every Case command through one pure decision — given the Case as it is, the command and the current time, return exactly one of: transition accepted (target state, events, record effects, follow-up work), refused (code and the refusal record), or attachment (event) — with no access to storage, network or clock of its own.
- **FR-002**: The decision MUST implement exactly the 29 transitions of `contracts/case-state-machine.yaml`, with their actors and preconditions, and nothing else.
- **FR-003**: Every component that changes a Case (Production flow, API, sweeper, Benchmark) MUST go through a single command path that calls the decision; no component MAY change a Case's state, Timeline or work items directly.
- **FR-004**: An accepted transition MUST be recorded atomically: new state, `caseVersion` incremented by one, `StateChanged {from, to, reason, caseVersionAfter}`, the row's other events and its follow-up work items. If any part cannot be recorded, none is.
- **FR-005**: An attachment MUST record its event without changing state or `caseVersion`, and only in the states the table allows for it.
- **FR-006**: A refused command MUST leave state and `caseVersion` unchanged and record `CommandDiscarded {command, actor, currentState, requestedState, code}`, with `code` ∈ `INVALID_TRANSITION`, `INVALID_ACTOR`, `STALE_VERSION`, `APPROVAL_EXPIRED`, and the caller MUST receive the refusal as a result, never as success.
- **FR-007**: A repeated approval of an already approved `proposalId` MUST return the existing Approval with no transition, no event and no work item, even with a stale version.
- **FR-008**: When several Revalidation checks fail, the decision MUST apply the precedence `Cancelled` > `Investigating` > `Held`; in all three exits the Execution closes with no Attempt sent and its authorization is voided in the same operation and never accepted again.
- **FR-009**: The decision MUST keep `denialCount` per Case as the table defines: incremented only on denial, never reset within the Case, at most one new Investigation after `Rejected`, `ReviewRequired` on the second denial.
- **FR-010**: The system MUST keep at most one non-terminal Case per Order; an Exception for an Order whose latest Case is terminal MUST open a new Case linked to the previous one (`previousEpisodeCaseId`), and the previous Case MUST gain only the `new_episode_opened` annotation.
- **FR-011**: Only the `sweeper` actor MUST be able to expire an Approval; `benchmark` MUST be accepted only for the Benchmark Automatic Approval on a BenchmarkRun Case; `agent`, `rules` and `replay` only for delivering a Proposal and only when they match the Case's mode.
- **FR-012**: A parity test MUST check, row by row, that the decision accepts each of the 29 rows of `contracts/case-state-machine.yaml` with the same target, events and follow-up work, and that every (state, target) pair outside the table is refused with `INVALID_TRANSITION`; it MUST read the table file, and the decision MUST NOT.
- **FR-013**: The four journeys UJ-1 to UJ-4 MUST be replayable as automated scenarios through the command path, with the actors and steps of the table's `journeyTrace`.
- **FR-014**: All tests of this feature MUST run on the live contest instance (IRIS AI Hub build 154) through iris-agentic-dev, and each test MUST exist and fail before the behavior that makes it pass (TDD).

### Key Entities

- **Case snapshot**: what the decision reads — state, `caseVersion`, `denialCount`, step lease, current Proposal, Approval (decision, `expiresAt`), Execution (outcome, inconclusive Reconciliation rounds, authorization status), mode and BenchmarkRun, pending reassessment Exceptions, previous episode (data-model Part 2 of spec 001).
- **Command**: requested target or attachment, actor, expected state, expected `caseVersion`, target (`proposalId` or `executionId`), and the facts already recorded as Evidence or verdicts (Validator verdict, Revalidation result, Partner response class, Reconciliation result).
- **Decision**: accepted transition, refusal or attachment, as a value.
- **Work item**: one of `Investigate`, `Execute`, `Reconcile`, `Expire`, `Reassess`, `Resume`, queued with the Case and the `caseVersionAfter` it applies to.
- **Refusal record**: the `CommandDiscarded` Timeline event.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 29 of 29 table rows are accepted by the decision with the table's target, events and follow-up work, and 100% of the (state, target) pairs outside the table are refused with `INVALID_TRANSITION`.
- **SC-002**: 100% of refused commands in the test suite leave state and `caseVersion` unchanged and leave exactly one `CommandDiscarded` on the Timeline.
- **SC-003**: The 4 journeys UJ-1 to UJ-4 run end to end in automated scenarios, each ending in the state and with the actors its trace lists.
- **SC-004**: In concurrency scenarios (two approvals, approval plus new Exception, two first Exceptions for one Order), exactly one write wins every time, with no lost refusal record, across at least 100 repeated runs.
- **SC-005**: After any change to `contracts/case-state-machine.yaml`, the parity test fails within one test run until the Core matches it again.
- **SC-006**: No component outside the command path changes a Case: a review of every module that touches Cases finds zero direct writes.

## Assumptions

- **Start date**: Constitution 1.2.0 (pending team review) lifts the calendar gate, so work may start before 2026-10-26; the tests still have to run on the contest build 154 (FR-014). The Plan of this feature should be written after the 10/25 spike reports on Q-F (Embedded Python version on build 154) and on what build 154 exposes; it then chooses the implementation language among the three options of specs/001 research R4 (ObjectScript; Embedded Python methods inside ObjectScript classes; Embedded Python modules, which would require amending the Constitution's test rule and AD-1/AD-16). The Agent stays on `%AI.Agent` regardless.
- **Dependency on B04** (`epic-fundacao-e-simulador`): the first persisted Case and the Production as transport exist before this feature's end-to-end scenarios run; per Principle IX this feature extends that tracer slice rather than delivering a layer on its own.
- **Normative source**: `contracts/case-state-machine.yaml` 1.0.0 as validated by `contracts/tools/validate_state_machine.py`; this feature changes the Core to match the table, never the reverse. A disagreement found while building becomes a change proposal to the table and to spec 001 first.
- **Contract changes C1–C5** (spec 001 `openapi-delta.md`) reach the HTTP contract in story 2.5; this feature records the fields internally even if the HTTP contract exposes them later.
- **Concurrency**: optimistic, by compare-and-swap on state, `caseVersion` and target, as AD-3 decides; no locks.
- **Out of scope**: the Agent, Tools and Investigation; the Validator's verdict logic; the Partner client, Revalidation checks and Reconciliation queries (they produce the facts this Core consumes); sweeper scheduling; HTTP endpoints; UI; effect-key derivation (story 2.3); freezing contract 1.0.0 (story 2.5).
