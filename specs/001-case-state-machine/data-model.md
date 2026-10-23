# Data Model: Normative Case state machine

**Feature**: [spec.md](spec.md) | **Plan**: [plan.md](plan.md)

The model has two parts. Part 1 is what this story delivers: the table as data, in `contracts/case-state-machine.yaml`. Part 2 is the fields of the Case aggregate the table reads and writes, a reference for Phase B (code from 10/26) and for 2.5 (contract).

## Part 1 — The table as data

### StateMachine (YAML root)

| Field | Type | Rule |
|---|---|---|
| `version` | semver | `1.0.0` at the freeze; changes by the Constitution's semver rules |
| `supersedes` | list of text | `addendum.md §D`, `architecture-signal-noir.md AD-24 (Pontos fixados)` |
| `parameters` | map | `approvalTtl`, `reassessInterval`, `maxInconclusiveReconciliations`, `maxDenials` (R6) |
| `states` | list of State | exactly the 13 values of `CaseState` |
| `transitions` | list of Transition | T01–T29; unique, stable Ids |
| `attachments` | list of Attachment | the spec's attachments table |
| `refusals` | list of RefusalRule | `INVALID_TRANSITION`, `INVALID_ACTOR`, `STALE_VERSION`, `APPROVAL_EXPIRED` |
| `decisions` | list of Decision | D1–D5 |
| `journeyTrace` | list of TraceStep | UJ-1 to UJ-4 |

### State

| Field | Type | Rule |
|---|---|---|
| `name` | `CaseState` | unique |
| `class` | enum `active`, `waiting`, `terminal` | `Held` and `ReviewRequired` = `waiting`; the 4 terminal states = `terminal` |
| `transient` | bool | `true` for `Open`, `DecisionProposed`, `Rejected`, `Approved` |
| `restart` | enum `keep`, `sweeperReview`, `sweeperReconcile`, `redispatch` | FR-018 |

Validation: a `terminal` state does not appear in `from`; every non-terminal state appears in at least one `to` (or is the creation target, in the case of `Open`) and in at least one `from`.

### Transition

| Field | Type | Rule |
|---|---|---|
| `id` | `T\d{2}` | unique; never reused |
| `from` | `CaseState` or `null` | `null` only in T01 and T02 (creation) |
| `to` | `CaseState` | — |
| `trigger` | text | readable trigger |
| `command` | command enum or `null` | the command that fires it, when there is one (`Investigate`, `Execute`, `Reconcile`, `Expire`, `Reassess`, `Resume`) or the API command (`decideProposal`, `resolveReview`) |
| `actors` | list of `Actor` patterns | not empty; `operator:*` stands for any name |
| `preconditions` | list of Precondition | not empty |
| `events` | list of `TimelineEventType` | `StateChanged` is implicit and is **not** listed; may be empty only when the transition emits nothing besides `StateChanged` |
| `effectsOnRecords` | list of text | e.g. "increments denialCount", "authorization voided", "Execution closes with outcome=held" |
| `followUp` | FollowUp | follow-up work |
| `sameStepAs` | list of Id | transitions chained in the same step (T07→T11/T12, T28→T07→T11) |
| `decision` | Decision Id or `null` | D1–D5 when the row comes from a decision |
| `pendingContractChange` | `"2.5"` or absent | marks values not yet in the OpenAPI (R3) |
| `contractChanges` | list of `C\d` | items of [contracts/openapi-delta.md](contracts/openapi-delta.md) the marker covers; also valid in `attachments` and `refusals` |

### Precondition

| Field | Type | Rule |
|---|---|---|
| `check` | identifier | closed vocabulary of this table (below) |
| `expected` | value | comparable literal, or the name of a parameter |

Initial `check` vocabulary: `state`, `caseVersionMatches`, `proposalIsCurrent`, `noOpenCaseForOrder`, `previousCaseTerminal`, `leaseValid`, `leaseExpired`, `proposerMatchesMode`, `verdict`, `requiresApproval`, `action`, `benchmarkRun`, `approvalNotExpired`, `approvalExpired`, `noAuthorization`, `noExecutionInFlight`, `noAttemptSent`, `revalidationFailed` (with the name of the OpenAPI `PreconditionCheck`), `receiptMatches`, `attemptsExhausted`, `inconclusiveReconciliations`, `waitConditionEnded`, `denialCount`, `reasonPresent`, `resolutionAction`, `newException`. It differs from the OpenAPI `PreconditionCheck`, which is the vocabulary of the preconditions declared in a Proposal.

### FollowUp

| Field | Type | Rule |
|---|---|---|
| `outbox` | list of commands | entries recorded in the same transaction |
| `inProcess` | text or `null` | work done by the same processing (Validator, Revalidation) |
| `dossier` | bool | creates a Dossier |
| `terminal` | bool | no follow-up work |

### Attachment

| Field | Type |
|---|---|
| `event` | `TimelineEventType` |
| `states` | list of `CaseState`, or `"*"` for all |
| `actors` | list of `Actor` patterns |
| `kinds` | list of text (only on `Annotation`) |
| `terminalKinds` | subset of `kinds` accepted in terminal states (only on `Annotation`) |
| `note` | text |

### RefusalRule

`code`, `when` (text), `records` (`CommandDiscarded`), `httpStatus` (409 or 403 when exposed by the API), `changesState: false`.

### Decision

`id` (D1–D5), `contradiction` (1–5), `replaces` (the §D or AD-24 line it replaces), `rule`, `reason`, `forbids` (list of (from, to) pairs no row may have), and for D1 `exceptionTriggersOnlyFrom` (the only origin states a row triggered by a new Exception may leave).

### TraceStep

`journey` (`UJ-1`…`UJ-4`), `step` (the text of the spec's first column up to the colon, e.g. "step 5" or "step 4 (variant)"), `refs` (list of transition Ids or rules such as `FR-014`), `actors`, optional `note`.

## Part 2 — Aggregate fields the table uses

| Case field | Written by | Read by |
|---|---|---|
| `state`, `caseVersion` | every transition | every CAS precondition |
| `denialCount` (0–2) | T13 | T13, T14, T15 |
| `stepLeaseUntil` | T03, T14, T16, T22, T27 (Investigation), T17 (Execution) | T04, T05, T06, the sweeper in `Executing` |
| `currentProposalId` | T04, T28; cleared (no longer current) in T16, T22 | T07–T11, T13, T17 |
| `previousEpisodeCaseId` | T02 | interface, Bench |
| `pendingReassessmentExceptions` (Exceptions attached in `Approved`/`Executing`) | Exception attachment | T23, T25 (decides T02) |
| `proposerMode`, `benchmark.runId` | T01, T02 | T04 (actor), T12 |
| Approval `expiresAt`, `decision` | T11, T12, T13 | T17, T18 |
| Execution `outcome`, `inconclusiveReconciliations`, voided authorization | T17–T26 | T08, T17, D4, FR-016 |

Aggregate invariants the Phase B Core must guarantee:
- at most one non-terminal Case per `orderId` (conditional unique index);
- at most one Execution per Case in `in_progress` or `reconciling`;
- `denialCount` ≤ `maxDenials`;
- one current Proposal at a time;
- a voided authorization never becomes valid again.
