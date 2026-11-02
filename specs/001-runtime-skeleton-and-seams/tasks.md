---

description: "Task list for feature 001 — runtime skeleton and shared seams"
---

# Tasks: Runtime Skeleton and Shared Seams

**Input**: Design documents from `/specs/001-runtime-skeleton-and-seams/`

**Prerequisites**: plan.md (required), spec.md (required for user stories), research.md, data-model.md, contracts/

**Tests**: MANDATORY (Constitution, Engineering Standards — TDD; Principle IX). Every user story
carries the failing test that proves it, written before the implementation. `%UnitTest` classes
MUST be compiled and run on the live build 154 container through iris-agentic-dev.

**Calendar gate**: no submission code may be written before 2026-10-26. Until then only the
contract change, the seam contract and throwaway spikes are allowed; implementation tasks below
MUST NOT start before that date.

> **Gate override (2026-10-23)**: the project owner explicitly authorized starting implementation
> ahead of the gate date ("Override the gate now" in response to the gate warning). This note is
> the audit trail; T003/T004 were completed before the override under the original gate.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (US1–US4)
- Every task names an exact file path

## Path Conventions

Single IRIS/IPM project. Sources under `src/`, tests under `tests/`, startup routine under
`boot/`. Namespace `IRISAPP`; module name `signalnoir`.

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Project initialization and basic structure

- [X] T001 Create the package tree from plan.md: `src/SignalNoir/Core/{Dto,Port}/`, `src/SignalNoir/Application/Model/`, `src/SignalNoir/Api/`, `src/SignalNoir/Interop/Service/`, `src/SignalNoir/Proposers/`, `boot/`, `tests/SignalNoir/Tests/{Core,Application,Api,Interop,Smoke,Fakes}/`, `docs/`
- [X] T002 Replace `module.xml` with the `signalnoir` IPM module: `<Name>signalnoir</Name>`, `<SourcesRoot>src</SourcesRoot>`, `<Resource Name="SignalNoir.PKG"/>`, `<UnitTest Name="/tests" Package="SignalNoir.Tests" Phase="test"/>`; delete the `src/dc/` and `tests/dc/` placeholder sources
- [X] T003 Apply contract change 001 by adding `GET /health` to `contracts/openapi-signalnoir.yaml` exactly as specified in `specs/001-runtime-skeleton-and-seams/contracts/contract-change-001-health.md` (schema requires `status`, `liveness`, `provider`, `serverTime`)
- [X] T004 [P] Publish `docs/seams.md` from `specs/001-runtime-skeleton-and-seams/contracts/seams.md` (no divergence; the spec copy is the source of truth)
- [X] T005 [P] Add `boot/%ZSTART.mac` with the `SYSTEM` entry point calling `##class(SignalNoir.Interop.Bootstrap).OnStart()`; update `iris.script` to load it into the `%SYS` namespace and compile it during build (compose/Dockerfile rewrite stays in feature 012)

**Checkpoint**: Structure, module, contract change and startup routine are in place.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Shared domain, DTOs, ports, persistence and adapters that every story needs

**⚠️ CRITICAL**: No user story work can begin until this phase is complete.

### Tests for Foundational

- [X] T006 [P] Unit test for closed vocabularies in `tests/SignalNoir/Tests/Core/TestVocab.cls` (states exactly: `Open`, `Investigating`, `DecisionProposed`, `PendingApproval`, `Approved`, `Rejected`, `Executing`, `Held`, `ReviewRequired`, `Resolved`, `ResolvedByPriorReceipt`, `Cancelled`, `Failed`; actions exactly: `RETRY`, `APPLY_APPROVED_MAPPING`, `HOLD`, `REQUEST_REVIEW`; commands exactly: `Investigate`, `Execute`, `Reconcile`, `Expire`, `Reassess`, `Resume`)
- [X] T007 [P] Unit test for the state machine in `tests/SignalNoir/Tests/Core/TestCaseMachine.cls` (only `—→Open`, `Open→ReviewRequired`, `Open→Investigating` in this slice; actor table rejects an unlisted actor with `INVALID_ACTOR`)
- [X] T008 [P] Unit test for persistence and optimistic concurrency in `tests/SignalNoir/Tests/Application/TestPersistence.cls` (`VERSIONPROPERTY` rejects a stale save; at most one non-terminal Case per `orderId`; a fresh `%OpenId` after reconnect returns the same Case and timeline)

### Implementation for Foundational

- [X] T009 [P] Implement `src/SignalNoir/Core/Vocab.cls` — states, actors (`system`, `operator:<name>`, `sweeper`, `benchmark`, `agent`), actions, commands and the closed error-code vocabulary taken from the frozen OpenAPI; add no new code
- [X] T010 [P] Implement the DTO classes in `src/SignalNoir/Core/Dto/` — `Order`, `Case`, `CaseSummary`, `TimelineEvent` fully populated, and `Evidence`, `Proposal`, `ValidatorVerdict`, `Approval`, `Execution`, `Receipt`, `Dossier` declared with the fields in `contracts/seams.md`
- [X] T011 [P] Implement the port classes in `src/SignalNoir/Core/Port/` — `CaseCommands`, `CaseQueries`, `Validator`, `Proposer`, `Tools`, `PartnerClient`, `Clock`, `IdGenerator`, with the signatures in `contracts/seams.md`
- [X] T012 [P] Implement `src/SignalNoir/Core/CaseMachine.cls` — the state machine and the transition→actor table; only the three transitions in this slice are live
- [X] T013 [P] Implement `src/SignalNoir/Core/Validator.cls` — deterministic, origin-blind, minimal rule set (declares the five preconditions but evaluates only what this slice needs)
- [X] T014 [P] Implement `src/SignalNoir/Core/Canon.cls` — the equivalence-key canonization seam (ordered codes, UTC, normalized case); used by Order acceptance
- [X] T015 [P] Implement the persistent records in `src/SignalNoir/Application/Model/` — `OrderRecord`, `CaseRecord` (with `Parameter VERSIONPROPERTY = "Version"`, `caseVersion`, `lastEventSeq`, `lastEventAt`, `synthetic`, `replay`, `reviewReason`), `CaseEventRecord` (append-only, per-Case `$INCREMENT` `seq`), `OutboxRecord`; ensure they map to the module resource
- [X] T016 [P] Implement `src/SignalNoir/Application/SystemClock.cls` and `src/SignalNoir/Application/IdFactory.cls` — `IdFactory.New(prefix)` accepts only `case_`, `prop_`, `appr_`, `exec_`, `evid_`, `cmd_`, `run_` and rejects anything else
- [X] T017 Implement `src/SignalNoir/Application/CaseService.cls` — the single mutation path implementing `CaseCommands` + `CaseQueries`: CAS on `caseVersion`, state + timeline event + outbox entry in one short I/O-free transaction; attachment commands append without bumping `caseVersion`
- [X] T018 [P] Implement the test doubles in `tests/SignalNoir/Tests/Fakes/` — `FakeCaseCommands`, `FakeCaseQueries`, `FakeValidator`, `FakeProposer`, `FakeTools`, `FakePartnerClient`, `FixedClock`, `SeqIdGenerator`, each usable with no live provider

**Checkpoint**: Foundation ready — user stories can be implemented.

---

## Phase 3: User Story 1 - Start honestly and report readiness (Priority: P1) 🎯 MVP

**Goal**: The app starts with a fresh checkout, reports readiness and provider availability
distinctly, and never crashes for a missing key.

**Independent Test**: Read health with a key and without one; the two payloads differ only in
readiness/provider, and the process stays up in both.

### Tests for User Story 1 (MANDATORY — write first) ⚠️

- [X] T019 [P] [US1] Bootstrap test in `tests/SignalNoir/Tests/Interop/TestBootstrap.cls` — with key present records provider configured; without key records unavailable with a reason naming the provider; startup never throws
- [X] T020 [P] [US1] Health contract test in `tests/SignalNoir/Tests/Api/TestHealth.cls` — asserts the `GET /health` payload matches `contracts/openapi-signalnoir.yaml`, that `liveness=alive` always, `status=ready` with key and `degraded` without, and that a missing key never yields 5xx

### Implementation for User Story 1

- [X] T021 [US1] Implement `src/SignalNoir/Interop/Bootstrap.cls` — idempotent `OnStart()`: read `SN_AI_PROVIDER`, `SN_AI_MODEL`, `SN_AI_API_KEY`; materialize the AI Hub provider via `%ConfigStore.Configuration` + `RebuildRegistry` with fallback `%AI.Provider.Create`; record availability; verify lease > partner timeout + investigation budget; never log the key
- [X] T022 [US1] Implement `src/SignalNoir/Api/Health.cls` — `%CSP.REST` for `/signalnoir/api/v1/health`: `liveness=alive`, `status` `ready`/`degraded`, `provider.configured` and optional `reason`, `serverTime`; missing key is a reported value, never an error
- [X] T023 [US1] Implement `src/SignalNoir/Proposers/Unavailable.cls` — returns the provider-unavailable result value (no exception)
- [X] T024 [US1] Implement `src/SignalNoir/Interop/Production.cls` (minimal `Ens.Production`) and register the web applications `/signalnoir/api/v1` (dispatch `SignalNoir.Api.Dispatch`) and the health route, plus ensure `Interop=1` for `IRISAPP`
- [X] T025 [US1] Wire the unavailable path: when the Proposer reports unavailable, `CaseService` transitions the Case to `ReviewRequired` with `reviewReason` naming the unavailable provider (FR-004, FR-016)

**Checkpoint**: US1 is independently testable — health and the no-key path work.

---

## Phase 4: User Story 2 - Accept, persist and reload a synthetic Order (Priority: P1)

**Goal**: One synthetic Order becomes a Case with an append-only timeline that survives a restart.

**Independent Test**: Accept an Order, read the Case and timeline, restart, read again unchanged.

### Tests for User Story 2 (MANDATORY — write first) ⚠️

- [X] T026 [P] [US2] Case read test in `tests/SignalNoir/Tests/Api/TestCasesRead.cls` — `GET /cases` and `GET /cases/{caseId}` return the Case with `synthetic=true`, `caseVersion`, `lastEventSeq` and `serverTime`
- [X] T027 [P] [US2] Restart durability test in `tests/SignalNoir/Tests/Application/TestCaseRestart.cls` — the Case and every timeline row are identical after re-opening from a fresh process/connection

### Implementation for User Story 2

- [X] T028 [P] [US2] Implement `src/SignalNoir/Api/Dispatch.cls` — `%CSP.REST` for `/signalnoir/api/v1`: `GET /cases`, `GET /cases/{caseId}`, mapping DTOs to JSON; errors use the closed envelope
- [X] T029 [US2] Implement `src/SignalNoir/Interop/Service/OrderIn.cls` — Business Service accepts one synthetic Order and calls the single command path (`CaseService`) to persist the Order and open the Case
- [X] T030 [US2] Write the timeline events for acceptance in `src/SignalNoir/Application/CaseService.cls` — `OrderAccepted`, `CaseOpened` (and `ReviewRequired` when applicable), each with monotonic `seq` and UTC `at`
- [X] T031 [US2] Start the Production and route the Order through the Business Service in `tests/SignalNoir/Tests/Interop/TestProductionStart.cls`, using `Ens.Director` (covered by the test in T027/T030; no direct BP/BO calls)

**Checkpoint**: US1 and US2 both work; the Case survives a restart.

---

## Phase 5: User Story 3 - Build another feature against the published seam (Priority: P2)

**Goal**: A consumer compiles and tests against `docs/seams.md` and the fakes without editing
this feature's files.

**Independent Test**: Compile and run a trivial consumer that imports only the seam and the fakes.

### Tests for User Story 3 (MANDATORY — write first) ⚠️

- [X] T032 [P] [US3] Seam consumer test in `tests/SignalNoir/Tests/Seam/TestConsumerUsesSeam.cls` — a test-only consumer uses every port through its fake and compiles with no reference to feature implementation classes
- [X] T033 [P] [US3] Runtime-exclusion test in `tests/SignalNoir/Tests/Seam/TestFakesNotRuntime.cls` — asserts the fakes are not resolvable in the runtime resource of module `signalnoir`

### Implementation for User Story 3

- [X] T034 [US3] Confirm `module.xml` keeps the fakes out of the runtime resource and only under the `test` phase (`tests/`), adjusting `<Resource>`/`<UnitTest>` if needed
- [X] T035 [US3] Finalize `docs/seams.md` so every port and DTO signature matches the implemented classes; record it as the published contract consumers build against
- [X] T036 [US3] Add a test-only sample consumer in `tests/SignalNoir/Consumer/Consumer.cls` that imports only the seam and the fakes (never the Proposers/Api/Interop packages)

**Checkpoint**: A second feature team can start against the seam.

---

## Phase 6: User Story 4 - Prove the skeleton with the test harness (Priority: P2)

**Goal**: The harness runs on the build 154 container and a single smoke proves the skeleton.

**Independent Test**: Run the smoke on a clean environment; it passes.

### Tests / Harness for User Story 4 (MANDATORY — write first) ⚠️

- [X] T037 [P] [US4] Smoke test in `tests/SignalNoir/Tests/Smoke/TestWalkingSkeleton.cls` — covers start, accept, read, restart and the provider-unavailable path end to end
- [X] T038 [US4] Document the harness command to run all `%UnitTest` suites and the smoke through iris-agentic-dev, in `dev.md` (added section, not a README rewrite)

### Implementation for User Story 4

- [X] T039 [US4] Make the smoke runnable on a clean build 154 container: assert no provider is required for startup, and that the smoke reaches the first Case in the documented run

**Checkpoint**: The skeleton is proven by the harness.

---

## Phase 7: Polish & Cross-Cutting Concerns

- [X] T040 [P] Delete the throwaway `SN.Proto.VersionProbe*` classes from the dev container and record the cleanup in `research.md`
- [X] T041 [P] Verify `Interop=1` for `IRISAPP` on a freshly built container and record the result (research.md D2 risk)
- [X] T042 [P] Search the module, timeline, logs and exports for the provider key and confirm zero occurrences (FR-018)
- [X] T043 [P] Review the diff against the Constitution, the spec, the plan and the tests before merge (Engineering Standards review gate)
- [X] T044 Run `quickstart.md` end to end on a clean container and fix any gap
- [X] T045 Record approval of contract change 001 by a second team member (Governance) and mark the proposal applied in `contracts/contract-change-001-health.md`

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: no dependencies.
- **Foundational (Phase 2)**: depends on Setup; blocks all user stories.
- **US1 (Phase 3)**: after Foundational. MVP.
- **US2 (Phase 4)**: after Foundational; integrates with US1's CaseService and shares the Api app.
- **US3 (Phase 5)**: after Foundational; depends on the ports/DTOs/fakes (T009–T018).
- **US4 (Phase 6)**: after US1 and US2 (the smoke drives them).
- **Polish (Phase 7)**: after all stories.

### User Story Dependencies

- **US1 (P1)**: independent after Foundational.
- **US2 (P1)**: independent after Foundational; extends the same Api app but never edits US1 files.
- **US3 (P2)**: independent after Foundational (seam + fakes only).
- **US4 (P2)**: needs US1 + US2 to have an end-to-end path.

### Within Each Story

- Tests are written and MUST fail before the implementation.
- Models before services; services before endpoints; endpoints before the smoke.
- Story complete and validated before the next priority.

### Parallel Opportunities

- Setup: T004, T005 in parallel.
- Foundational tests T006–T008 in parallel; implementation T009–T016 and T018 in parallel; T017 after T015.
- US1: T019, T020 in parallel; T021–T023 in parallel; T024/T025 after.
- US2: T026, T027 in parallel; T028 parallel with T029/T030.
- US3: T032, T033 in parallel; T034–T036 parallel after.
- US4: T037 in parallel with T038.
- Polish: T040–T043 in parallel.

---

## Parallel Example: Foundational

```bash
# Tests first (different files):
Task: "T006 Unit test vocab in tests/SignalNoir/Tests/Core/TestVocab.cls"
Task: "T007 Unit test case machine in tests/SignalNoir/Tests/Core/TestCaseMachine.cls"
Task: "T008 Persistence test in tests/SignalNoir/Tests/Application/TestPersistence.cls"

# Then parallel implementation:
Task: "T009 Core/Vocab.cls"
Task: "T010 Core/Dto/*"
Task: "T011 Core/Port/*"
Task: "T015 Application/Model/*"
Task: "T018 Tests/Fakes/*"
```

## Parallel Example: User Story 1

```bash
Task: "T019 Bootstrap test tests/SignalNoir/Tests/Interop/TestBootstrap.cls"
Task: "T020 Health contract test tests/SignalNoir/Tests/Api/TestHealth.cls"
Task: "T021 Interop/Bootstrap.cls"
Task: "T022 Api/Health.cls"
Task: "T023 Proposers/Unavailable.cls"
```

---

## Implementation Strategy

### MVP First (User Story 1)

1. Phase 1 Setup → Phase 2 Foundational → Phase 3 US1.
2. **STOP and VALIDATE**: read health with and without a key; the process stays up.
3. This is the first demonstrable slice.

### Incremental Delivery

1. Setup + Foundational → foundation ready.
2. US1 → validate → health demo (MVP).
3. US2 → validate → accept/read/restart demo.
4. US3 → validate → a second team compiles against the seam.
5. US4 → validate → smoke on a clean container.
6. Polish → cleanup, key search, review, quickstart, contract approval.

### Notes

- [P] marks different files with no dependency.
- Every task names its file path and its constraint source (spec FR / contract).
- Tests run on the live build 154 container through iris-agentic-dev, not on the host.
- Do not start implementation before 2026-10-26 (Constitution calendar gate).
