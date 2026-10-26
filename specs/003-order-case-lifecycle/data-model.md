# Data Model: Order Intake and Case Lifecycle

All records live in `SignalNoir.Application.Model` and are written only by
`SignalNoir.Application.CaseService`. Timestamps are ISO-8601 UTC with `Z` (milliseconds).

## Order (`OrderRecord`, IdKey `orderId`)

| Field | Type | Rule |
|---|---|---|
| orderId | string(128) | business id from the snapshot; IdKey |
| partnerId | string(128) | from snapshot |
| correlationId | string(64) | `corr_…`, assigned on first acceptance, never changes |
| transactionIds | list of string | every Origin transaction id seen for this orderId, in arrival order, no duplicates |
| runId | string(64) | from the feed envelope, empty outside Benchmark |
| snapshotJson | string(32000) | exactly as received; never updated after first save |
| equivalenceKey | string(512) | `Core.Canon.FromSnapshot`; indexed (`equivKeyIdx`) |
| receivedAt | timestamp | first acceptance |
| synthetic | boolean | always 1 |
| caseId | string(64) | latest Case of this Order (empty until the first Exception) |

## Intake refusal (`IntakeRefusalRecord`, auto id)

orderId (may be empty), transactionId, reasons (ordered list from `Core.OrderShape`), refusedAt.
Never linked to a Case.

## Exception (`ExceptionRecord`, IdKey `exceptionId` = `exc_…`)

| Field | Rule |
|---|---|
| caseId, orderId | links |
| kind | `timeout`, `http_error`, `invalid_receipt`, `business_rejection`, `processing_error` |
| httpStatus | integer or empty |
| bodyJson | raw body as data (string or object JSON) |
| responseClass | optional, `success/business_error/transient/uncertain` when the caller classified it |
| observedAt | timestamp, required |
| attemptId | optional |
| duringExecution | 1 when recorded with the Case in `Approved`/`Executing` |

Index `caseIdx On caseId`.

## Case (`CaseRecord`, IdKey `caseId`)

| Field | Rule |
|---|---|
| caseId | `case_…` |
| orderId, partnerId | from the Order |
| openOrderId | = orderId while non-terminal, empty when terminal; `Index openOrderIdx [ Unique ]` |
| previousCaseId | Case of the previous episode, when any |
| state | closed vocabulary |
| caseVersion | starts at 1 on opening; +1 on each transition; never changed by attachments |
| Version | `VERSIONPROPERTY` row version (internal guard) |
| lastEventSeq | committed Timeline watermark |
| lastEventAt | time of the last event; `Index activityIdx On (lastEventAt, caseId)` |
| denialCount | 0..2 |
| reviewReason | set on entering `ReviewRequired` |
| currentProposalId, currentApprovalId, currentExecutionId | targets for CAS; empty in this feature except when set by later features |
| executionOutcome | latest Execution outcome or empty (filled by 008) |
| runId, proposerMode | Benchmark provenance (empty / `agent` by default) |
| synthetic (1), replay (0) | labels |
| createdAt, updatedAt | timestamps |

## Timeline event (`CaseEventRecord`, IdKey `(caseId, seq)`)

seq (1..lastEventSeq, contiguous), at, type (contract `TimelineEventType`), actor (contract
`Actor`), refId, payloadJson. Insert-only.

| Event | Payload |
|---|---|
| `CaseOpened` | `{orderId, correlationId, previousCaseId?}` |
| `ExceptionRecorded` | `{exceptionId, kind, httpStatus, observedAt, duringExecution}` (refId = exceptionId) |
| `StateChanged` | `{from, to, reason, caseVersionAfter}` |

## Follow-up work (`OutboxRecord`, IdKey `commandId` = `cmd_…`)

type (closed `Commands`), caseId, caseVersionAfter, status `pending → dispatched → done`,
payloadJson (e.g. `{rejectionReason}`), createdAt, dispatchedAt. Written in the same transaction
as the transition that creates it.

## State machine (core: `SignalNoir.Core.CaseMachine`)

The transition table is the one in spec FR-015, encoded as data in the core:
`(from, to) → (actors, followUp)`. Helpers:

- `Check(from, to, actor) → "" | INVALID_TRANSITION | INVALID_ACTOR`
- `FollowUp(from, to) → "" | Investigate | Execute`
- `RouteException(latestState) → open | attach | attach_and_investigate`
- `AfterRejection(denialCount) → Investigating | ReviewRequired`

Terminal: `Resolved`, `ResolvedByPriorReceipt`, `Cancelled`, `Failed` (no outgoing transition).
`Held` has exactly one outgoing transition (`→ Investigating`, `sweeper`).

## Commands (Application)

| Command | Kind | Effect |
|---|---|---|
| `AcceptOrder(order)` | intake | check shape → refuse (record) or store/correlate Order; ref = orderId |
| `RecordException(orderId, exception)` | mixed | open Case (Open) / attach / attach + `→ Investigating` per `RouteException` |
| `Transition(caseId, expectedVersion, toState, actor, event, expectedState?, expectedTarget?)` | transition | CAS + state + `StateChanged` + follow-up, atomic |
| `Append(caseId, event)` | attachment | closed event type; seq+1; caseVersion unchanged |
| `MarkReviewRequired(...)` | transition | `→ ReviewRequired` with reason |
| `ResolveRejection(caseId, expectedVersion, reason)` | transition | `Rejected → Investigating` (count 1, follow-up carries reason) or `→ ReviewRequired` (count 2) |
| `RecoverInterrupted()` | transition (system) | interrupted `Investigating` → `ReviewRequired` |

`PendingApproval → Rejected` increments `denialCount` in the same transaction.
`Approved → PendingApproval` (sweeper) clears `currentApprovalId`.
