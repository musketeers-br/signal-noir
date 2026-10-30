---
description: "Tasks for feature 008 — Safe Execution and Recovery"
---

# Tasks: Safe Execution and Recovery

**Input**: `specs/008-execution-and-recovery/` (spec, plan, research, data-model,
contracts/coordination.md, quickstart)

**Tests**: MANDATORY (TDD). Each test is written, and run failing, before its implementation task,
on the live instance through iris-agentic-dev.

**Calendar gate**: waived for this feature by Henry on 2026-10-28 (research.md).

## Phase 1: Setup

- [X] T001 Baseline: run the full ObjectScript suite on the branch start and record the counts in research.md

## Phase 2: Foundational (pure core, ports, records)

- [X] T002 [P] `tests/SignalNoir/Tests/Core/TestResponseClass.cls` then `src/SignalNoir/Core/ResponseClass.cls`, covering every row of research R2:
  - no answer → uncertain/timeout;
  - 200 with a matching Receipt → success;
  - 200 with the wrong orderId, the wrong key, no receiptId or free text → uncertain/invalid_receipt;
  - 503, 429 → transient;
  - 504 → uncertain;
  - 500 with an empty body → uncertain; 500 with a body → business_error/http_error;
  - 400, 404, 409, 422 → business_error/business_rejection;
  - a Receipt on a non-200 is never success.
- [X] T003 [P] `tests/SignalNoir/Tests/Core/TestEffectKey.cls` then `src/SignalNoir/Core/EffectKey.cls`:
  - `Canonical` sorts keys at every level and keeps array order;
  - the same payload with keys in a different order gives the same key;
  - a different payload, Order or Partner gives a different key;
  - the key has the `bek_` prefix and 8–128 characters (Partner contract);
  - `Derive` takes no Proposal.
- [X] T004 [P] `tests/SignalNoir/Tests/Core/TestExecutionPolicy.cls` then `src/SignalNoir/Core/Port/ExecutionPolicy.cls` and `src/SignalNoir/Core/ExecutionPolicy.cls`:
  - **`Revalidate` passes**: UP, active, approval valid, versions unchanged → passed with 5 checks.
  - **`Revalidate` holds**: DEGRADED, DOWN, active maintenance or unreadable health → Held, `PARTNER_HEALTHY_WINDOW` failed. A policy or mapping version that differs from the current one → Held.
  - **`Revalidate` cancels**: `cancelled` at the Origin → Cancelled, `ORDER_ACTIVE_AT_ORIGIN` failed. Unreadable status → Held.
  - **`Revalidate` changes nothing**: an approval expired or not valid → destination "", `APPROVAL_VALID` failed. No approval is required for HOLD.
  - **Precedence**: cancel over hold.
  - `MaxAttempts` = 3, `MinHoldSeconds` = 300.
  - `LeaseSeconds` = `SN_AI_LEASE_SECONDS` (300), above the Partner timeout.
  - `EffectPayload`: RETRY → snapshot; `APPLY_APPROVED_MAPPING` → error "mapping unavailable".
- [X] T005 `src/SignalNoir/Core/Port/PartnerClient.cls`: add `Deliver`, `SearchReceipts`, `Health`, `OriginStatus`, keeping `Send` and `FetchReceipts` for the seam.
- [X] T006 `src/SignalNoir/Interop/SimulatorHttp.cls`: extract `OriginFeed.Http` into the shared `Call(base, method, path, body, timeout)`; `OriginFeed.Http` delegates to it. Run `TestOriginFeed` green.
- [X] T007 `src/SignalNoir/Interop/PartnerHttp.cls`: implement the four methods over the Simulator, reading the `Idempotent-Replayed` header. Test `tests/SignalNoir/Tests/Interop/TestPartnerHttp.cls` live:
  - health of a `clean` instance;
  - status of an emitted Order;
  - receipts for an unknown key → empty items;
  - a delivery → 200 with a Receipt;
  - a repeat → replayed.
- [X] T008 [P] `src/SignalNoir/Application/Model/ExecutionRecord.cls` and `ReceiptCopyRecord.cls`, per data-model.md.
- [X] T009 [P] `tests/SignalNoir/Tests/Fakes/ScriptedPartner.cls`: a PartnerClient fake with health, status, a queue of delivery answers, receipts held in memory, a call log and a "lose" answer (the Receipt is recorded but the answer is not returned).

## Phase 3: User Story 1 — An approved Action reaches the Partner once (P1) 🎯 MVP

- [X] T010 [US1] `tests/SignalNoir/Tests/Support.cls`: `ApprovedCase(svc, tag, action)` (a Case in `Approved` with a current fixture Proposal and an Order snapshot) and `ExecuteNow(svc, partner, caseId)` (delivers its `Execute` through an `ExecutionService` with the given partner).
- [X] T011 [US1] `tests/SignalNoir/Tests/Application/TestExecution.cls`:
  - **Approved RETRY with a healthy fake**:
    - one Execution, `approvalId` = the approval, generation 1, lease set;
    - the approval is `consumed`;
    - `Executing`, then `Resolved`;
    - a Receipt copy with source `delivery`;
    - `executionOutcome` = resolved;
    - Timeline order: RevalidationPerformed, ExecutionAuthorized, StateChanged, ReconciliationPerformed (prior_check, not found), AttemptRecorded, ReceiptRecorded, StateChanged;
    - the fake received 1 delivery with the effect key and the snapshot.
  - **Prior Receipt by Order exists**: 0 deliveries, `Resolved`, Receipt source `reconciliation`.
  - **HOLD Case in `Executing`**: an Execution with no approval and no attempts, `Held`, 0 calls.
  - **Storage failure at authorization** (`BrokenCmdIds`-style injected save error): 0 deliveries, still `Approved`.
  - **`Execute` delivered twice**: 1 Execution, 1 delivery.
- [X] T012 [US1] `CaseService.AuthorizeExecution(commandId, plan)`: under the Case lock, outbox pending and the version check; the reconciling block (R7); the execution record, the approval consumed, events, transition and request done (research R1). Also `StartAttempt`, `FinishAttempt` (success path) and `RecordReconciliation` (prior check).
- [X] T013 [US1] `src/SignalNoir/Application/ExecutionService.cls`: `Execute(commandId)` with observe → revalidate → authorize → prior check → attempt loop. `Default()` uses `PartnerHttp` and `Core.ExecutionPolicy`.
- [X] T014 [US1] `CommandBus.Route`: `Execute` and `Reconcile` go to `ExecutionService`; the `Executions` switch ("none" leaves them pending); `Sweeper.Run` passes its switch to both. Update `TestCommandBus` (Execute is no longer "waiting" by default; with "none" it is).

## Phase 4: User Story 2 — Nothing is sent on stale context (P1)

- [X] T015 [US2] `tests/SignalNoir/Tests/Application/TestRevalidation.cls` (fake partner):
  - DEGRADED → `Held`, 0 deliveries, `revalidation.checks` has `PARTNER_HEALTHY_WINDOW` failed with the observed status;
  - active maintenance → `Held`;
  - Origin cancelled → `Cancelled`, `openOrderId` cleared;
  - approval past its deadline (FixedClock) → state `Approved` unchanged, approval still `valid`, `RevalidationPerformed` recorded, request done, 0 deliveries;
  - policy version changed (policy stub) → `Held` with the reason;
  - health unreadable → `Held`;
  - `APPLY_APPROVED_MAPPING` with the default policy → `Held`, "mapping unavailable";
  - a concurrent version bump between revalidation and the CAS → the CAS loses, 0 deliveries.
- [X] T016 [US2] Wire the blocking destinations in `AuthorizeExecution` and `ExecutionService`.

## Phase 5: User Story 3 — An uncertain outcome is reconciled (P1)

- [X] T017 [US3] `tests/SignalNoir/Tests/Application/TestReconciliation.cls` (fake partner):
  - **lost answer**: attempt 1 uncertain, the Execution `reconciling` and a `Reconcile` pending in the same commit (asserted before delivering it); the summary's `executionOutcome` is reconciling; delivering the Reconcile finds the Receipt by key → `Resolved` with source `reconciliation`; 1 delivery in total;
  - **timeout, no Receipt**: the Reconcile resends with the same key and payload as attempt 2 → success;
  - **same key, same payload**: the fake returns the original Receipt as replayed and holds 1 Receipt;
  - **422 (key reused with a different payload)**: `Failed`;
  - **another Execution of the Order reconciling**: a new `Execute` authorizes nothing, its request stays pending (waiting), 0 deliveries;
  - **reconciliation unreadable**: stays `reconciling`, no new request.
- [X] T018 [US3] `FinishAttempt` (uncertain path), `TakeOverExecution`, `RecordReconciliation` (found / not found / unreadable) and `ExecutionService.Reconcile(commandId)`.

## Phase 6: User Story 4 — Restarts, late workers and repeats (P1)

- [X] T019 [US4] `tests/SignalNoir/Tests/Application/TestLease.cls`:
  - **lease passed in `Executing`** (FixedClock): the sweeper writes one `Reconcile` (`lease_expired`) and an Annotation, never `ReviewRequired`; delivering it takes over with generation 2 and resolves;
  - **a write under generation 1 after the take-over**: refused, `CommandDiscarded` with the generation;
  - **a refused write that held a Receipt**: a `Reconcile` (`lost_cas`) is queued;
  - **two jobs delivering the same `Execute`**: 1 Execution, ≤ 1 delivery;
  - **a repeated approval click**: 1 approval, 1 Execution;
  - **`Investigating` past its lease**: the sweeper moves it to `ReviewRequired`.
- [X] T020 [US4] Generation checks and the lost-CAS Reconcile in every execution write; `CaseService.RequestReconcile`; `Sweeper` lease pass (`Executing` and `Investigating`).

## Phase 7: User Story 5 — Held is reassessed (P2)

- [X] T021 [US5] `tests/SignalNoir/Tests/Application/TestHeld.cls`:
  - `Held` before the minimum hold → untouched;
  - after it, with the Partner still degraded → untouched, no event;
  - after it, with the Partner UP → `Investigating` by `sweeper`, `ReassessmentPerformed`, an `Investigate` pending;
  - held for a version change → back to `Investigating` without a health read;
  - after leaving `Held`, the old approval is `consumed` and a new Proposal routed to `PendingApproval` needs a new approval (replay of the old one is refused, because it belongs to another Proposal).
- [X] T022 [US5] `CaseService.ReassessHeld` and the `Sweeper` Held pass (with a partner parameter for tests).

## Phase 8: User Story 6 — Refusals and exhausted attempts fail honestly (P2)

- [X] T023 [US6] `tests/SignalNoir/Tests/Application/TestExecutionFailure.cls` (fake partner):
  - **500 with a body**: the attempt records the class and a body excerpt (≤ 500 characters), `Failed`; a new related Case opens with an Exception `http_error` 500 whose `previousCaseId` is the failed Case;
  - **409**: an Exception `business_rejection`;
  - **transient, then success**: 2 attempts, same key;
  - **3 transients**: `Failed`, no new Case;
  - **a Receipt with the wrong key on a 200**: never success.
- [X] T024 [US6] `FinishAttempt` (business, transient and budget paths) and `ExecutionService`'s failure report.

## Phase 9: User Story 7 — The execution is visible (P3)

- [X] T025 [US7] `tests/SignalNoir/Tests/Api/TestCaseDetailLayers.cls` (add): the Case detail of a resolved Case has `executions[0]` with the contract fields (`executionId`, `approvalId`, `proposalId`, `action`, `idempotencyKey`, `authorizedAt`, `leaseGeneration`, `revalidation`, `attempts`, `reconciliations`, `outcome`) and `receipt` (`receiptId`, `orderId`, `idempotencyKey`, `receivedAt`, `partnerId`, `source`); the list summary carries `executionOutcome` (the contract has it only on `CaseSummary`).
- [X] T026 [US7] `CaseService.ListExecutions`, `ReceiptOf`, and the projections in `Api/Dispatch.cls`.

## Phase 10: Recovery suite (live, SC-001..SC-004)

- [X] T027 `tests/SignalNoir/Tests/Recovery/TestRecoverySuite.cls`, against the Simulator over HTTP with client timeout 3 s and timeScale 0.01. Each test ends with a count of the Partner's Receipts for the Order.
  - **clean**: Resolved, 1 Receipt.
  - **lost response** (`idempotency.lost_receipt`): Resolved via reconciliation, 1 Receipt.
  - **repeated click** (`idempotency.repeated_approval`): 1 Receipt.
  - **restart during executing** (`idempotency.restart_during_executing`): kill the worker job mid-call, then lease pass and Reconcile; 1 Receipt.
  - **repeated command**: the same `Execute` delivered 3 times; 1 Receipt.
  - **late worker**: a generation-1 write after the take-over is discarded; 1 Receipt.
  - **blocking precondition** (`P3` events `PARTNER_DEGRADES`, `MAINTENANCE_STARTS` and `ORDER_CANCELLED_AT_ORIGIN` after approval): Held, Held, Cancelled; 0 Receipts.
  - **Totals**: 0 duplicates.

## Phase 11: Polish

- [X] T028 Full ObjectScript suite green, plus the live contract check (`validate_live.py`) with Cases that have executions.
- [X] T029 Update the coordination docs: `PARALELISMO.md` row 008, and the 007 coordination note ("Execute waits for 008" no longer holds).
- [X] T030 Record the verification results in research.md R10.

## Dependencies

- Phase 2 blocks everything.
- US1 (T010–T014) blocks US2–US7.
- US3 and US4 share `FinishAttempt` and the generation checks; do US3 first.
- US5 and US6 are independent of each other.
- US7 needs US1.
- The recovery suite needs US1–US4.

## Parallel opportunities

- T002, T003, T004, T008 and T009 touch different files.
- T021 and T023 have separate test classes, but both edit `CaseService`, so they are sequential in
  practice.
