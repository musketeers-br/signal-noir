# Feature Specification: Normative Case state machine

**Feature Branch**: `001-case-state-machine` (no branch created; spec directory only)

**Created**: 2026-10-22

**Status**: Draft

**Input**: User description (translated from Portuguese): "Normative state machine of the Signal Noir Case (story 2.2 / B01 of epic-contratos-e-spike). One frozen table that replaces addendum §D and AD-24 as the normative source, covering the 13 states of `CaseState`, with actor, preconditions, Timeline events and follow-up work for each transition, and resolving the five known contradictions."

**Ticket**: `epic-contratos-e-spike`, entry 2 (B01). Owner: Henry (domain) with José (technical). Reviewer: Henrique.

**Replaces as normative source**: `addendum.md` §D (in full) and the "Pontos fixados" (fixed points) table of AD-24. PRD FR-5 now points to this document. The rest of AD-24 (the Core owns the table and refuses an unlisted actor) still applies.

## Clarifications

### Session 2026-10-22

Henry accepted the recommendation on Q1 and asked for the remaining questions to be settled by the recommendation.

- Q: Is a new Exception for the same Order, with the Case in `PendingApproval`, a transition or an attachment? → A: Transition `PendingApproval → Investigating` (T16); the current Proposal stops being current and open screens receive `STALE_VERSION` (D1).
- Q: When the Case enters `Failed` with an Exception attached during `Approved`/`Executing`, does the new episode open automatically? → A: Yes, in the same transaction (T25 → T02); without an attached Exception, no new Case (D2).
- Q: How many inconclusive Reconciliation rounds before `Executing → ReviewRequired`? → A: 3 (T26, D4).
- Q: Is `denialCount` reset when the Case returns to `Investigating` through Reassessment (T27) or a changed version (T22)? → A: No; it holds for the whole Case (FR-006).
- Q: Does a new Exception during `Investigating` restart the running Investigation? → A: No; it is an attachment, enters as Evidence if collection is still open, and in any case is visible to the Validator and the Dossier.

## User Scenarios & Testing *(mandatory)*

The "users" of this specification are the three fronts that start building on 10/26 (José on the Production, Henry on the Simulator and Scenarios, Henrique on the Interface and the HTTP contract) and, through them, Carla, the Operator of flows UJ-1 to UJ-4. The value delivered is that nobody needs to renegotiate a transition after 10/26.

### User Story 1 - Find the transition and actor of each step of a journey (Priority: P1)

José opens the table and, for each step of flows UJ-1 to UJ-4 in EXPERIENCE.md, finds the row that says which state the Case leaves, which state it enters, who may do it, what must be true beforehand, which event appears on the Timeline and what work comes next. He does it without asking Henry anything.

**Why this priority**: it is the ticket's acceptance criterion and it unblocks the three fronts. Without it, each front implements its own reading of §D and AD-24.

**Independent Test**: give José the table and EXPERIENCE.md; he fills in the "Journey trace" section independently and the result matches this spec.

**Acceptance Scenarios**:

1. **Given** step 5 of UJ-1 (Carla approves), **When** José looks it up in the table, **Then** he finds T11 (`PendingApproval → Approved`, actor `operator:<name>`, precondition "current Proposal and up-to-date `expectedCaseVersion`", events `ApprovalRecorded` and `StateChanged`, follow-up work `Execute`).
2. **Given** step 2 of UJ-2 (Revalidation finds the Partner unstable), **When** José looks it up, **Then** he finds T19 (`Executing → Held`, actor `system`) and knows that nothing was sent and the recorded authorization was voided.
3. **Given** step 7 of UJ-1 (Approve again from another tab), **When** José looks it up, **Then** he finds the repeated-Approval rule: no transition, idempotent response, no new effect.

---

### User Story 2 - Refuse and record a disallowed transition or actor (Priority: P1)

Any command asking for a transition that is not in the table, or coming from an actor that is not in the transition's row, is refused with `INVALID_TRANSITION` or `INVALID_ACTOR`. The Case does not change and the refusal is recorded on the Timeline.

**Why this priority**: it is the guarantee that makes the table normative rather than descriptive (FR-5, AD-24), and it is an explicit acceptance criterion.

**Independent Test**: send `Open → Executing`, an Approval with actor `benchmark` outside a BenchmarkRun, and an expiration issued by an actor other than `sweeper`; check that all three are refused, that `caseVersion` does not change and that there is a refusal event for each.

**Acceptance Scenarios**:

1. **Given** a Case in `Open`, **When** a command asking for `Open → Executing` arrives, **Then** the command is refused with `INVALID_TRANSITION`, the state and `caseVersion` stay the same and the Timeline gains a `CommandDiscarded` with `{command, actor, current state, requested state, code}`.
2. **Given** a Case in `Approved` outside a BenchmarkRun, **When** an actor other than `sweeper` asks for `Approved → PendingApproval` by expiration, **Then** the command is refused with `INVALID_ACTOR` and recorded.
3. **Given** a Case in `PendingApproval` outside a BenchmarkRun, **When** an Approval with actor `benchmark` arrives, **Then** it is refused with `INVALID_ACTOR` and recorded.

---

### User Story 3 - Waiting, rejection and expiration with a single owner per transition (Priority: P2)

The Case enters and leaves `Held`, `Rejected` and Approval expiration always by the same path and with a single authorized actor, so that two units never compete for the same transition.

**Why this priority**: these are the points where §D and AD-24 left two possible owners (adversarial review H-1), and they cover UJ-2 and the denial rule of FR-5.

**Independent Test**: simulate an Approval that expires without execution, two denials in a row, and a Case in `Held` whose Partner stabilizes; check each transition and the recorded actor.

**Acceptance Scenarios**:

1. **Given** a Case in `Approved` whose Approval expired (15 min) with no authorization recorded, **When** the sweeper runs, **Then** the Case goes to `PendingApproval` with `ApprovalExpired`, and the same Proposal can be approved again.
2. **Given** a Case with `denialCount = 0` in `PendingApproval`, **When** Carla denies with a reason, **Then** the Case goes to `Rejected`, `denialCount = 1`, and then to `Investigating` with the denial reason as Evidence.
3. **Given** the same Case, back in `PendingApproval` after the new Investigation, **When** Carla denies a second time, **Then** the Case goes to `Rejected` and then to `ReviewRequired` with a Dossier of reason `second_denial`.
4. **Given** a Case in `Held` because the Partner is unstable, **When** the periodic Reassessment finds the Partner stable, **Then** the Case goes to `Investigating`, and the previous Approval is never reused.

---

### User Story 4 - Uncertainty and closure without a duplicated effect (Priority: P2)

When the send to the Partner ends in a timeout or an uncertain response, the Case stays in `Executing` with an unknown outcome until Reconciliation gives an answer. The table says what happens for each Reconciliation outcome, including when it finds no Receipt.

**Why this priority**: it is contradiction 4 and protects the at-most-once effect guarantee (Principle VI).

**Independent Test**: with the scenario `case.executing.outcome-unknown`, exercise the three Reconciliation outcomes (Receipt found, absence confirmed, inconclusive Reconciliation) and check the final state, `executionOutcome` and the number of Receipts at the Partner.

**Acceptance Scenarios**:

1. **Given** a Case in `Executing` with `executionOutcome = reconciling`, **When** Reconciliation finds the Receipt for the effect key, **Then** the Case goes to `Resolved` without a resend.
2. **Given** the same Case, **When** the Partner answers conclusively that there is no Receipt and the Policy still has Attempts left, **Then** the Execution makes a new Attempt with the same effect key; with no Attempts left, the Case goes to `Failed`.
3. **Given** the same Case, **When** Reconciliation stays inconclusive after the maximum number of rounds, **Then** the Case goes to `ReviewRequired` with a Dossier of reason `outcome_unknown`, and no new send for the same Order happens until a conclusive Reconciliation.

---

### User Story 5 - A terminal state never reopens (Priority: P3)

An Exception for the same Order after a terminal state opens a new Case, related to the previous one. A Receipt divergence in a terminal Case becomes only an annotation.

**Why this priority**: it closes contradictions 2 and 5 and the new-episode rule; it shows up less in the demo, but without it the fronts invent `Resolved → Resolved` or reopening (review M-7).

**Independent Test**: cause an Exception after `Resolved` and a Receipt correction on a `Resolved` Case; check that the old Case changes neither state nor `caseVersion`.

**Acceptance Scenarios**:

1. **Given** a `Resolved` Case for `orderId` X, **When** a new Exception for X arrives, **Then** a new Case opens in `Open` with `previousEpisodeCaseId` pointing to the previous one, and the previous one stays `Resolved`, gaining only a `new_episode_opened` annotation.
2. **Given** a `Resolved` Case, **When** a query to the Partner shows a canonical Receipt different from the Case's copy, **Then** the Case gains a `receipt_corrected` annotation, with no change to state or `caseVersion`.
3. **Given** a Case in `Executing` that received a new Exception during the Execution, **When** the Execution ends in `Failed`, **Then** a new Case (new episode) opens with that Exception, and the failed Case stays `Failed`.

---

### Edge Cases

- **Late Agent answer** after the sweeper moved the Case to `ReviewRequired` (T06): the CAS of `Investigating → DecisionProposed` fails; the Proposal is not recorded; a `CommandDiscarded` is recorded.
- **Approval and new Exception at the same time in `PendingApproval`**: T11 and T16 compete for the same `caseVersion`; only one wins. If T16 wins, the Approval receives `STALE_VERSION`. If T11 wins, the Exception becomes an attachment (the `Approved` rule).
- **Execute delayed more than 15 min** (for example, a restart): T17 refuses because the Approval expired; the Case stays in `Approved` until the sweeper applies T18.
- **Revalidation with more than one false precondition**: precedence `Cancelled` > `Investigating` > `Held` (Decision D3).
- **Losing the exit CAS after an external effect** (the BO holds the Receipt and another writer moved ahead): the loser issues `Reconcile` (AD-22); it never discards the effect.
- **Expiration on a BenchmarkRun Case**: T18 applies as usual; the Benchmark Automatic Approval is not reissued, and the Case stays in `PendingApproval` (how the score treats it belongs to story 2.4).
- **Operator chooses `REQUEST_REVIEW` in the resolution**: refused (API-Q3); the resolution accepts only `RETRY`, `APPLY_APPROVED_MAPPING`, `HOLD` or cancellation.
- **Validator refuses the Action chosen by the Operator** (UJ-4 step 2): no transition; only `ValidatorVerdict` is recorded; the Case stays in `ReviewRequired`.
- **Canonical Receipt disappears on a terminal Case**: `receipt_missing` annotation and an alert to the Operator; the state does not change and no new Case is opened (there is no new Exception).
- **Restart with a Case in a transient state** (`Open`, `DecisionProposed`, `Rejected`, `Approved`): the sweeper redispatches the pending outbox entry or, if there is none, issues `Resume`; nothing is re-executed without re-reading the Case.

## Requirements *(mandatory)*

### Vocabulary

- **Terminal state**: `Resolved`, `ResolvedByPriorReceipt`, `Cancelled`, `Failed`. No transition leaves them.
- **Waiting** (non-terminal, persisted with no work in flight): `Held` (technical wait, leaves through Reassessment) and `ReviewRequired` (human wait, leaves through an Operator action). `PendingApproval` is also a human wait, but it is active.
- **Transient** (the follow-up work is dispatched in the same transaction): `Open`, `DecisionProposed`, `Rejected`, `Approved`.
- **Transition**: changes the state, increments `caseVersion` and records, in the same transaction, the new state, the Timeline events (always including `StateChanged {from, to, reason, caseVersionAfter}`) and the outbox entries. It is a compare-and-swap on `caseVersion`, the expected state and the target (`proposalId` or `executionId`).
- **Attachment**: changes neither state nor `caseVersion`; records Evidence, a verdict, Revalidation, Reconciliation, a received Exception or an annotation. Each state accepts only the attachments listed in the attachments table.
- **Actors**: `system` (Application and Production flow acting on a command), `agent`, `rules`, `replay` (proposers; must match the Case's mode), `benchmark` (only the Benchmark Automatic Approval, only in a BenchmarkRun), `sweeper` (the only task with a clock), `operator:<name>`.
- **Work commands** (outbox): `Investigate`, `Execute`, `Reconcile`, `Expire`, `Reassess`, `Resume`.

### Normative transition table

Every transition emits `StateChanged {from, to, reason, caseVersionAfter}`; the "Events" column lists only the additional events, in the order they enter the Timeline. "Same step" means the next transition is made by the same processing, without going through the outbox.

| Id | From → To | Trigger | Actor | Verifiable preconditions | Events (besides `StateChanged`) | Follow-up work |
|---|---|---|---|---|---|---|
| T01 | — → `Open` | 1st Exception for an `orderId` | `system` | Order exists with snapshot and Equivalence Key; no non-terminal Case for the `orderId`; no previous Case for the `orderId` | `CaseOpened`, `ExceptionRecorded` | outbox `Investigate` |
| T02 | — → `Open` (new episode) | Exception for an `orderId` whose most recent Case is terminal, or Exception attached during the Execution of a Case that ends in `Failed` (T25) | `system` | No non-terminal Case for the `orderId`; the previous Case is in a terminal state | On the new Case: `CaseOpened` (with `previousEpisodeCaseId`), `ExceptionRecorded`. On the previous one: `Annotation` `new_episode_opened` (attachment, no transition) | outbox `Investigate` |
| T03 | `Open` → `Investigating` | `Investigate` command | `system` | State `Open`; `caseVersion` = the command's `caseVersionAfter` | — (records `stepLeaseUntil`) | Investigation: collection through the Tools port (each call becomes `ToolCalled` by attachment) and a call to the proposer of the Case's mode |
| T04 | `Investigating` → `DecisionProposed` | Proposer returns a valid Proposal within budget | `agent`, `rules` or `replay` (same as the Case's mode) | State `Investigating`; lease of the same Investigation still valid; valid Proposal DTO; every Diagnosis claim cites Evidence of the Case | `ProposalCreated` (the previous Proposal, if any, stops being current) | Validator in the same step (T07 to T10) |
| T05 | `Investigating` → `ReviewRequired` | Budget exceeded, invalid response, Agent refusal or Provider unavailable (FR-4) | `system` | State `Investigating`; lease still valid | `DossierCreated` (reason `budget_exceeded`, `invalid_agent_response`, `agent_refusal` or `provider_unavailable`, with the Evidence collected so far) | Dossier; waits for the Operator |
| T06 | `Investigating` → `ReviewRequired` | Investigation interrupted (restart or lost work) | `sweeper` | State `Investigating`; `stepLeaseUntil` < now | `DossierCreated` (reason `investigation_interrupted`) | Dossier; a late proposer answer will be discarded |
| T07 | `DecisionProposed` → `PendingApproval` | Verdict `accepted` with `requiresApproval = true` | `system` | Current Proposal; verdict recorded for that `proposalId` | `ValidatorVerdict` | Outside a BenchmarkRun: none (human wait). In a BenchmarkRun: T12 in the same step. In the Operator resolution: T11 in the same step |
| T08 | `DecisionProposed` → `Executing` | Verdict `accepted` with `requiresApproval = false` (only `HOLD`) | `system` | Action `HOLD`; verdict recorded; no Execution of the Case in `reconciling` | `ValidatorVerdict`, `ExecutionAuthorized` | outbox `Execute` (the outcome is T20) |
| T09 | `DecisionProposed` → `ResolvedByPriorReceipt` | Verdict `prior_receipt_confirmed` (FR-47) | `system` | Candidate Receipt and raw snapshot of the associated Order obtained through Tools and recorded as Evidence; Equivalence Keys canonicalized by the Core are equal | `ValidatorVerdict`, `ReceiptRecorded` (link to the prior Receipt) | None (terminal); no Execution |
| T10 | `DecisionProposed` → `ReviewRequired` | Verdict `blocked` or `review` | `system` | Verdict recorded for the current Proposal | `ValidatorVerdict`, `DossierCreated` (reason `validator_blocked`, `missing_evidence`, `low_confidence`, `prior_receipt_unconfirmed` with the candidate, `ambiguous_identity` or `review_requested`) | Dossier; waits for the Operator |
| T11 | `PendingApproval` → `Approved` | Operator approves | `operator:<name>` | State `PendingApproval`; `proposalId` = current Proposal; `expectedCaseVersion` = `caseVersion` | `ApprovalRecorded` (`decision = approved`, `expiresAt` = now + 15 min) | outbox `Execute` |
| T12 | `PendingApproval` → `Approved` | Benchmark Automatic Approval | `benchmark` | The Case belongs to a BenchmarkRun; issued in the same step as T07 | `ApprovalRecorded` (`by = benchmark`) | outbox `Execute` |
| T13 | `PendingApproval` → `Rejected` | Operator denies with a reason | `operator:<name>` | Same as T11; non-empty reason; `denialCount` < 2. Increments `denialCount` in the same transaction | `ApprovalRecorded` (`decision = denied`); reason recorded as Evidence `operator.denial_reason` | outbox `Investigate` (the flow picks T14 or T15 from the counter) |
| T14 | `Rejected` → `Investigating` | `Investigate` command with `denialCount = 1` | `system` | State `Rejected`; `denialCount` = 1; `caseVersion` = `caseVersionAfter` | — (records `stepLeaseUntil`; the denial Evidence enters the base package) | Investigation, as in T03 |
| T15 | `Rejected` → `ReviewRequired` | `Investigate` command with `denialCount = 2` | `system` | State `Rejected`; `denialCount` = 2 | `DossierCreated` (reason `second_denial`) | Dossier; waits for the Operator |
| T16 | `PendingApproval` → `Investigating` | New Exception for the same Order (Decision D1) | `system` | State `PendingApproval`; `orderId` equal to the Case's | `ExceptionRecorded` (the current Proposal stops being current; open screens receive `STALE_VERSION`) | Investigation, as in T03 |
| T17 | `Approved` → `Executing` | `Execute` command: authorization CAS | `system` | State `Approved`; `approved` Approval of the current Proposal; now < `expiresAt`; no Execution of the Case in `in_progress` or `reconciling`; `caseVersion` = `caseVersionAfter`. If the Approval expired, the command is refused and the Case stays in `Approved` | `ExecutionAuthorized` (`executionId`, effect key, lease) | In the same processing: Revalidation, prior Reconciliation by `orderId`, send (AD-5) |
| T18 | `Approved` → `PendingApproval` | `Expire` command (FR-18) | `sweeper` | State `Approved`; `expiresAt` ≤ now; no authorization recorded | `ApprovalExpired` | None; the same Proposal stays current and needs a new Approval |
| T19 | `Executing` → `Held` | Revalidation: `PARTNER_HEALTHY_WINDOW` false (Partner unstable or maintenance window) | `system` | Execution in `in_progress` with no Attempt sent | `RevalidationPerformed` (failed rows). The Execution closes with `outcome = held` and the authorization is voided in the same transaction | Reassessment every 60 s (the sweeper issues `Reassess`) |
| T20 | `Executing` → `Held` | Execution of `HOLD` | `system` | The Execution's Action is `HOLD` | `RevalidationPerformed`; the Execution closes with `outcome = held` | Reassessment every 60 s |
| T21 | `Executing` → `Cancelled` | Revalidation: `ORDER_ACTIVE_AT_ORIGIN` false | `system` | Execution in `in_progress` with no Attempt sent | `RevalidationPerformed`; the Execution closes with `outcome = cancelled`; authorization voided | None (terminal); no effect |
| T22 | `Executing` → `Investigating` | Revalidation: `POLICY_VERSION_UNCHANGED` or `MAPPING_VERSION_UNCHANGED` false | `system` | Execution in `in_progress` with no Attempt sent | `RevalidationPerformed`; the Execution closes with `outcome = cancelled`; authorization voided; the Proposal stops being current | Investigation (new Proposal and new Approval) |
| T23 | `Executing` → `Resolved` | Partner response classified `success` with a valid Receipt | `system` | Receipt with the Execution's `orderId` and effect key | `AttemptRecorded`, `ReceiptRecorded`; the Execution closes with `outcome = resolved` | None (terminal). Exceptions attached during the Execution stay recorded only |
| T24 | `Executing` → `Resolved` | Prior Reconciliation or Reconciliation finds a Receipt (FR-23) | `system` | Receipt returned by the Partner for the `orderId` or for the effect key | `ReconciliationPerformed`, `ReceiptRecorded`; the Execution closes with `outcome = resolved` | None (terminal); no resend |
| T25 | `Executing` → `Failed` | Policy Attempts exhausted | `system` | No Attempt with an unknown outcome pending (the last one was `business_error` or `transient`, or a conclusive Reconciliation said "not delivered") | `AttemptRecorded`; the Execution closes with `outcome = failed` | If an Exception was attached during `Approved`/`Executing`: T02 in the same transaction (new episode). Otherwise, none |
| T26 | `Executing` → `ReviewRequired` | Reconciliation inconclusive after 3 rounds (Decision D4) | `system` | Execution in `reconciling`; inconclusive rounds ≥ 3 | `ReconciliationPerformed`, `DossierCreated` (reason `outcome_unknown`). The Execution **stays** `reconciling` | Dossier; new sends for the Order blocked until a conclusive Reconciliation |
| T27 | `Held` → `Investigating` | `Reassess` command finds that the waiting condition is over (FR-51) | `system` | State `Held`; new Evidence of a stable Partner or of the end of the Policy window | `ReassessmentPerformed` | Investigation (new Proposal; the previous Approval is never reused, AD-7) |
| T28 | `ReviewRequired` → `DecisionProposed` | Operator resolution with a Catalog Action (FR-29) | `operator:<name>` | State `ReviewRequired`; `expectedCaseVersion` = `caseVersion`; Action ∈ {`RETRY`, `APPLY_APPROVED_MAPPING`, `HOLD`}; the Validator accepts the Proposal before anything is recorded | `OperatorResolution`, `ProposalCreated` (author `operator:<name>`) | In the same step: T07 followed by T11 with the same Operator, or T08 for `HOLD` |
| T29 | `ReviewRequired` → `Cancelled` | Operator resolution by cancellation | `operator:<name>` | State `ReviewRequired`; `expectedCaseVersion` = `caseVersion`; non-empty reason | `OperatorResolution` | None (terminal) |

### Entries and exits per state

| State | Class | Entered by | Left by |
|---|---|---|---|
| `Open` | active, transient | T01, T02 | T03 |
| `Investigating` | active | T03, T14, T16, T22, T27 | T04, T05, T06 |
| `DecisionProposed` | active, transient | T04, T28 | T07, T08, T09, T10 |
| `PendingApproval` | active, human wait | T07, T18 | T11, T12, T13, T16 |
| `Approved` | active, transient | T11, T12 | T17, T18 |
| `Rejected` | active, transient | T13 | T14, T15 |
| `Executing` | active | T08, T17 | T19, T20, T21, T22, T23, T24, T25, T26 |
| `Held` | waiting | T19, T20 | T27 |
| `ReviewRequired` | waiting | T05, T06, T10, T15, T26 | T28, T29 |
| `Resolved` | terminal | T23, T24 | — |
| `ResolvedByPriorReceipt` | terminal | T09 | — |
| `Cancelled` | terminal | T21, T29 | — |
| `Failed` | terminal | T25 | — |

### Attachments allowed per state (no transition)

| Attachment | States that accept it | Actor | Note |
|---|---|---|---|
| New Exception for the same Order (`ExceptionRecorded`) | `Open`, `Investigating`, `DecisionProposed`, `Rejected`, `Approved`, `Executing`, `Held`, `ReviewRequired` | `system` | In `PendingApproval` it is a transition (T16). In a terminal state it is a new episode (T02). In `Approved`/`Executing` it is flagged for reassessment at the end of the Execution (T23 or T25). In `ReviewRequired` it also updates the Dossier |
| Tool call / Evidence (`ToolCalled`, `EvidenceObsoleted`) | `Investigating`, `Held` (Reassessment) | `system`, `agent`, `rules`, `replay` | Every call through the Tools port |
| Validator verdict without transition (`ValidatorVerdict`) | `ReviewRequired` | `system` | Operator resolution refused (UJ-4 step 2) |
| Passed Revalidation (`RevalidationPerformed`) | `Executing` | `system` | Before the send |
| Attempt (`AttemptRecorded`) | `Executing` | `system` | Policy Attempts belong to the Execution, never an Exception of the Case |
| Reconciliation (`ReconciliationPerformed`) | `Executing`, `ReviewRequired` (Execution still `reconciling`) | `system` | A conclusive Reconciliation in `ReviewRequired` closes the Execution and updates the Dossier, without a transition |
| Reassessment with no change (`ReassessmentPerformed`) | `Held` | `system` | The waiting condition still holds |
| Annotation (`Annotation`) | all, including terminal | `system`, `operator:<name>` | In a terminal state, only `receipt_corrected`, `receipt_missing` and `new_episode_opened` |
| Command refusal (`CommandDiscarded`) | all, including terminal | the actor of the refused command | See FR-012 |

### Recorded decisions on the contradictions

- **D1 — New Exception on a non-terminal Case (contradiction 1).** The §D rule "any non-terminal → `Investigating`" is revoked. The per-state rule is: in `PendingApproval` it is a transition to `Investigating` (T16), because nobody has committed to the Proposal yet and FR-3 asks for a new Investigation; in every other non-terminal state it is an attachment. In `Open`, `Investigating`, `DecisionProposed` and `Rejected`, the running or the next Investigation will read the Exception; a running Investigation is not restarted, and the Exception enters as Evidence if collection is still open. In `Approved` and `Executing` AD-24 applies: an attachment reassessed at the end of the Execution (T23 leaves it recorded only; T25 opens a new episode). In `Held` it does not bring the exit forward, which happens only through Reassessment (FR-51). In `ReviewRequired` it enters the Dossier, and the exit is still only the Operator's (FR-29). *Reason:* no Exception pulls a Case out of an Execution in flight or out of a wait with a defined owner.
- **D2 — `Failed` stays terminal (contradiction 2).** AD-24's "`Failed → Investigating`" is replaced by: on entering `Failed`, if an Exception was attached during `Approved` or `Executing`, the system opens in the same transaction a new Case (T02), related to the failed one and carrying those Exceptions. Without an attached Exception, `Failed` is the final outcome shown to the Operator. *Reason:* it preserves the rule "terminal never reopens" (Principle V) without losing the reassessment AD-24 wanted.
- **D3 — Revalidation failing after the authorization CAS (contradiction 3).** The AD-5 order (authorization CAS, then Revalidation) is kept. Instead of §D's `Approved → Held` and `Approved → Cancelled`, the transitions are `Executing → Held` (T19), `Executing → Cancelled` (T21) and `Executing → Investigating` (T22, Policy or Mapping version changed, which requires a new Proposal). Precedence when several fail: `Cancelled` > `Investigating` > `Held`. In all of them, no Attempt was sent, the Execution closes with `outcome` `held` or `cancelled` and **the recorded authorization is voided in the same transaction**: it cannot be reused, and any future effect requires a new Proposal and a new Approval. `Executing → PendingApproval` does **not** exist: Approval validity is checked at the authorization CAS (T17), and the Execution BO refuses the CAS for an expired Approval, leaving the Case in `Approved` for the sweeper to apply T18. Revalidation evaluates `APPROVAL_VALID` against the authorization instant. `Approved → PendingApproval` happens only by expiration (T18). New Evidence that makes a declared precondition false (FR-18) is caught by Revalidation, which follows the same table. *Reason:* a single owner for expiration (the sweeper) and a single moment for checking preconditions.
- **D4 — Unknown outcome with no Receipt (contradiction 4).** With the Execution in `reconciling`: (a) Receipt found → T24; (b) the Partner answers conclusively that there is no Receipt either for the effect key or for the `orderId` → the Attempt is declared "not delivered", the Execution returns to `in_progress` and, if the Policy has Attempts left, makes a new Attempt **with the same effect key** (the Partner deduplicates key + payload); with no Attempts left → T25; (c) the Reconciliation itself fails or is inconclusive → it stays `reconciling`, the sweeper reissues `Reconcile` after the lease, and after 3 inconclusive rounds → T26 to `ReviewRequired` with reason `outcome_unknown`. While an Execution is in `reconciling`, no new send for the same Order happens, including one from a new Operator Proposal: the prior Reconciliation of the new Execution must be conclusive, and it also closes the earlier uncertain Execution. The sweeper never moves `Executing` to `ReviewRequired` (AD-22); T26 is done by `system`. *Reason:* uncertainty stays distinct from failure and from waiting (Principle VII) and blocks effects (Principle VI).
- **D5 — Receipt divergence on a terminal Case (contradiction 5, review M-7).** Correcting the Receipt copy is an `Annotation` attachment of kind `receipt_corrected`, with the previous and the new copy; the Partner prevails (AD-14). If the canonical Receipt no longer exists, the annotation is `receipt_missing` and raises an alert to the Operator. Neither changes state or `caseVersion` or opens a new Case. *Reason:* terminal never reopens, and nobody invents `Resolved → Resolved`.

### Functional Requirements

- **FR-001**: The system MUST accept exactly transitions T01 to T29 and no other. Each transition can be made only by the actors in its row.
- **FR-002**: The system MUST treat `Resolved`, `ResolvedByPriorReceipt`, `Cancelled` and `Failed` as terminal: no transition leaves them, and they accept only the `Annotation` attachments (`receipt_corrected`, `receipt_missing`, `new_episode_opened`) and `CommandDiscarded`.
- **FR-003**: The system MUST keep at most one non-terminal Case per `orderId`. An Exception for the same Order follows Decision D1 if there is a non-terminal Case, and opens a new episode (T02) if the most recent Case is terminal.
- **FR-004**: A Case opened as a new episode MUST reference the previous Case (`previousEpisodeCaseId`), and the previous Case MUST gain the `new_episode_opened` annotation with the new Case's identifier, without changing state or `caseVersion`.
- **FR-005**: Every transition MUST record, in the same atomic operation, the new state, the incremented `caseVersion`, `StateChanged {from, to, reason, caseVersionAfter}`, the other events of its row and the outbox entries of the follow-up work. If any part fails, nothing is recorded.
- **FR-006**: The system MUST keep `denialCount` on the Case, incremented only by T13, never reset within the same Case (neither by T22 nor by T27), with at most one new Investigation after `Rejected` (T14) and `ReviewRequired` on the second denial (T15).
- **FR-007**: Only the `sweeper` actor MUST be able to expire an Approval (T18). The Execution BO MUST refuse the authorization CAS when the Approval has expired, without changing the state.
- **FR-008**: New Evidence MUST invalidate an Approval only if it makes a declared precondition false, and that MUST be decided by Revalidation according to Decision D3.
- **FR-009**: A Case in `Held` MUST leave only through T27, when the periodic Reassessment (every 60 s) finds that the waiting condition is over.
- **FR-010**: A Case in `ReviewRequired` MUST leave only through an Operator action: T28 (Catalog Action accepted by the Validator) or T29 (cancellation). If the Validator refuses the Action, nothing but the verdict is recorded.
- **FR-011**: `ResolvedByPriorReceipt` MUST happen only through T09, with the Validator verdict `prior_receipt_confirmed`. An unconfirmed candidate MUST lead to `ReviewRequired` with the candidate in the Dossier (T10).
- **FR-012**: A command with an unlisted transition MUST be refused with `INVALID_TRANSITION`; with an unlisted actor, with `INVALID_ACTOR`; with a stale version, with `STALE_VERSION`. In all cases the state and `caseVersion` stay the same and the Timeline gains `CommandDiscarded` with command, actor, current state, requested state and code.
- **FR-013**: The `benchmark` actor MUST be accepted only in T12 and only on a BenchmarkRun Case. The actors `agent`, `rules` and `replay` MUST be accepted only in T04 and only when they match the Case's mode.
- **FR-014**: A repeated Approval of the same already-approved `proposalId` MUST return the existing Approval with no transition and no new effect, even with a stale `expectedCaseVersion`.
- **FR-015**: When Revalidation fails after T17, the recorded authorization MUST be voided in the same exit transaction (T19, T21 or T22) and never reused.
- **FR-016**: While the Case has an Execution in `reconciling`, the system MUST NOT authorize a new send for the same Order until a conclusive Reconciliation (Decision D4).
- **FR-017**: The sweeper MUST be the only component with a clock and MUST NOT produce an external effect. It issues only T06, T18 and the commands `Reassess`, `Reconcile` and `Resume`, besides redispatching pending outbox entries.
- **FR-018**: On resuming after a restart, the per-state handling MUST be: `Investigating` with an expired lease → T06; `Executing` with an expired lease → `Reconcile`; `Open`, `DecisionProposed`, `Rejected` and `Approved` → outbox redispatch or `Resume`; `PendingApproval`, `Held`, `ReviewRequired` and terminal states → kept.
- **FR-019**: The table in this specification MUST be the only normative source of transitions. `addendum.md` §D and the "Pontos fixados" table of AD-24 MUST be marked as replaced by it, and PRD FR-5 MUST point to it.
- **FR-020**: The HTTP contract 1.0.0 (story 2.5) MUST incorporate the changes listed in "Resulting contract changes".

### Journey trace (UJ-1 to UJ-4)

| Journey and step | Transition or rule | Actor |
|---|---|---|
| UJ-1 before step 1: Exception, Investigation, Proposal `APPLY_APPROVED_MAPPING` | T01, T03, T04, T07 | `system`, `system`, `agent`, `system` |
| UJ-1 steps 1–4: Carla reads the Case in `PendingApproval` | none (read only) | — |
| UJ-1 step 5: approves | T11 | `operator:Carla` |
| UJ-1 step 6: Approved → Executing → Resolved, Revalidation before the send | T17, `RevalidationPerformed` (attachment), T23 | `system` |
| UJ-1 step 7: Approve again | FR-014 (no transition) | `operator:Carla` |
| UJ-2 step 1: approves `RETRY` | T11 | `operator:Carla` |
| UJ-2 steps 2–3: Revalidation finds the Partner unstable, "nothing was sent" | T17, T19; `ReassessmentPerformed` every 60 s | `system` |
| UJ-2 step 4: Partner recovers, new Proposal, new Approval | T27, T04, T07, T11 | `system`, `agent`, `system`, `operator:Carla` |
| UJ-2 step 5 (variant): Order cancelled at the Origin | T17, T21 | `system` |
| UJ-3 steps 1–3: prior Receipt confirmed, Execution layer empty | T01, T03, T04, T09 | `system`, `system`, `agent`, `system` |
| UJ-4 step 1: Case in `ReviewRequired` (ambiguous identity) | T04, T10 (`ambiguous_identity`) | `agent`, `system` |
| UJ-4 step 2: tries `RETRY`, the Validator blocks | FR-010 (only `ValidatorVerdict`, no transition) | `operator:Carla` |
| UJ-4 step 3: cancels with a reason | T29 | `operator:Carla` |
| UJ-4 step 4 (variant): Provider unavailable; chooses the PLASMA Mapping; resolves | T05 (`provider_unavailable`), T28, T07, T11, T17, T23 | `system`, `operator:Carla` (T28, T11), `system` |

### Resulting contract changes (input to story 2.5)

- `CaseHeader` gains `previousEpisodeCaseId` (null in the first episode). The previous Case's detail shows the link through the `new_episode_opened` annotation.
- `Dossier.reason` gains the value `outcome_unknown` (T26).
- The `Annotation` payload gains `kind`, with at least `receipt_corrected`, `receipt_missing` and `new_episode_opened`.
- The `CommandDiscarded` payload is `{command, actor, currentState, requestedState, code}`, with `code` ∈ `INVALID_TRANSITION`, `INVALID_ACTOR`, `STALE_VERSION`, `APPROVAL_EXPIRED`.
- The description of `CaseSummary.executionOutcome` allows `reconciling` also with the Case in `ReviewRequired` (T26).
- API-Q5 is closed as proposed: the resolution goes through `ReviewRequired → DecisionProposed → PendingApproval → Approved` in one transaction, with one `StateChanged` per step. API-Q3 is closed as proposed: the resolution does not accept `REQUEST_REVIEW`.
- `TimelineEventType` and `CaseState` do not change.

### Key Entities

- **Case**: aggregate with `state`, `caseVersion`, `denialCount`, `stepLeaseUntil`, the current Proposal, `previousEpisodeCaseId` and a mode marker (`agent`, `rules` or `replay`, plus the BenchmarkRun when there is one).
- **Transition**: a table row (Id, from, to, trigger, actors, preconditions, events, follow-up work). Closed vocabulary of the Core.
- **Command**: a request for a transition or for work, with actor, expected state, expected `caseVersion` and target; the work commands are `Investigate`, `Execute`, `Reconcile`, `Expire`, `Reassess` and `Resume`.
- **Approval**: a decision on a `proposalId` with `expiresAt`; consumed by the authorization CAS.
- **Execution**: a recorded authorization with `outcome` (`in_progress`, `reconciling`, `resolved`, `held`, `cancelled`, `failed`), Attempts and Reconciliation rounds.
- **Timeline event**: `{seq, at, type, actor, refId, payload}`, append-only; `StateChanged` on every transition.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: The 13 values of `CaseState` appear in the "Entries and exits per state" table; the 9 non-terminal ones have at least one entry and one exit, and the 4 terminal ones have at least one entry and no exit.
- **SC-002**: José, without Henry's help, maps 100% of the steps of UJ-1 to UJ-4 to a transition or rule of the table in a session of at most 30 minutes, and his mapping matches "Journey trace".
- **SC-003**: 100% of rows T01 to T29 have an actor, a verifiable precondition and at least one Timeline event.
- **SC-004**: The 5 contradictions listed in the ticket appear as decisions D1 to D5, each with a rule and a reason.
- **SC-005**: The three invalid commands of User Story 2 (including `Open → Executing`) are described as refused and recorded, without changing state or `caseVersion`.
- **SC-006**: In Henrique's review, no transition is left open or with two owners; and, between 10/26 and the freeze of contract 1.0.0, no front opens a transition change request that this table does not already answer.

## Assumptions

- Approval validity of 15 min (FR-18) and Reassessment every 60 s (FR-51), as decided in the PRD.
- The number of inconclusive Reconciliation rounds before T26 is 3. It is a starting value, adjustable in the Plan without changing the table.
- The attempt Policy and its limit belong to the Execution BO and do not change the table; only "exhausted" matters (T25).
- `HOLD` does not require Approval in v1 (FR-16) and goes through `Executing` with no external effect, as in §D.
- The Investigation after `Held` (T27) or after a changed version (T22) uses the same proposer as the Case's mode.
- A candidate Receipt found during the Execution for **another** `orderId` does not lead to `ResolvedByPriorReceipt` in this version: Reconciliation searches by the effect key and by the `orderId`. The P9 path is only through the Investigation (T09).
- How BenchmarkRun Cases that expire in `PendingApproval` are scored belongs to story 2.4.
- Out of scope: code (starts on 10/26); derivation of `commandId`, `executionId` and the effect key (story 2.3, API-Q11), referred to here only as "effect key"; variant catalog and Answer Key (2.4); freezing OpenAPI 1.0.0 (2.5).
- Sources: `addendum.md` §C and §D; `prd-signal-noir.md` FR-3, FR-4, FR-5, FR-15 to FR-24, FR-29, FR-47, FR-51; `architecture-signal-noir.md` AD-2 to AD-8, AD-12, AD-14, AD-19 to AD-24; `reviews/review-adversarial.md` H-1, H-2, M-7; `reviews/reconcile-prd.md` findings 9, 11 and 12; `contracts/openapi-signalnoir.yaml` (`CaseState`, `Actor`, `TimelineEventType`, `ExecutionOutcome`, `Dossier.reason`, API-Q3, API-Q5); `ux-signal-noir/EXPERIENCE.md` UJ-1 to UJ-4; Constitution 1.1.0, Principles IV to VII.
