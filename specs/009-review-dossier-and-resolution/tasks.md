---
description: "Tasks for feature 009 — Review Dossier and Operator Resolution"
---

# Tasks: Review Dossier and Operator Resolution

**Input**: `specs/009-review-dossier-and-resolution/` (plan, spec, research, data-model,
contracts/coordination-004-007.md, quickstart)

**Tests**: MANDATORY (TDD), written and run failing before each implementation task, on the live
instance through iris-agentic-dev.

**Calendar gate**: waived for this feature by Henry on 2026-10-25 (research.md).

## Phase 1: Setup

- [X] T001 Baseline: full ObjectScript suite on the branch start; record the count in research.md

## Phase 2: Foundational

- [X] T002 [P] `tests/SignalNoir/Tests/Core/TestActionCatalog.cls` then `src/SignalNoir/Core/ActionCatalog.cls`: the 4 Actions, `externalEffect`, `requiresApproval` (HOLD false), allowed params per Action, contract `ActionCatalogEntry` objects
- [X] T003 [P] Models `src/SignalNoir/Application/Model/DossierRecord.cls`, `src/SignalNoir/Application/Model/ApprovalRecord.cls`; `Core/Dto/Case.cls` + `dossier` (%DynamicObject), `approvals` (%DynamicArray)

## Phase 3: User Story 1 — Every review comes with an honest Dossier (P1) 🎯 MVP

- [X] T004 [P] [US1] `tests/SignalNoir/Tests/Core/TestDossierBuilder.cls`: reason mapping table (R1); provider unavailable without proposal → no partial diagnosis, unknown "no interpretation", relevant ids = given Evidence; proposal present → partialDiagnosis + hypotheses + conflicts (only ids that exist); absence Evidence → unknown; no Evidence → unknown "no evidence was collected"; identity collision from receipts Evidence → collidingRecords with divergentFields; prior-receipt candidate mismatches; every emitted id ∈ given ids; nothing to flag → empty unknowns
- [X] T005 [US1] `src/SignalNoir/Core/DossierReason.cls`, `src/SignalNoir/Core/DossierBuilder.cls`
- [X] T006 [P] [US1] `tests/SignalNoir/Tests/Application/TestDossier.cls`: each path to `ReviewRequired` (provider unavailable at open, invalid response, budget, interrupted, second rejection) leaves a `DossierRecord` + `DossierCreated` in the same transaction; detail `dossier` = latest; a second entry into review creates a fresh Dossier; every Dossier evidence id exists on the Case
- [X] T007 [US1] Hook in `ApplyTransition` (`src/SignalNoir/Application/CaseService.cls`): build + save the Dossier on `→ ReviewRequired`; `GetCase` returns `dossier` and `approvals`

## Phase 4: User Story 2 — Resolve with a catalog Action through the same Validator (P1)

- [X] T008 [P] [US2] `tests/SignalNoir/Tests/Core/TestResolutionShape.cls`: allowed fields only (`payload`, `snapshot`, extra keys refused), operator name rules, integer version, catalog Action, `REQUEST_REVIEW` refused, params per Action, cancel needs reason
- [X] T009 [US2] `src/SignalNoir/Core/ResolutionShape.cls`, `src/SignalNoir/Core/OperatorProposal.cls`
- [X] T010 [P] [US2] `tests/SignalNoir/Tests/Application/TestResolution.cls`: accepted mapping → Proposal `operator:Carla` current, verdict on Timeline, Approval by `operator:Carla` with 15 min deadline, Case `Approved` (caseVersion +3), `Execute` pending; HOLD → `Executing`, no Approval; FakeValidator blocked → 422 data (`blocked`, reasons), Case unchanged (state, version), no Proposal/Approval/Execute, only `ValidatorVerdict` appended; stale version / not in review → `STALE_VERSION` / `INVALID_TRANSITION`, nothing written; shape refused → `VALIDATION_FAILED`
- [X] T011 [US2] `src/SignalNoir/Application/ResolutionValidator.cls` (adapter, R4) and `ResolveReview` in `CaseService.cls`

## Phase 5: User Story 3 — Cancel with a reason (P2)

- [X] T012 [P] [US3] Add to `TestResolution.cls`: cancel without reason refused; with reason → `Cancelled`, `OperatorResolution` with reason and operator, no `Execute`
- [X] T013 [US3] Cancel branch of `ResolveReview`

## Phase 6: User Story 4 — The console reads it all over the contract (P2)

- [X] T014 [P] [US4] `tests/SignalNoir/Tests/Api/TestResolutionApi.cls`: status map (201/400/404/409/422) and bodies for `ReviewResolutionResult` and the 422 envelope with `details.verdict`; action catalog payload; mappings payload; detail with `dossier` and `approvals`
- [X] T015 [US4] `src/SignalNoir/Api/Dispatch.cls`: `POST /cases/:caseid/resolution`, `GET /reference/action-catalog`, `GET /reference/mappings`, detail `dossier`/`approvals`
- [X] T016 [US4] Extend `tests/contract/validate_live.py` (review detail with dossier, resolution 400/409/422/201 on scratch cases, reference operations) and run it live

## Phase 7: Polish

- [X] T017 Full run (ObjectScript suite, ui tests, validate_live, fixtures); record in research.md
- [X] T018 Browser check: resolve a review from the console against the real API
- [X] T019 Update `docs/specify-prompts/PARALELISMO.md` row 009

## Phase 8: Closing the runtime gaps (2026-10-26)

Found after T019: every task was checked, but at runtime no Case reached `ReviewRequired` with an
identity or prior-receipt Dossier, because nothing routed a Proposal by the Validator and no
patient records were collected.

- [X] T020 [P] Failing tests first: `Core.TestToolCatalog` (base package of 6 with receipts),
  `Core.TestDossierBuilder` (identity overrides a generic review; `Core.Identity` is the one rule),
  `Application.TestDossier` (identity end to end, unconfirmed prior receipt end to end, Validator
  blocked → `validator_blocked`), `Application.TestInvestigation` (routing to `ReviewRequired` and
  `PendingApproval`, verdict recorded); adjusted 006 tests for 6 base calls
- [X] T021 `src/SignalNoir/Core/Identity.cls` (collision rule moved out of `DossierBuilder`);
  `ambiguous_identity` text and next step in `Core.DossierReason`
- [X] T022 `Core.ToolCatalog` base package + `tool.receipts_and_orders_by_patient`; `Proposers.Rules`
  identity rule, no extra Tool call
- [X] T023 `CaseService.CompleteInvestigation` + `RouteProposal`: verdict through
  `ResolutionValidator`, `ValidatorVerdict` event, routing by verdict (FR-014)
- [X] T024 Specs 006/009 updated; full suite, live contract and analysis recorded in research.md
- [X] T025 Analysis follow-ups: `TestDossier.TestEachReviewEntryRecordsAFreshDossier` (C1); plan.md
  (I1), `contracts/coordination-004-007.md` (I2) and data-model.md (I3) brought in line with the
  routing, `Core.Identity`, `verdictJson` and build 154
- [X] T026 Review fixes (PR): `Core.ResolutionShape` requires JSON strings for params, note,
  operator and cancel reason; the Operator's note is saved as `operator.note` Evidence (only when
  the resolution is accepted) and the Proposal cites it even with an empty Dossier
  (`TestResolutionShape.TestTextFieldsMustBeStrings`, `TestResolution.TestNoteIsRecordedAsEvidence…`,
  `TestResolution.TestBlockedResolutionRecordsNoNote`)

## Dependencies

Foundational → US1 → US2 → US3 → US4 → Polish. `CaseService.cls` tasks are sequential.
