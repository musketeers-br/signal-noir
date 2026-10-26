# Implementation Plan: Review Dossier and Operator Resolution

**Branch**: `009-review-dossier-and-resolution` | **Date**: 2026-10-25 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `specs/009-review-dossier-and-resolution/spec.md`

## Summary

A pure core builder (`Core.DossierBuilder`) turns the Case's own records — Evidence, the current
Proposal, the Order snapshot and the recorded review reason — into the contract's `Dossier`; it can
only cite Evidence ids it was given and turns every absence into a factual unknown.
`CaseService.ApplyTransition` writes a `DossierRecord` and a `DossierCreated` event in the same
transaction as every move to `ReviewRequired`. Operator resolution is one command,
`CaseService.ResolveReview`: a core shape check (`Core.ResolutionShape`, catalog Action + allowed
params, or cancel + reason; nothing else), then CAS on version and state, then the Operator's
Proposal (`Core.OperatorProposal`) through the single Validator via one adapter
(`Application.ResolutionValidator`). Blocked → only a `ValidatorVerdict` event, 422 with the
verdict. Accepted → Proposal, verdict, the Operator's own Approval (contract `Approval`, 15 min) and
the transitions `ReviewRequired → DecisionProposed → PendingApproval → Approved` (or `→ Executing`
for HOLD) with an `Execute` follow-up, all in one transaction. The API adds `POST /resolution`,
`GET /reference/action-catalog`, `GET /reference/mappings`, and the detail's `dossier` and
`approvals`.

The same adapter now also routes every proposer's Proposal: `CompleteInvestigation` records the
verdict (`ProposalRecord.verdictJson` and a `ValidatorVerdict` event) and `RouteProposal` moves
`DecisionProposed` to `ReviewRequired` (blocked, or `REQUEST_REVIEW`), `PendingApproval` or
`Executing`. Identity collisions live in a pure `Core.Identity`, shared by the Dossier builder
(reason `ambiguous_identity`) and the Rules proposer (asks for review); the base Evidence package
includes `tool.receipts_and_orders_by_patient`, so it uses the whole six-call budget.

## Technical Context

**Language/Version**: ObjectScript (verified on IRIS 2026.3 AI Hub build 154, `dev/aihub`; see 006 R0).

**Primary Dependencies**: existing `CaseService`, `Core.Validator` (seam v1), AI Hub (`%AI.*`) for the live agent, `%DynamicObject`.

**Storage**: new `DossierRecord` and `ApprovalRecord` in `SignalNoir.Application.Model`.

**Testing**: `%UnitTest` via iris-agentic-dev; `FakeValidator` for refusals; `tests/contract/validate_live.py`
extended to the resolution and reference operations.

**Target Platform / Project Type**: single IRIS project.

**Performance Goals**: Dossier built from the Case's rows inside the short transition transaction
(tens of Evidence rows; no I/O).

**Constraints**: no free payload; one Validator; nothing invented; calendar-gate exception granted.

**Scale/Scope**: one Dossier per entry into review; one resolution command.

## Constitution Check

- [x] **I. Pure Core** — Dossier building, reason mapping, resolution shape, operator Proposal and the
  action catalog are pure core classes; the Application only gathers rows and persists.
- [x] **II. Closed Catalog** — the resolution accepts only catalog Actions and their allowed
  parameters; `REQUEST_REVIEW` and any extra field are refused; no payload editing.
- [x] **III. One Validator** — the Operator's Proposal and every proposer's Proposal go through
  the single Validator (one adapter, `Application.ResolutionValidator`); no relaxed path.
- [x] **IV. Human Authority** — the Approval binds the exact Operator Proposal, with a deadline; the
  approver is the declared Operator.
- [x] **V. Case as Source of Truth** — Dossier with its transition; resolution writes Proposal,
  verdict, Approval, transitions and outbox in one transaction under the Case lock; refusals write
  only the verdict (attachment).
- [x] **VI. Effects at Most Once** — the resolution only creates `Execute` work; Execution is 008.
- [x] **VII. Honest Outcomes** — unknowns for absence; no invented Evidence (builder only cites given
  ids, tested); 422 names reason codes and records nothing else.
- [x] **VIII. Honest Measurement** — N/A.
- [x] **IX. Verifiable Increments** — four stories, tests first.
- [x] **Platform Constraints** — synthetic; no secrets.
- [x] **iris-agentic-dev** — only generic persistence/REST behavior already verified in 003/005.

## Project Structure

```text
specs/009-review-dossier-and-resolution/  plan.md research.md data-model.md quickstart.md tasks.md
                                          contracts/coordination-004-007.md  checklists/
src/SignalNoir/Core/  DossierReason.cls  DossierBuilder.cls  Identity.cls  ActionCatalog.cls  ResolutionShape.cls  OperatorProposal.cls
src/SignalNoir/Core/  ToolCatalog.cls  CaseMachine.cls  Suspicion.cls   # base package of 6, no expression methods, Neutralize
src/SignalNoir/Proposers/  Rules.cls  Agent.cls  AiHubRuntime.cls      # identity rule; neutralized input; temperature 0, usage
src/SignalNoir/Core/Dto/Case.cls               # + dossier, approvals
src/SignalNoir/Application/ResolutionValidator.cls
src/SignalNoir/Application/CaseService.cls     # dossier on ReviewRequired, RouteProposal, ResolveReview, reads
src/SignalNoir/Application/Model/  DossierRecord.cls  ApprovalRecord.cls  ProposalRecord.cls (+ verdictJson)
src/SignalNoir/Api/Dispatch.cls                # resolution, reference, detail dossier/approvals
tests/SignalNoir/Tests/Core/  TestDossierBuilder  TestResolutionShape  TestActionCatalog
tests/SignalNoir/Tests/Application/  TestDossier  TestResolution
tests/SignalNoir/Tests/Api/  TestResolutionApi
```

## Complexity Tracking

| Deviation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|--------------------------------------|
| `ApprovalRecord` created here, before 007 | The contract's `resolveReview` records the Operator's own Approval in the same command | Leaving the Case in `PendingApproval` contradicts the contract; a 007 port with a fake would leave the runtime without an implementation. Coordination recorded in `contracts/coordination-004-007.md` |
| Validator adapter over the seam-v1 Validator | 004's v2 is not merged; the resolution must use the single Validator now | Writing a v2 `ValidationInput` here would write 004's files |
| Proposal routing done here, not at G2 | Without it a blocked or `REQUEST_REVIEW` Proposal never reached review, so US1 #3/#4 could not happen end to end | Waiting for G2 would leave the Dossier unreachable from a real investigation |
