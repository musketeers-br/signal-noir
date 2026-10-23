# Phase 1 Data Model: Runtime Skeleton and Shared Seams

**Feature**: 001-runtime-skeleton-and-seams
**Date**: 2026-10-22

This slice persists one Order and one Case with its timeline. The model below is the smallest set
that lets a later slice grow without a schema reset. All records are synthetic and labelled.

## Aggregates

### Order

The synthetic external request. Read-only input to the system; owned by the incoming Business
Service.

| Field | Type | Notes |
|-------|------|-------|
| `orderId` | opaque, partner-issued | unique per Scenario instance; no new prefix |
| `payload` | snapshot (immutable) | raw snapshot as received; never mutated |
| `equivalenceKey` | string | canonized by the Core only (codes ordered, UTC, case normalized) |
| `receivedAt` | UTC timestamp | from the Clock port |
| `synthetic` | boolean | always true in this slice |
| `caseId` | ref | the Case opened for this Order, if any |

**Invariant**: at most one non-terminal Case per `orderId` (index/unique rule).

### Case

The persisted source of truth for a resolution.

| Field | Type | Notes |
|-------|------|-------|
| `caseId` | `case_` + counter | opaque |
| `orderId` | ref to Order | |
| `state` | closed vocabulary | see States |
| `caseVersion` | integer (`VERSIONPROPERTY`) | optimistic concurrency |
| `lastEventSeq` | integer | highest timeline seq |
| `lastEventAt` | UTC timestamp | drives the list cursor (later slices) |
| `synthetic` | boolean | true |
| `replay` | boolean | false in this slice |
| `reviewReason` | string, optional | set when state is `ReviewRequired` |
| `createdAt` / `updatedAt` | UTC timestamps | |

**Invariant**: every mutation goes through `SignalNoir.Application`; a transition commits the new
state, its timeline event and (if required) an outbox entry together. A writer whose expected
version no longer matches loses visibly.

### CaseEvent (timeline)

Append-only. One row per fact.

| Field | Type | Notes |
|-------|------|-------|
| `caseId` | ref | |
| `seq` | integer | per-Case `$INCREMENT`; never reused |
| `at` | UTC timestamp | |
| `type` | closed vocabulary | e.g. `CaseOpened`, `OrderAccepted`, `ReviewRequired` |
| `actor` | string | e.g. `system`, `operator:<name>`, `sweeper` |
| `refId` | string, optional | the id of the record the event refers to |
| `payload` | string/JSON snapshot | fact data only; no secrets |

**Invariant**: never updated or deleted; `seq` is monotonic per Case.

### OutboxEntry

Written in the same transaction as a transition that needs Production work.

| Field | Type | Notes |
|-------|------|-------|
| `commandId` | `cmd_` + counter | |
| `type` | enum | `Investigate`, `Execute`, `Reconcile`, `Expire`, `Reassess`, `Resume` |
| `caseId` | ref | |
| `caseVersionAfter` | integer | the post-commit version the consumer must match |
| `status` | enum | `pending`, `dispatched`, `done` |
| `createdAt` | UTC timestamp | |

In this slice the outbox is created and left pending (the consumer and sweeper arrive in later
slices); the table exists so no schema reset is needed.

## States

`Open`, `Investigating`, `DecisionProposed`, `PendingApproval`, `Approved`, `Rejected`,
`Executing`, `Held`, `ReviewRequired`, `Resolved`, `ResolvedByPriorReceipt`, `Cancelled`, `Failed`.

Only these transitions exist in this slice:

| From | To | Trigger | Actor |
|------|----|---------|-------|
| — | `Open` | Order accepted | `system` |
| `Open` | `ReviewRequired` | provider unavailable | `system` |
| `Open` | `Investigating` | investigation command (seam only) | `system` |

No terminal state reopens implicitly.

## Closed vocabularies (Core)

- **Actions**: `RETRY`, `APPLY_APPROVED_MAPPING`, `HOLD`, `REQUEST_REVIEW`.
- **Actors**: `system`, `operator:<name>`, `sweeper`, `benchmark`, `agent`.
- **Error codes**: the closed vocabulary already frozen in `contracts/openapi-signalnoir.yaml`;
  the seam must not add codes.
- **Preconditions**: `PARTNER_HEALTHY_WINDOW`, `ORDER_ACTIVE_AT_ORIGIN`, `APPROVAL_VALID`,
  `POLICY_VERSION_UNCHANGED`, `MAPPING_VERSION_UNCHANGED` (declared now, evaluated later).
- **Commands**: `Investigate`, `Execute`, `Reconcile`, `Expire`, `Reassess`, `Resume`.

## Ports (seam)

Everything below is behaviour the Core/Application expose; the adapters live at the edge.

| Port | Responsibility in this slice |
|------|------------------------------|
| `CaseCommands` | `AcceptOrder`, `OpenCase`, `MarkReviewRequired` — the only mutation path |
| `CaseQueries` | `GetCase`, `GetTimeline`, `ListCases` (read for the API) |
| `Validator` | `Validate(proposalDto)` → `ValidatorVerdict` (minimal rules) |
| `Proposer` | `Propose(caseDto)` → `Proposal` or a result value; `Unavailable` returns provider-unavailable |
| `Tools` | read-only capability seam; no implementation beyond the port |
| `PartnerClient` | effect seam; not called in this slice |
| `Clock` | `NowUtc()` |
| `IdGenerator` | `New(prefix)` |

Each port has a test double under `tests/SignalNoir/Tests/Fakes`; the doubles are not part of the
runtime resource.

## Relationships

```text
Order 1 ── 0..1 Case 1 ── * CaseEvent
                    └── * OutboxEntry
Case * ── 0..1 Proposal (seam DTO, persisted in a later slice)
```

## Validation rules derived from the spec

- An Order cannot be accepted twice into two non-terminal Cases (FR-005, D2/AD-25).
- Every Case and CaseSummary read through the API carries `synthetic=true` (FR-006).
- A restart preserves the Case and every timeline row byte-for-byte in meaning (FR-008).
- A provider-unavailable Case ends in `ReviewRequired` with a reason naming the provider (FR-004).
- No secret is stored on any record (FR-018).
