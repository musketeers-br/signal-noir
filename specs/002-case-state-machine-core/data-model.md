# Data Model: Case state machine Core (Phase B)

**Feature**: [spec.md](spec.md) | **Plan**: [plan.md](plan.md)

Class names are provisional, tied to the ObjectScript choice of research R1 (SPIKE-DEPENDENT). Field semantics come from specs/001 data-model Part 2 and do not depend on the language.

## Core value objects (`SignalNoir.Core`, no persistence, no I/O)

### CaseSnapshot

What `Decide` reads. Built by the Application from the stored Case and its children.

| Field | Type | Notes |
|---|---|---|
| `CaseId` | string `case_…` | |
| `OrderId` | string | |
| `State` | `CaseState` (13 values) | |
| `CaseVersion` | integer ≥ 1 | incremented by every transition |
| `DenialCount` | integer 0–2 | spec 001 FR-006 |
| `StepLeaseUntil` | UTC timestamp or empty | Investigation and Execution leases |
| `CurrentProposalId` | `prop_…` or empty | |
| `ProposerMode` | `agent`, `rules`, `replay` | from the BenchmarkRun or `agent` |
| `BenchmarkRunId` | `run_…` or empty | |
| `Approval` | `{ proposalId, decision, expiresAt }` or empty | latest Approval of the current Proposal |
| `Execution` | `{ executionId, outcome, attemptsSent, inconclusiveReconciliations, authorizationVoided }` or empty | latest Execution |
| `PendingReassessmentExceptions` | integer ≥ 0 | Exceptions attached in `Approved`/`Executing` |
| `PreviousEpisodeCaseId` | `case_…` or empty | |
| `LatestCaseForOrderIsTerminal` | boolean | for T01/T02, filled by the Application |

### TransitionCommand

| Field | Type | Notes |
|---|---|---|
| `CommandId` | `cmd_…` | idempotency of work items (AD-20) |
| `Kind` | `Transition` or `Attach` | |
| `RequestedState` | `CaseState` or empty | empty for attachments |
| `AttachEvent` | `TimelineEventType` or empty | for attachments |
| `Actor` | `Actor` pattern | |
| `ExpectedState` | `CaseState` | |
| `ExpectedCaseVersion` | integer | |
| `TargetId` | `prop_…` or `exec_…` or empty | |
| `Facts` | `%DynamicObject` | verdict, revalidation failures, response class, reconciliation result, decision, reason, `newException` — only what was already recorded |

### Decision

| Field | Type | Notes |
|---|---|---|
| `Kind` | `Accepted`, `Refused`, `Attach` | |
| `TransitionId` | `T01`…`T29` or empty | |
| `ToState` | `CaseState` or empty | |
| `Events` | list of `{ type, payload }` | `StateChanged` included, built by the Core with `caseVersionAfter` |
| `RecordEffects` | list of named effects | e.g. `IncrementDenialCount`, `VoidAuthorization`, `CloseExecution(outcome)`, `SetStepLease`, `ClearCurrentProposal`, `OpenNewEpisode` |
| `Outbox` | list of work-item kinds | `Investigate`, `Execute`, `Reconcile`, `Expire`, `Reassess`, `Resume` |
| `SameStep` | list of transition Ids | the Application applies them in the same transaction (T07→T11/T12, T28→T07→T11, T25→T02) |
| `RefusalCode` | `INVALID_TRANSITION`, `INVALID_ACTOR`, `STALE_VERSION`, `APPROVAL_EXPIRED` or empty | |
| `IdempotentReplay` | boolean | repeated Approval (spec 001 FR-014) |

### TransitionTable and Preconditions

- `TransitionTable`: the 29 rows as `XData` JSON (research R4) and the attachment matrix (event × states).
- `Preconditions`: one class method per `check` of the closed vocabulary, each `(snapshot, command, now, expected) → boolean`; parameters such as `maxDenials` resolve against the table's `parameters`.

## Stored records (`SignalNoir.Application.Store`, persistent) — see research R11

### Case

Fields of `CaseSnapshot` that are stored on the Case, plus:

| Field | Notes |
|---|---|
| `OpenOrderKey` | computed and stored: `OrderId` while non-terminal, `"closed:" _ CaseId` when terminal; **unique index** (research R7, AD-25) |
| `LastEventAt` | updated by every transition and attachment (AD-17 list cursor) |
| `Labels` | `synthetic` always true; `replay` (FR-38) |

Invariant checks enforced by the command path: at most one Execution in `in_progress` or `reconciling`; `DenialCount` ≤ 2; a voided authorization is never accepted again.

### TimelineEvent

`CaseId`, `Seq` (per-Case `$INCREMENT`), `At` (UTC), `Type` (`TimelineEventType`), `Actor`, `RefId`, `Payload` (JSON). Append-only: no update or delete method. `StateChanged` payload `{from, to, reason, caseVersionAfter}`; `CommandDiscarded` payload `{command, actor, currentState, requestedState, code}` (spec 001 C4).

### OutboxEntry

`CommandId`, `Kind` (work item), `CaseId`, `CaseVersionAfter`, `Status` (`pending`, `dispatched`, `done`), `CreatedAt`. Written in the same transaction as the transition (AD-20); dispatching and sweeper redispatch are outside this feature.

## State transitions

Exactly those of `contracts/case-state-machine.yaml` (T01–T29); this feature adds none. The persistent Case's `State` changes only through the command path.
