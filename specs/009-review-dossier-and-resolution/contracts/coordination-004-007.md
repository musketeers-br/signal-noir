# Coordination with 004 (Validator) and 007 (Approval)

No change to `contracts/openapi-signalnoir.yaml` or to the seam.

## 004 — Validator

- 009 calls the Validator only through `SignalNoir.Application.ResolutionValidator`, both for the
  Operator's resolution and for every proposer's Proposal (`CaseService.RouteProposal`).
- When 004's seam v2 lands, the adapter calls `Validate(ValidationInput)` (Proposal + Evidence +
  Order + reference snapshot + `now`) and returns 004's verdict and reason codes. The body alone is
  not enough: today `Verdict(validator, proposal, now)` receives no Evidence, Order or run, so its
  signature changes and a new `InputFor(rec, proposal, now)` builds the input; the two callers in
  `CaseService` (`CompleteInvestigation`, `ResolveReview`) pass it. Agreed with 004 as edits 1–2 of
  `specs/004-validation-and-reference-data/contracts/coordination-004-006-009.md` (004 T015).
- Approval policy: `ActionCatalog.RequiresApproval` was corrected by 009b
  (`specs/009b-request-review-approval`): an Action needs Approval only when it has an external
  effect, so `REQUEST_REVIEW` is false in the catalog and in every verdict. 004's edit 3 keeps only
  `requiredEvidence` in `Entries()`.
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
