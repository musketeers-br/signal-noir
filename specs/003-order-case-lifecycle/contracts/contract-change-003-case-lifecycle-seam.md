# Contract change 003 — Case lifecycle seam (seams v2 → v3)

**Status**: proposed by feature 003 (Henry), 2026-10-25. Applied to `docs/seams.md` in the same
change set as the implementation; reviewed at gate G1.

**Frozen HTTP contracts**: unchanged. `contracts/openapi-signalnoir.yaml` and
`contracts/openapi-sim.yaml` are not edited.

## Why

Feature 003 opens a Case on the first Exception, not on Order acceptance (spec FR-010), and needs a
compare-and-swap on expected state and target, not only version (FR-019). The v2 seam cannot
express either.

## Changes

### CaseCommands

| v2 | v3 |
|---|---|
| `AcceptOrder(order) -> Result<CaseRef>` | `AcceptOrder(order) -> Result<OrderRef>` — stores and correlates the Order; opens no Case. A malformed Order returns `VALIDATION_FAILED` with `details.reasons`. |
| — | **new** `RecordException(orderId, exception: CaseException) -> Result<CaseRef>` — opens the Case on the first Exception, joins the non-terminal Case otherwise, opens a related Case after a terminal one. |
| `OpenCase(orderId) -> Result<CaseRef>` | unchanged signature; returns the non-terminal Case of the Order, `NOT_FOUND` when there is none. It no longer creates a Case. |
| `Transition(caseId, expectedVersion, toState, actor, event)` | `Transition(caseId, expectedVersion, toState, actor, event, expectedState = "", expectedTarget = "")` — optional trailing parameters; an empty value is not checked. |
| — | **new** `ResolveRejection(caseId, expectedVersion, reason) -> Result<CaseRef>` |
| `Append(caseId, event)` | unchanged; `event.type` must be one of the contract's `TimelineEventType`, else `VALIDATION_FAILED`. |

### CaseQueries

`GetTimeline(caseId, sinceSeq)` gains an optional `limit` (default 200, max 500); `ListCases(cursor)`
gains optional `direction`, `limit` and a `filters` object (`state[]`, `status`, `pendingApproval`,
`runId`, `includeBenchmark`). Defaults keep v2 calls valid.

### DTOs

- **new** `CaseException`: `exceptionId`, `kind`, `httpStatus?`, `body?`, `responseClass?`,
  `observedAt`, `attemptId?`, `duringExecution`.
- `Order` adds `correlationId`, `transactionId` (input) / `transactionIds` (output), `partnerId`,
  `runId`.
- `Case` adds (all optional for consumers) `denialCount`, `previousCaseId`, `currentProposalId`,
  `currentApprovalId`, `currentExecutionId`, `executionOutcome`, `updatedAt`.
- `CaseSummary` adds `orderId`, `partnerId`, `createdAt`, `lastEventSeq`, `replay`,
  `exceptionCount`, `lastExceptionSummary`, `executionOutcome`.

### Result

Adds `details` (`%DynamicObject`). A `STALE_VERSION` result carries `expectedCaseVersion`,
`caseVersion`, `lastEventSeq`, `state`, `currentProposalId`, `serverTime`, matching the contract's
409 example.

### Conventions

- ID prefixes add `corr_` (correlation id) and `exc_` (exception id).
- Actors add `rules` and `replay` (already in the HTTP contract's `Actor`).
- Timeline event types are the closed `TimelineEventType` enum of the HTTP contract; transitions
  write `StateChanged` with `{from, to, reason, caseVersionAfter}`.

### Fakes

`FakeCaseCommands`/`FakeCaseQueries` implement the v3 signatures with the same semantics
(no Case on acceptance; Case on `RecordException`).

## Impact on other features

- 006 (Investigation), 007 (Approval), 008 (Execution), 009 (Dossier): call `Transition` with the
  new optional expectations when they hold a Proposal/Execution target. No signature they use is
  removed.
- 004 (Validator): not affected.
- Tests of 001 that relied on "Case on acceptance" are updated by 003 in the same change.
