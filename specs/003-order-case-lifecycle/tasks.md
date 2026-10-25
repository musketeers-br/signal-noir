---
description: "Tasks for feature 003 — Order Intake and Case Lifecycle"
---

# Tasks: Order Intake and Case Lifecycle

**Input**: Design documents from `specs/003-order-case-lifecycle/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md,
contracts/contract-change-003-case-lifecycle-seam.md, quickstart.md

**Tests**: MANDATORY (Constitution — TDD; Principle IX). Each story writes its failing
`%UnitTest` first. Classes are compiled and tests run on the live instance through
iris-agentic-dev (`--container congenial-waffle-iris-1 -n IRISAPP`).

**Calendar gate**: waived for this feature by Henry on 2026-10-25 (recorded in research.md).

## Format: `[ID] [P?] [Story] Description`

- **[P]**: can run in parallel (different files, no dependency on an incomplete task)
- **[Story]**: user story from spec.md (US1–US6)

---

## Phase 1: Setup

- [X] T001 Record a baseline: compile `src/` and `tests/` and run the full `SignalNoir.Tests` suite through iris-agentic-dev; note the pass/fail count in `specs/003-order-case-lifecycle/research.md` (Verification log)
- [X] T002 [P] Create the live-conformance script `tests/contract/validate_live.py` (reuses the registry/validator approach of `contracts/tools/validate_fixtures.py`; arguments `--base`; fetches `/cases`, `/cases?direction=newer&cursor=…`, `/cases/{id}`, `/cases/{id}/timeline`, one unknown id and one bad cursor; validates against `CaseListPage`, `CaseDetail`, `TimelinePage`, `ErrorEnvelope`)

---

## Phase 2: Foundational (blocking all stories)

**Purpose**: closed vocabularies, result details, clock and the v3 seam shape every story compiles against.

- [X] T003 [P] Write failing tests for the new vocabularies in `tests/SignalNoir/Tests/Core/TestVocab.cls`: actors `rules`/`replay` accepted; `EXCEPTIONKINDS` = timeout,http_error,invalid_receipt,business_rejection,processing_error; `EVENTTYPES` = the contract `TimelineEventType` enum; prefixes `corr_`, `exc_` accepted
- [X] T004 Extend `src/SignalNoir/Core/Vocab.cls`: add `rules,replay` to `ACTORS`; add `EXCEPTIONKINDS`, `EVENTTYPES` parameters with `IsExceptionKind`, `IsEventType`; add `corr_,exc_` to `IDPREFIXES` (makes T003 pass)
- [X] T005 [P] Add `Property details As %DynamicObject` to `src/SignalNoir/Core/Result.cls` and a `ClassMethod ErrorWith(code, message, details)`; keep `Error` unchanged
- [X] T006 [P] Change `src/SignalNoir/Application/SystemClock.cls` to UTC with milliseconds from `$ZTIMESTAMP` (`YYYY-MM-DDTHH:MM:SS.mmmZ`); add a test in `tests/SignalNoir/Tests/Core/TestVocab.cls` or a new `tests/SignalNoir/Tests/Application/TestClock.cls` asserting the contract `UtcDateTime` pattern
- [X] T007 [P] Create DTO `src/SignalNoir/Core/Dto/CaseException.cls` (exceptionId, kind, httpStatus, body As %DynamicAbstractObject or string, responseClass, observedAt, attemptId, duringExecution)
- [X] T008 [P] Extend DTOs per contract change 003: `src/SignalNoir/Core/Dto/Order.cls` (+correlationId, transactionId, transactionIds As %ListOfDataTypes, partnerId, runId), `src/SignalNoir/Core/Dto/Case.cls` (+denialCount, previousCaseId, currentProposalId, currentApprovalId, currentExecutionId, executionOutcome, updatedAt, runId, proposerMode), `src/SignalNoir/Core/Dto/CaseSummary.cls` (+orderId, partnerId, createdAt, lastEventSeq, replay, exceptionCount, lastExceptionSummary, executionOutcome, pendingApproval, currentProposalId)
- [X] T009 Update the port `src/SignalNoir/Core/Port/CaseCommands.cls`: `Transition(…, expectedState As %String = "", expectedTarget As %String = "")`; new `RecordException(orderId, exception As SignalNoir.Core.Dto.CaseException)`, `ResolveRejection(caseId, expectedVersion, reason)`; and `src/SignalNoir/Core/Port/CaseQueries.cls`: `GetTimeline(caseId, sinceSeq = 0, limit = 200)`, `ListCases(cursor = "", direction = "older", limit = 50, filters As %DynamicObject = "")`
- [X] T010 Update fakes to the v3 seam: `tests/SignalNoir/Tests/Fakes/FakeCaseCommands.cls` (AcceptOrder returns orderId and opens no Case; RecordException opens/joins; Transition checks expectedState/expectedTarget; event types `CaseOpened`/`StateChanged`) and `tests/SignalNoir/Tests/Fakes/FakeCaseQueries.cls` (new optional parameters); update `tests/SignalNoir/Consumer/Consumer.cls` and `tests/SignalNoir/Tests/Seam/TestConsumerUsesSeam.cls` to drive AcceptOrder + RecordException
- [X] T011 Extend persistent models: `src/SignalNoir/Application/Model/OrderRecord.cls` (+partnerId, correlationId, transactionIds As list, runId, snapshotJson MAXLEN 32000, `Index equivKeyIdx On equivalenceKey`), `src/SignalNoir/Application/Model/CaseRecord.cls` (+caseVersion, openOrderId with `Index openOrderIdx On openOrderId [ Unique ]`, previousCaseId, denialCount, currentProposalId, currentApprovalId, currentExecutionId, executionOutcome, runId, proposerMode, `Index activityIdx On (lastEventAt, caseId)`, `Index stateIdx On state`), `src/SignalNoir/Application/Model/OutboxRecord.cls` (+payloadJson, dispatchedAt, `Index statusIdx On (caseId, type, status)`); new `src/SignalNoir/Application/Model/ExceptionRecord.cls` and `src/SignalNoir/Application/Model/IntakeRefusalRecord.cls` per data-model.md; compile and confirm storage regenerates
- [X] T012 Rewrite the private write helpers in `src/SignalNoir/Application/CaseService.cls`: `LockCase(caseId)` (`LOCK +^SignalNoir.CaseLock(caseId):5` inside the transaction), `AppendEvent(rec, type, actor, refId, payload, at)` assigning `seq = rec.lastEventSeq + 1`, saving the event row and setting `rec.lastEventSeq/lastEventAt` (no `$INCREMENT`, no `^SignalNoir.CaseSeq`/`CaseLast`), `EmitFollowUp(rec, type, payload)`; projections read `lastEventSeq/lastEventAt` from the row

**Checkpoint**: everything compiles; the 001 suites still compile (some will fail until US2 rewires the Case opening).

---

## Phase 3: User Story 1 — A synthetic Order is checked and correlated on arrival (P1) 🎯 MVP

**Goal**: malformed Orders refused with a recorded reason and no Attempt/Case; valid Orders stored immutable, correlated, with a canonical key.

**Independent Test**: `Core.TestOrderShape`, `Core.TestCanon`, `Application.TestIntake`.

### Tests (write first, must fail)

- [X] T013 [P] [US1] `tests/SignalNoir/Tests/Core/TestOrderShape.cls`: valid Origin Order → no reasons; each missing required field → reason `missing:<path>` in a stable order; `exams` empty → `missing:exams[0].code`; unreadable `specimen.collectedAt` → `unreadable:specimen.collectedAt`; `synthetic` absent/false → `not_synthetic`; non-object input → `malformed`
- [X] T014 [P] [US1] `tests/SignalNoir/Tests/Core/TestCanon.cls`: `FromSnapshot` equal for exam codes in other order/case, duplicated codes, and `collectedAt` `2026-10-23T07:00:00-03:00` vs `2026-10-23T10:00:00Z`; `NormalizeUtc` handles `+HH:MM`, `-HHMM`, `Z`, fraction, date rollover across midnight; unreadable → ""
- [X] T015 [P] [US1] `tests/SignalNoir/Tests/Application/TestIntake.cls`: invalid Order → `VALIDATION_FAILED`, `details.reasons`, one `IntakeRefusalRecord`, no `OrderRecord`, no `CaseRecord`; valid Order → `OrderRecord` with snapshot byte-identical, `corr_` correlationId, transactionIds = [tx1], key = `Canon.FromSnapshot`, no Case; same orderId with tx2 → one record, transactionIds [tx1, tx2], snapshot unchanged, same correlationId; `notes` with an instruction-like text stored verbatim and nothing else changes

### Implementation

- [X] T016 [P] [US1] Create `src/SignalNoir/Core/OrderShape.cls` with `ClassMethod Check(snapshot) As %ListOfDataTypes` per research R5
- [X] T017 [P] [US1] Extend `src/SignalNoir/Core/Canon.cls`: `FromSnapshot(snapshot)`, offset-aware `NormalizeUtc` (pure `$ZDATEH`/`$ZDATE` arithmetic), `Parts(key) As %DynamicObject` (`patientId`, `examCodes[]`, `collectedAt`, `specimenId`) for `OrderView.equivalenceKey`
- [X] T018 [US1] Rewrite `AcceptOrder` in `src/SignalNoir/Application/CaseService.cls`: `OrderShape.Check` → on reasons save `IntakeRefusalRecord` and return `ErrorWith("VALIDATION_FAILED", …, {reasons})`; else under `LOCK +^SignalNoir.OrderLock(orderId)` create or correlate the `OrderRecord` (first time: snapshot, key, correlationId `corr_`, partnerId, runId, receivedAt; again: append new transactionId only); return `OkRef(orderId)`; never open a Case
- [X] T019 [US1] Update `src/SignalNoir/Interop/Service/OrderIn.cls`: `Accept(json, transactionId = "", runId = "")` builds the DTO from the raw Origin Order (no client-supplied equivalence key) and calls `AcceptOrder`; malformed JSON → `VALIDATION_FAILED` and an `IntakeRefusalRecord`
- [X] T020 [US1] Compile and run `Core.TestOrderShape`, `Core.TestCanon`, `Application.TestIntake` green through iris-agentic-dev

**Checkpoint**: US1 independently green.

---

## Phase 4: User Story 2 — The first Exception opens a Case; later Exceptions join it (P1)

**Goal**: Case opens on first Exception; one non-terminal Case per orderId; joins; related Case after terminal.

**Independent Test**: `Application.TestExceptionRouting`.

### Tests (write first)

- [X] T021 [P] [US2] `tests/SignalNoir/Tests/Core/TestCaseMachine.cls` (add): `RouteException` → `open` for "" and each terminal state; `attach` for Investigating/Approved/Executing; `attach_and_investigate` for Open, DecisionProposed, PendingApproval, Rejected, Held, ReviewRequired
- [X] T022 [P] [US2] `tests/SignalNoir/Tests/Application/TestExceptionRouting.cls`: accepted Order with no Exception → no Case; first Exception (`timeout`) → Case `Open`, caseVersion 1, Timeline `CaseOpened` then `ExceptionRecorded` with kind/status/body/observedAt, `ExceptionRecord` linked; Exception for an unknown orderId → `NOT_FOUND`, no Case; invalid kind → `VALIDATION_FAILED`; second Exception on a non-terminal Case → same Case, 2 Exceptions, no new Case; Exception on a Case in `Approved` (set via Transition chain) → attached with `duringExecution=1`, state unchanged, caseVersion unchanged; Exception after `Cancelled` → new Case, `CaseOpened.payload.previousCaseId` = old Case, old Case unchanged; two different Orders → two Cases
- [X] T023 [P] [US2] `tests/SignalNoir/Tests/Application/TestConcurrency.cls` method `TestConcurrentFirstExceptions`: two `JOB` workers report the first Exception of the same orderId at once (start barrier via a global) → exactly one non-terminal Case holding both Exceptions

### Implementation

- [X] T024 [US2] Add `RouteException(latestState)` to `src/SignalNoir/Core/CaseMachine.cls`
- [X] T025 [US2] Implement `RecordException(orderId, exception)` in `src/SignalNoir/Application/CaseService.cls`: validate kind/observedAt; in one transaction under `OrderLock(orderId)` read the latest Case of the Order; route: `open` → new `CaseRecord` (caseVersion 1, openOrderId, previousCaseId, labels, runId/proposerMode from the Order) + `CaseOpened` + `ExceptionRecorded`; `attach` → `ExceptionRecord` + `ExceptionRecorded` (duringExecution for Approved/Executing); `attach_and_investigate` → attach then the `→ Investigating` transition with follow-up `Investigate` (same transaction); `OrderRecord.caseId` updated; return `OkRef(caseId)`. Rewrite `OpenCase(orderId)` to return the non-terminal Case or `NOT_FOUND`; remove `OpenCaseRecord` and the `^SignalNoir.OpenCaseByOrder` global
- [X] T026 [US2] Rewire `ProcessOrder` and add `ProcessException(orderId, exception)` in `src/SignalNoir/Application/CaseService.cls`: after a new Case opens, route it `Open → ReviewRequired` (provider unavailable, as in 001) or `Open → Investigating` (follow-up `Investigate`); add `OrderIn.ReportException(orderId, kind, httpStatus, body, observedAt, attemptId)` in `src/SignalNoir/Interop/Service/OrderIn.cls`
- [X] T027 [US2] Update 001 tests that assumed "Case on acceptance" to accept + report an Exception: `tests/SignalNoir/Tests/Application/TestPersistence.cls`, `tests/SignalNoir/Tests/Application/TestCaseRestart.cls`, `tests/SignalNoir/Tests/Smoke/TestWalkingSkeleton.cls`, `tests/SignalNoir/Tests/Api/TestCasesRead.cls` (event types `CaseOpened`/`ExceptionRecorded`/`StateChanged` instead of `OrderAccepted`/`CaseTransition`); keep their intent
- [X] T028 [US2] Compile and run US1 + US2 suites and the updated 001 suites green

**Checkpoint**: tracer path step "Order becomes a Case" works with the real semantics.

---

## Phase 5: User Story 3 — One state machine, with visible losers (P1)

**Goal**: full transition table with actors and follow-up; atomic CAS with expected version/state/target.

**Independent Test**: `Core.TestCaseMachine`, `Application.TestTransitions`, `Application.TestConcurrency`.

### Tests (write first)

- [X] T029 [P] [US3] `tests/SignalNoir/Tests/Core/TestCaseMachine.cls` (rewrite table tests): every row of spec FR-015 allowed for each listed actor and refused (`INVALID_ACTOR`) for `agent` when not listed; a sample of non-listed pairs (`Open→Executing`, `Held→PendingApproval`, `Held→Resolved`) → `INVALID_TRANSITION`; every terminal state has no outgoing transition; `operator:` without name refused; `FollowUp` returns `Investigate` for →Investigating rows and `Execute` for `PendingApproval→Approved` and `DecisionProposed→Executing`
- [X] T030 [P] [US3] `tests/SignalNoir/Tests/Application/TestTransitions.cls`: `Open→Investigating` bumps caseVersion by 1, writes `StateChanged {from,to,reason,caseVersionAfter}` and one `pending` `Investigate` outbox row with `caseVersionAfter`; forbidden transition and unauthorized actor → error, caseVersion/lastEventSeq/outbox unchanged; stale version → `STALE_VERSION` with `details` (expectedCaseVersion, caseVersion, lastEventSeq, state, serverTime); expectedState mismatch → `STALE_VERSION`; expectedTarget mismatch against `currentProposalId` → `STALE_VERSION`; terminal → any refused; `Append` with an unknown event type → `VALIDATION_FAILED`; `Append` of `Annotation` → lastEventSeq+1, caseVersion unchanged; forced failure after the event row is written (test hook that raises inside the transaction) → no state, event or outbox visible
- [X] T031 [P] [US3] `tests/SignalNoir/Tests/Application/TestConcurrency.cls` method `TestTwoWritersOneWins`: 100 trials, two `JOB` workers call `Transition` with the same expected version (barrier global) → exactly one ok and one `STALE_VERSION` per trial; Timeline has exactly one `StateChanged` per trial

### Implementation

- [X] T032 [US3] Encode the FR-015 table in `src/SignalNoir/Core/CaseMachine.cls` as data (`(from,to) → actors, followUp`), rewrite `CanTransition`, `AllowedActors`, `Check`; add `FollowUp(from,to)`; keep method names used by 001 callers
- [X] T033 [US3] Rewrite `Transition` in `src/SignalNoir/Application/CaseService.cls`: `TSTART`, `LockCase`, reload row, check expectedVersion/expectedState/expectedTarget → `STALE_VERSION` with details (rollback, no write); `CaseMachine.Check` → `INVALID_TRANSITION`/`INVALID_ACTOR`; set state, `caseVersion+1`, reviewReason on ReviewRequired, `openOrderId=""` on terminal, `denialCount+1` on `→Rejected`, `currentApprovalId=""` on `Approved→PendingApproval`; `StateChanged` event; follow-up from `CaseMachine.FollowUp`; map `#5800` on save to `STALE_VERSION`; `TCOMMIT`. Add a test-only failure hook (`^SignalNoir.Test("failAfterEvent")`, read only when set) for T030
- [X] T034 [US3] Restrict `Append` in `src/SignalNoir/Application/CaseService.cls` to `Vocab.IsEventType` and actors to `Vocab.IsActor`; refuse on terminal Cases only for types other than `Annotation`
- [X] T035 [US3] Compile and run US3 suites green (plus US1/US2 regression)

**Checkpoint**: "two writers can never both win" demonstrated.

---

## Phase 6: User Story 4 — Cases survive a restart (P2)

**Independent Test**: `Application.TestRestart003` + quickstart step "Restart".

- [X] T036 [P] [US4] `tests/SignalNoir/Tests/Application/TestRestart003.cls`: Cases in Open, PendingApproval (through the table) and Held; snapshot state/caseVersion/Timeline/outbox; drop all orefs and reopen with a new `CaseService` → identical; Case in Investigating with its `Investigate` outbox `dispatched` → `RecoverInterrupted()` moves it to `ReviewRequired` reason `investigation interrupted`; one with outbox `pending` stays `Investigating` and the entry stays `pending`; running `RecoverInterrupted()` twice changes nothing more
- [X] T037 [US4] Implement `RecoverInterrupted()` in `src/SignalNoir/Application/CaseService.cls` (SQL over `CaseRecord` state = Investigating joined to outbox status) and add `MarkDispatched(commandId)`/`MarkDone(commandId)` helpers for the future consumer
- [X] T038 [US4] Call `RecoverInterrupted()` from `OnStart` in `src/SignalNoir/Interop/Bootstrap.cls` (result recorded, never throws); extend `tests/SignalNoir/Tests/Interop/TestBootstrap.cls` to assert it runs
- [X] T039 [US4] Compile and run green; perform the container restart walk-through of quickstart.md §3 and record the result in research.md Verification log

---

## Phase 7: User Story 5 — Read views for the console and the Benchmark (P2)

**Independent Test**: `Core.TestCursor`, `Application.TestProjections`, `Api.TestTimelineRead`, `tests/contract/validate_live.py`.

### Tests (write first)

- [X] T040 [P] [US5] `tests/SignalNoir/Tests/Core/TestCursor.cls`: encode/decode round-trip; garbage, wrong part count or a non-UTC time → invalid
- [X] T041 [P] [US5] `tests/SignalNoir/Tests/Application/TestProjections.cls`: 5 Cases, limit 2 `older` paging covers each exactly once newest first; `newer` from a head cursor after touching 2 Cases returns those 2 ascending with a new headCursor; filters `state`, `status=open|terminal`, `pendingApproval`; bad cursor → `VALIDATION_FAILED`; detail carries order view (correlationId, transactionIds, snapshot, key parts), exceptions, denialCount, labels synthetic=1, nulls for absent layers; timeline `sinceSeq`/`limit`/`hasMore`/`nextSinceSeq`; late confirmation: a `JOB` holds an open transaction after appending (hang) while the reader polls → reader sees only seq ≤ committed watermark, then sees it after commit, no gap
- [X] T042 [P] [US5] `tests/SignalNoir/Tests/Api/TestTimelineRead.cls` and extend `tests/SignalNoir/Tests/Api/TestCasesRead.cls`: payload builders produce every required field of `CaseListPage`/`CaseSummary`, `CaseDetail`, `TimelinePage`; unknown caseId → 404 envelope `NOT_FOUND`; bad `sinceSeq`/cursor/limit → 400 `VALIDATION_FAILED`; error mapping 409 for `STALE_VERSION`/`INVALID_TRANSITION`

### Implementation

- [X] T043 [P] [US5] Create `src/SignalNoir/Core/Cursor.cls` (`Encode(lastEventAt, caseId)`, `Decode(cursor, .lastEventAt, .caseId) As %Boolean`, base64url, no padding)
- [X] T044 [US5] Rewrite `ListCases`, `GetCase`, `GetTimeline` in `src/SignalNoir/Application/CaseService.cls` per research R9 (watermark = row `lastEventSeq`; summaries with exceptionCount/lastExceptionSummary; detail DTO with order view and exceptions; `headCursor` = max matching `(lastEventAt, caseId)`)
- [X] T045 [US5] Rewrite `src/SignalNoir/Api/Dispatch.cls`: routes `/cases`, `/cases/:caseid`, `/cases/:caseid/timeline`; query parsing (`cursor`, `direction`, `limit`, repeated `state`, `status`, `pendingApproval`, `runId`, `includeBenchmark`, `sinceSeq`); payloads matching `CaseListPage`, `CaseDetail`, `TimelinePage`; `serverTime` everywhere; error status map (VALIDATION_FAILED 400, NOT_FOUND 404, INVALID_ACTOR 403, STALE_VERSION/INVALID_TRANSITION 409) with `details`
- [X] T046 [US5] Compile and run US5 suites green; run `tests/contract/validate_live.py` against the live instance and record the result in research.md

---

## Phase 8: User Story 6 — Rejection and expiry have a destination and a limit (P3)

**Independent Test**: `Application.TestRejectionExpiry`.

- [X] T047 [P] [US6] `tests/SignalNoir/Tests/Core/TestCaseMachine.cls` (add): `AfterRejection(1)` = Investigating, `AfterRejection(2)` = ReviewRequired
- [X] T048 [P] [US6] `tests/SignalNoir/Tests/Application/TestRejectionExpiry.cls`: drive Open→Investigating→DecisionProposed(agent)→PendingApproval→Rejected(operator:ana) → denialCount 1 → `ResolveRejection` → Investigating with `Investigate` outbox payload `{rejectionReason}`; second round → denialCount 2 → `ReviewRequired` reason `second rejection`, no new outbox; Approved → PendingApproval by `sweeper` ok, Timeline `StateChanged` reason `approval expired`, `currentApprovalId` cleared; the same by `system` or `operator:x` → `INVALID_ACTOR`
- [X] T049 [US6] Add `AfterRejection(denialCount)` to `src/SignalNoir/Core/CaseMachine.cls` and `ResolveRejection(caseId, expectedVersion, reason)` to `src/SignalNoir/Application/CaseService.cls` (uses `Transition` with follow-up payload)
- [X] T050 [US6] Compile and run US6 suite green

---

## Phase 9: Polish & cross-cutting

- [X] T051 Publish `docs/seams.md` v3 from `specs/003-order-case-lifecycle/contracts/contract-change-003-case-lifecycle-seam.md` (update ports, DTOs, prefixes, event-type rule, fakes table; version line `v3 (2026-10-26) — contract change 003`); keep `specs/001-runtime-skeleton-and-seams/contracts/seams.md` in step (it must not diverge)
- [X] T052 [P] Remove dead 001 globals usage (`^SignalNoir.Cases`, `^SignalNoir.CaseSeq`, `^SignalNoir.CaseLast`, `^SignalNoir.OpenCaseByOrder`) from `src/` and tests; grep confirms none left
- [X] T053 [P] Secret/payload audit: grep `src/SignalNoir` for anything writing keys into Timeline/outbox payloads; confirm Timeline payloads are facts only
- [X] T054 Full run: compile all, run every `SignalNoir.Tests` suite, run `validate_live.py`, walk quickstart.md; record the counts in research.md Verification log
- [X] T055 Update `docs/specify-prompts/PARALELISMO.md` board row 003 to "implementada (aguardando gate G1)"

---

## Dependencies & Execution Order

- Setup (T001–T002) → Foundational (T003–T012) → stories.
- **US1** (T013–T020) depends only on Foundational.
- **US2** (T021–T028) depends on US1 (needs accepted Orders).
- **US3** (T029–T035) depends on Foundational; its implementation shares `CaseService.cls` with US2, so run after US2 (same file).
- **US4** (T036–T039) depends on US3 (transitions, outbox statuses).
- **US5** (T040–T046) depends on US2 (Cases with Exceptions) and US3 (StateChanged); T043 can start any time.
- **US6** (T047–T050) depends on US3.
- Polish after all stories.

Within a story: tests first (must fail), then core, then application, then adapters, then the green run.

## Parallel Opportunities

- Foundational: T003, T005, T006, T007, T008 in parallel (different files); T009→T010 sequential.
- US1: T013, T014, T015 in parallel; T016 and T017 in parallel.
- US2: T021, T022, T023 in parallel.
- US3: T029, T030, T031 in parallel.
- US5: T040, T041, T042, T043 in parallel.
- `CaseService.cls` tasks (T012, T018, T025, T026, T033, T034, T037, T044, T049) are strictly sequential.

## Implementation Strategy

1. MVP = Foundational + US1 + US2 + US3: an Order becomes a Case on the first failure, under a
   correct, concurrency-safe state machine (G1 needs exactly this from 003).
2. Add US4 (restart) and US5 (read views) — the console (005) and the Benchmark need them.
3. Add US6 (rejection/expiry bounds) — consumed by 007.
4. Publish seams v3 and run the full validation.
