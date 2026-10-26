# Data Model: Review Dossier and Operator Resolution

## Dossier (`DossierRecord`, auto id, index on caseId)

caseId, createdAt, reason (contract enum: `provider_unavailable`, `invalid_agent_response`,
`budget_exceeded`, `investigation_interrupted`, `second_denial`, `validator_blocked`,
`ambiguous_identity`, `review_requested`), dossierJson (the contract `Dossier`, built by
`Core.DossierBuilder`). Insert-only: one row per entry into `ReviewRequired`, earlier rows are kept;
the latest per Case is shown. `ambiguous_identity` replaces `review_requested` when
`Core.Identity` finds colliding patient records (`collidingRecords` with `divergentFields`).

## Proposal (`ProposalRecord`, from 006)

+ `verdictJson`: the Validator verdict for this Proposal (`verdict`, `reasons`,
`requiresApproval`), written before routing.

## Approval (`ApprovalRecord`, IdKey `approvalId` = `appr_…`)

caseId, proposalId, decision (`approved`/`denied`), by (`operator:<name>` | `benchmark`), at,
expiresAt, status (`valid`/`expired`/`consumed`/`superseded`), reason. Shared with 007.

## Timeline events written

| Event | When |
|---|---|
| `DossierCreated` `{reason}` | with every transition to `ReviewRequired` |
| `ValidatorVerdict` `{proposalAuthor, action, verdict, reasons, requiresApproval}` | every resolution with an Action, and every proposer's Proposal before routing |
| `ProposalCreated` | accepted operator Proposal |
| `ApprovalRecorded` | the Operator's Approval |
| `OperatorResolution` `{kind, action | reason}` | every recorded resolution |
| `StateChanged` | each transition |

## Proposal routing (`DecisionProposed`)

| Verdict | Next state |
|---|---|
| blocked | `ReviewRequired`, reason `validator blocked: <codes>` |
| `REQUEST_REVIEW` | `ReviewRequired`, reason `review requested: <params.reason>` |
| requires approval | `PendingApproval` |
| otherwise | `Executing` |

## Resolution outcomes

| Request | Outcome |
|---|---|
| shape refused | 400 `VALIDATION_FAILED`, nothing recorded |
| stale version / not `ReviewRequired` | 409, nothing recorded |
| Validator blocked | 422 with `details.verdict`, only `ValidatorVerdict` recorded |
| accepted, needs approval | 201, Proposal + Approval, Case `Approved`, `Execute` pending |
| accepted, HOLD | 201, Proposal, Case `Executing`, `Execute` pending |
| cancel + reason | 201, Case `Cancelled` |
