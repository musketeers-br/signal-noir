---
description: "Tasks for feature 007 — Approval and the Transactional Outbox"
---

# Tasks: Approval and the Transactional Outbox

**Input**: `specs/007-approval-and-outbox/` (spec, plan, research, data-model,
contracts/coordination.md, quickstart)

**Tests**: MANDATORY (TDD), written and run failing before each implementation task, on the live
instance through iris-agentic-dev.

**Calendar gate**: waived for this feature by Henry on 2026-10-28 (research.md).

## Phase 1: Setup

- [X] T001 Baseline: full ObjectScript suite, live contract check and `npm test` in `ui/` on the branch start; record the counts in research.md

## Phase 2: Foundational

- [X] T002 [P] `tests/SignalNoir/Tests/Core/TestDecisionShape.cls` then `src/SignalNoir/Core/DecisionShape.cls`: `decision` ∈ approved/denied; `operator` string, non-empty, no colon, ≤ 64; `expectedCaseVersion` whole number; `reason` string when present and required (non-blank) on denial; unknown fields refused; JSON types enforced
- [X] T003 [P] `tests/SignalNoir/Tests/Core/TestApprovalPolicy.cls` then `src/SignalNoir/Core/Port/ApprovalPolicy.cls`, `src/SignalNoir/Core/ApprovalPolicy.cls`: 900 s deadline; `ExpiresAt(at)`; `IsExpired(expiresAt, now)`; `Admit("benchmark", runId)` true iff runId non-empty; other actors admitted
- [X] T004 `CaseService` gains the `Approvals` property (policy port, set in `Default()`); `Core.CaseMachine` row `PendingApproval>Rejected` gets follow-up `Reassess`; update `TestCaseMachine` table row

## Phase 3: User Story 1 — Approve the exact Proposal (P1) 🎯 MVP

- [X] T005 [US1] `tests/SignalNoir/Tests/Support.cls`: `PendingCase(svc, tag)` (a Case in `PendingApproval` with a current fixture Proposal) and `Decide(svc, caseId, decision, operator, reason)`; `DriveTo` goes through `DecideProposal` for `Approved`/`Rejected`
- [X] T006 [US1] `tests/SignalNoir/Tests/Application/TestDecision.cls`: approve exact version → `Approved`, one Approval (by, at, expiresAt = at + 900 s, status valid), `ApprovalRecorded` + `StateChanged` with `approvalId`, one `Execute` pending, `currentApprovalId`; reload after a new process (restart) keeps it; stale version → `STALE_VERSION` with `currentProposalId`, nothing recorded; non-current Proposal → `STALE_VERSION`; Case not in `PendingApproval` → `INVALID_TRANSITION`; replay (same Proposal, stale version, other Operator) → replay with the same approval and no new rows; invalid shape → `VALIDATION_FAILED`; concurrent approvals (2 jobs) → 1 Approval, 1 `Execute`
- [X] T007 [US1] `CaseService.DecideProposal` (approve path), replay lookup, `ApprovalJson` reuse
- [X] T008 [US1] Guard in `ApplyTransition`: `PendingApproval → Approved|Rejected` needs `payload.approvalId` of a matching decision for the current Proposal; 009's `ResolveReview` passes its `approvalId`; test: raw `Transition` to `Approved` without a decision → `INVALID_TRANSITION`, nothing recorded
- [X] T009 [US1] Update the tests that walked to `Approved`/`Rejected` by raw transition (`TestRejectionExpiry`, `TestTransitions`, `TestExceptionRouting`, `TestDossier`, others found by the suite) to use the decision helpers

## Phase 4: User Story 2 — Deny with a reason (P1)

- [X] T010 [US2] `TestDecision`: denial without reason → `VALIDATION_FAILED`; denial → `Rejected`, denied Approval (expiresAt null, reason), `operator.denial_reason` Evidence by the Operator with the reason, `Reassess` pending with `rejectionReason`
- [X] T011 [US2] `DecideProposal` deny path

## Phase 5: User Story 4 — Follow-up work happens once (P1)

- [X] T012 [US4] `tests/SignalNoir/Tests/Application/TestCommandBus.cls`: `Reassess` after a first denial → `Investigating` + `Investigate` with the reason, request `done`; second denial → `ReviewRequired` with Dossier; deliver twice / two jobs → processed once; Case version moved → `discarded` + `CommandDiscarded`; `Execute` → stays `pending`, result waiting; unknown id → `NOT_FOUND`; injected storage failure (`BrokenCmdIds`) during approval → no Approval, no state change, no request
- [X] T013 [US4] `src/SignalNoir/Application/CommandBus.cls` (`Deliver`, handlers); outbox status `discarded`

## Phase 6: User Story 3 — Approval has a deadline (P1)

- [X] T014 [US3] `tests/SignalNoir/Tests/Application/TestApprovalExpiry.cls`: sweeper after the deadline (FixedClock) → Approval `expired`, `ApprovalExpired` by `sweeper`, Case `PendingApproval`, the old `Execute` discarded on delivery; approve again → new Approval (no replay of the expired one); within deadline → untouched; new Evidence/Exception in `Approved` → Approval still valid; Case already `Executing` → not touched; sweeper redelivers a `Reassess` older than the grace period; a new Proposal supersedes the old Approval
- [X] T015 [US3] `src/SignalNoir/Tasks/Sweeper.cls` (`Run(now)`: redelivery, expiry), `CaseService.ExpireApproval`, supersede in `CompleteInvestigation`/`ResolveReview`
- [X] T016 [US3] `src/SignalNoir/Tasks/SweeperTask.cls` (`%SYS.Task.Definition`, `Ensure()` every minute, `Remove()`); test: `Ensure()` twice → one task; the `Bootstrap` call is left to the gate (research R6)

## Phase 7: User Story 5 — Benchmark approval and actor rules (P2)

- [X] T017 [US5] `tests/SignalNoir/Tests/Application/TestBenchmarkApproval.cls`: Case with `runId` and a Proposal needing approval → `Approved` by `benchmark`, Approval `automatic`, `Execute` queued; no `runId` → `PendingApproval`; `HOLD` in a run → no Approval; actor `benchmark` on a Case without `runId` → `INVALID_ACTOR`
- [X] T018 [US5] `RouteProposal` automatic approval; `ApplyTransition` admission check

## Phase 8: API

- [X] T019 [P] `tests/SignalNoir/Tests/Api/TestDecisionApi.cls`: payload of 201 (approval + CommandAck with commandId), 200 replay, 400, 404, 409 with `currentProposalId`; operator name `benchmark` acts as `operator:benchmark`
- [X] T020 `src/SignalNoir/Api/Dispatch.cls`: route `POST /cases/:caseid/proposals/:proposalid/decision`, statuses, delivery job after commit
- [X] T021 `tests/contract/validate_live.py`: decision 400 (denial without reason), 404 (unknown Case), 409 (stale) on a live `PendingApproval` Case when one exists

## Phase 9: Polish

- [X] T022 Full ObjectScript suite, live contract check, contract fixtures, `npm test` / `npm run check` in `ui/`; record results in research.md; `PARALELISMO.md` line for 007 left for the user; spec status → Implemented

- [X] T023 G2 rehearsal fixes: chained delivery in `CommandBus.Deliver` (`TestCommandBus.TestReassessAfterDenials`), `investigations` in `Tasks.Sweeper.Run`, `Supersede` only on approvals; report in `docs/verification/g2-rehearsal-2026-10-28.md`

## Dependencies

Setup → Foundational → US1 (T005–T009) → US2 → US4 → US3 → US5 → API → Polish. `CaseService.cls`
tasks are sequential.

## Parallel opportunities

T002 and T003; T019 can be written while US5 is implemented.

## Implementation strategy

US1 is the MVP (the console's approve button works end to end). US2 and US4 close the denial loop.
US3 and US5 add the deadline and the benchmark path.
