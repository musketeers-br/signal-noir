# Data Model: Approval and the Transactional Outbox

## Approval (`ApprovalRecord`, from 009)

approvalId (`appr_…`), caseId, proposalId, decision (`approved`/`denied`), by
(`operator:<name>`/`benchmark`), at, expiresAt (`null` on denial), status, reason.

| Status | Set by | Meaning |
|---|---|---|
| `valid` | decision, 009 resolution, benchmark | may authorize, until `expiresAt` |
| `expired` | sweeper | past the deadline; never replayed |
| `superseded` | a newer Proposal | the Proposal it bound is no longer current |
| `consumed` | 008 (Execution) | authorized one Execution; still replayed |

A denial keeps `valid` as its status and is never replayed (only `approved` is).

## Outbox request (`OutboxRecord`, from 003)

commandId, type (`Investigate`, `Execute`, `Reconcile`, `Expire`, `Reassess`, `Resume`), caseId,
caseVersionAfter, status, payloadJson, createdAt, dispatchedAt.

`pending → dispatched → done`, or `pending → discarded` (Case version moved). A type without a
handler stays `pending`.

## Case transitions touched

| Transition | Actor | Follow-up | Needs |
|---|---|---|---|
| `PendingApproval → Approved` | `operator`, `benchmark` (in a run) | `Execute` | approved Approval for the current Proposal |
| `PendingApproval → Rejected` | `operator`, `benchmark` (in a run) | `Reassess` (`rejectionReason`) | denied Approval for the current Proposal |
| `Approved → PendingApproval` | `sweeper` | — | expired Approval |

## Timeline events written

`ApprovalRecorded {approvalId, proposalId, decision, by, expiresAt, automatic}`,
`ApprovalExpired {approvalId, proposalId}`, `StateChanged` (with `approvalId`),
`Annotation {kind: evidence}` for the denial reason, `CommandDiscarded {commandId, reason}`.
