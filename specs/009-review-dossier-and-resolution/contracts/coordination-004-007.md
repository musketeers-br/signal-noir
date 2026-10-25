# Coordination with 004 (Validator) and 007 (Approval)

No change to `contracts/openapi-signalnoir.yaml` or to the seam.

## 004 — Validator

- 009 calls the Validator only through `SignalNoir.Application.ResolutionValidator`.
- When 004's seam v2 lands, replace the body of `ResolutionValidator.Validate` with a call to
  `Validate(ValidationInput)` (Proposal + Evidence + Order + reference snapshot + `now`) and return
  004's verdict and reason codes. Callers and tests that use `FakeValidator` stay as they are.
- The same adapter is the place 006's `DecisionProposed` routing should call at G2.

## 007 — Approval

- 009 creates `SignalNoir.Application.Model.ApprovalRecord` with the contract's `Approval` fields and
  writes only the Operator's own Approval inside `ResolveReview`.
- 007 should reuse this record (decision command, idempotent replay, expiry by the sweeper,
  `consumed`/`superseded` status) rather than create a second one. If 007 already has its own model,
  merge into one at G2 and keep the contract fields.
