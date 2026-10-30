---
description: "Tasks for correction 009b — Approval policy for a request for review"
---

# Tasks: Correction 009b — Approval Policy for a Request for Review

**Input**: `specs/009b-request-review-approval/` (spec, plan, research, data-model, contracts,
quickstart)

**Tests**: MANDATORY (TDD), written and run failing before each implementation task; ObjectScript
on the live instance through iris-agentic-dev, the console with Vitest.

**Calendar gate**: waived for this feature by Henry on 2026-10-26 (research.md).

## Phase 1: Setup

- [X] T001 Baseline on the branch start: full ObjectScript suite and `npm test` in `ui/`; record the counts in research.md

## Phase 2: Foundational

None: one rule in an existing class.

## Phase 3: User Story 1 — The catalog tells the truth about Approval (P1) 🎯 MVP

- [X] T002 [P] [US1] `tests/SignalNoir/Tests/Core/TestActionCatalog.cls`: `RequiresApproval("REQUEST_REVIEW")` is 0; for every entry of `Entries()`, `requiresApproval` = `externalEffect`
- [X] T003 [P] [US1] `tests/SignalNoir/Tests/Api/TestResolutionApi.cls` `TestCatalog`: the `REQUEST_REVIEW` entry reports `requiresApproval` false and `RETRY` true
- [X] T004 [US1] `src/SignalNoir/Core/ActionCatalog.cls`: `RequiresApproval(action)` returns `ExternalEffect(action)`; doc comment cites R19 / FR-16

## Phase 4: User Story 2 — The verdict on a request for review matches the catalog (P1)

- [X] T005 [US2] `tests/SignalNoir/Tests/Application/TestInvestigation.cls` `TestP5ProducesEvidenceLinkedProposal`: the recorded verdict (`ProposalRecord.verdictJson` and the `ValidatorVerdict` event) says `requiresApproval` false; the Case is `ReviewRequired` with a Dossier, no Approval and no `PendingApproval` in the Timeline; a P8b mapping Proposal still records `requiresApproval` true and waits in `PendingApproval` (already pinned, re-run)

## Phase 5: User Story 3 — The console's offline mode shows the same policy (P2)

- [X] T006 [P] [US3] `ui/tests/action-catalog-mock.test.ts`: the `FixtureServer` action catalog has four entries and `requiresApproval` = `externalEffect` for each
- [X] T007 [US3] `ui/src/lib/api/fixtures.ts`: derive `requiresApproval` from the external effect

## Phase 6: User Story 4 — The coordination note describes the real change (P3)

- [X] T008 [P] [US4] `specs/009-review-dossier-and-resolution/contracts/coordination-004-007.md`: the adapter gains the inputs v2 needs (`InputFor`, see 004's coordination document); the `REQUEST_REVIEW` Approval policy is corrected by 009b, so 004's edit 3 keeps only `requiredEvidence`

## Phase 7: Polish

- [X] T009 Full ObjectScript suite, live contract check (`tests/contract/validate_live.py`), contract fixtures and `npm test` / `npm run check` in `ui/`; record results in research.md; spec status → Implemented

## Dependencies

T001 → (T002, T003) → T004 → T005; T006 → T007; T008 independent; T009 last.

## Parallel opportunities

T002, T003, T006 and T008 touch different files.

## Implementation strategy

US1 is the MVP (the rule itself). US2 is a test-only confirmation, because the verdict reads the
same rule. US3 and US4 are independent cleanups.
