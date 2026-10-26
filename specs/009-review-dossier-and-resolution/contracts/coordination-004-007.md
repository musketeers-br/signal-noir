# Coordination with 004 (Validator) and 007 (Approval)

No change to `contracts/openapi-signalnoir.yaml` or to the seam.

## 004 — Validator

- 009 calls the Validator only through `SignalNoir.Application.ResolutionValidator`, both for the
  Operator's resolution and for every proposer's Proposal (`CaseService.RouteProposal`).
- When 004's seam v2 lands, replace the body of `ResolutionValidator.Validate` with a call to
  `Validate(ValidationInput)` (Proposal + Evidence + Order + reference snapshot + `now`) and return
  004's verdict and reason codes. Callers and tests that use `FakeValidator` stay as they are.
- Routing of `DecisionProposed` is already done here (blocked or `REQUEST_REVIEW` →
  `ReviewRequired`, approval required → `PendingApproval`, else `Executing`); at G2 only the
  adapter's body changes.
- The verdict is stored on the Proposal (`ProposalRecord.verdictJson`) and as a `ValidatorVerdict`
  event; 004's v2 verdict must keep `verdict`, `reasons` and `requiresApproval`.

## 007 — Approval

- 009 creates `SignalNoir.Application.Model.ApprovalRecord` with the contract's `Approval` fields and
  writes only the Operator's own Approval inside `ResolveReview`.
- 007 should reuse this record (decision command, idempotent replay, expiry by the sweeper,
  `consumed`/`superseded` status) rather than create a second one. If 007 already has its own model,
  merge into one at G2 and keep the contract fields.
