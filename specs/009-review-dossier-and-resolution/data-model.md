# Data Model: Review Dossier and Operator Resolution

## Dossier (`DossierRecord`, auto id, index on caseId)

caseId, createdAt, reason (contract enum), dossierJson (the contract `Dossier`, built by
`Core.DossierBuilder`). Insert-only; the latest per Case is shown.

## Approval (`ApprovalRecord`, IdKey `approvalId` = `appr_…`)

caseId, proposalId, decision (`approved`/`denied`), by (`operator:<name>` | `benchmark`), at,
expiresAt, status (`valid`/`expired`/`consumed`/`superseded`), reason. Shared with 007.

## Timeline events written

| Event | When |
|---|---|
| `DossierCreated` `{reason}` | with every transition to `ReviewRequired` |
| `ValidatorVerdict` `{proposalAuthor, action, verdict, reasons, requiresApproval}` | every resolution with an Action |
| `ProposalCreated` | accepted operator Proposal |
| `ApprovalRecorded` | the Operator's Approval |
| `OperatorResolution` `{kind, action | reason}` | every recorded resolution |
| `StateChanged` | each transition |

## Resolution outcomes

| Request | Outcome |
|---|---|
| shape refused | 400 `VALIDATION_FAILED`, nothing recorded |
| stale version / not `ReviewRequired` | 409, nothing recorded |
| Validator blocked | 422 with `details.verdict`, only `ValidatorVerdict` recorded |
| accepted, needs approval | 201, Proposal + Approval, Case `Approved`, `Execute` pending |
| accepted, HOLD | 201, Proposal, Case `Executing`, `Execute` pending |
| cancel + reason | 201, Case `Cancelled` |
