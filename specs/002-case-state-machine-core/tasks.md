---

description: "Task list for the Case state machine Core (Phase B, B06)"
---

# Tasks: Case state machine Core (Phase B)

**Input**: Design documents from `/specs/002-case-state-machine-core/`

**Prerequisites**: [plan.md](plan.md), [spec.md](spec.md), [research.md](research.md), [data-model.md](data-model.md), [contracts/](contracts/), [quickstart.md](quickstart.md)

**Tests**: MANDATORY (Constitution, Engineering Standards — TDD; Principle IX). Every test method is written and seen failing before the code that makes it pass. ObjectScript tests (`%UnitTest`) are compiled and run on the live instance through iris-agentic-dev.

**Language**: tasks, code, comments and test names are in English (Constitution, Language).

**SPIKE-DEPENDENT**: tasks tagged `[S1]`–`[S4]` rely on a decision of the plan's "Spike-dependent decisions" table; if the spike contradicts it, apply the fallback written there. Until a build 154 container is up, runs on the 2026.2 dev container are **provisional** `[S2]`; T051 re-runs everything on build 154 and only then are the stories done.

**Gate**: this list assumes Constitution 1.2.0 (calendar gate lifted, pending team review). If the review rejects it, start on 2026-10-26 with no other change.

**Organization**: tasks are grouped by the spec's user stories. All code is ObjectScript `[S1]` unless the path says otherwise.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: can run in parallel (different files, no dependency on incomplete tasks)
- **[Story]**: the spec's user story (US1–US4)

## Path Conventions

- Core: `src/SignalNoir/Core/` (package `SignalNoir.Core`)
- Application: `src/SignalNoir/Application/` and `src/SignalNoir/Application/Store/`
- Tests: `tests/SignalNoir/Tests/Core/` and `tests/SignalNoir/Tests/Application/` (packages `SignalNoir.Tests.Core`, `SignalNoir.Tests.Application`)
- Compile: `iris-agentic-dev compile <paths>`; run a suite: iris-agentic-dev's unit-test tool, or `iris-agentic-dev exec` of `%UnitTest.Manager` `[S4]`
- Table fixture: `tests/fixtures/case-state-machine.json`, generated from `contracts/case-state-machine.yaml`

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: target instance, existing B04 classes, the table fixture and the folder layout

- [X] T001 Record which instance the suites run on: query `$ZVERSION` and the existence of `%AI.Agent` through `iris-agentic-dev exec`, and write the result (build 154, or provisional 2026.2 `[S2]`) under a "Verification log" heading at the end of `specs/002-case-state-machine-core/research.md`
- [X] T002 Inventory what B04 already created on the instance and in `src/` (`SignalNoir.Application.Store.*` or equivalent Case, Timeline and outbox classes) with `iris-agentic-dev query`/`doc`, and record in the Verification log of `specs/002-case-state-machine-core/research.md` which classes T013–T015 must extend versus create (research R11)
- [X] T003 [P] Create the folders `src/SignalNoir/Core/`, `src/SignalNoir/Application/Store/`, `tests/SignalNoir/Tests/Core/`, `tests/SignalNoir/Tests/Application/` and `tests/fixtures/` (no change to `module.xml`, Dockerfile or compose files `[S4]`)
- [X] T004 [P] Write the failing test `contracts/tools/test_export_state_machine_json.py`: exporting `contracts/tools/tests/state_machine/_base.yaml` produces JSON with the same `states`, `transitions` (id, from, to, actors, preconditions, events, followUp, sameStepAs), `attachments`, `refusals`, `parameters` and `journeyTrace`; `--xdata` additionally writes an ObjectScript class whose `XData` block parses to the same JSON `[S3]`
- [X] T005 Implement `contracts/tools/export_state_machine_json.py` (Python, same style as `contracts/tools/validate_fixtures.py`): YAML → `tests/fixtures/case-state-machine.json` by default; `--xdata` also writes `tests/SignalNoir/Tests/Core/TableFixture.cls` `[S3]`; run T004 green
- [X] T006 Generate `tests/fixtures/case-state-machine.json` from `contracts/case-state-machine.yaml` and add a step to `.github/workflows/contracts.yml` that re-runs the export and fails on `git diff --exit-code -- tests/fixtures/case-state-machine.json`

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: value objects, the compiled table, the stored records and the result type every story uses

**⚠️ CRITICAL**: no user story starts before this phase ends

### Tests first (must fail)

- [X] T007 [P] Write `tests/SignalNoir/Tests/Core/Purity.cls`: for every class of package `SignalNoir.Core`, read its compiled method implementations from `%Dictionary` and fail on any reference to `%Persistent` subclasses, `&sql`, `%SQL.`, `%File`, `%Stream.File`, `%Net.`, `$ZTIMESTAMP`, `$HOROLOG`, `$INCREMENT` or globals (`^`) (FR-001, Principle I)
- [X] T008 [P] Write `tests/SignalNoir/Tests/Core/TableData.cls`: load the fixture (file `[S3]`, or `TableFixture` XData as fallback) and assert that `SignalNoir.Core.TransitionTable` holds the same 29 rows (id, from, to, actors, events, outbox, sameStepAs), the same attachment matrix (event × states, terminal kinds) and the same parameters
- [X] T009 [P] Write `tests/SignalNoir/Tests/Application/Store.cls`: a second non-terminal Case for the same `OrderId` is rejected by the unique index on `OpenOrderKey`; once the first Case is terminal a new one is accepted; `TimelineEvent.Seq` is strictly increasing per Case; `TimelineEvent` exposes no update or delete method (research R7, data-model)
- [X] T010 Compile the tests and run the three suites: all fail because the classes do not exist (record the red run in the Verification log)

### Implementation

- [X] T011 [P] Create the value objects `src/SignalNoir/Core/CaseSnapshot.cls`, `src/SignalNoir/Core/TransitionCommand.cls` and `src/SignalNoir/Core/Decision.cls` (`%RegisteredObject`) with the fields of [data-model.md](data-model.md) and no logic beyond constructors
- [X] T012 Create `src/SignalNoir/Core/TransitionTable.cls`: an `XData` JSON block with the 29 rows, the attachment matrix and `parameters` transcribed from `contracts/case-state-machine.yaml`, plus class methods `Rows(fromState, toState)`, `AttachmentAllowed(event, state)` and `Parameter(name)`; run T008 and T007 green
- [X] T013 Create or extend `src/SignalNoir/Application/Store/Case.cls` per T002: fields of the snapshot, `OpenOrderKey` computed and stored (`OrderId` while non-terminal, `"closed:"_CaseId` when terminal) with a unique index, `LastEventAt`, labels (research R7, R11)
- [X] T014 [P] Create or extend `src/SignalNoir/Application/Store/TimelineEvent.cls`: `CaseId`, `Seq` assigned by `$INCREMENT` on a per-Case global, `At`, `Type`, `Actor`, `RefId`, `Payload`; insert-only API
- [X] T015 [P] Create or extend `src/SignalNoir/Application/Store/OutboxEntry.cls`: `CommandId` (unique), `Kind`, `CaseId`, `CaseVersionAfter`, `Status`, `CreatedAt`
- [X] T016 [P] Create `src/SignalNoir/Application/CommandResult.cls` with `Outcome`, `CaseId`, `State`, `CaseVersion`, `RefusalCode`, `Events`, `OutboxCommandIds`, `FailureText` ([contracts/command-path.md](contracts/command-path.md))
- [X] T017 Run T007–T009 green on the instance `[S2]`

**Checkpoint**: table compiled and equal to the YAML; stored records with the uniqueness and append-only guarantees

---

## Phase 3: User Story 1 - Every command against a Case obeys the normative table (Priority: P1) 🎯 MVP

**Goal**: the decision accepts exactly the table's 29 rows, and the command path records each accepted decision atomically

**Independent Test**: the `Parity` suite (29/29 rows accepted, every pair outside refused) and the `CommandPath` atomicity tests pass

### Tests for User Story 1 (MANDATORY — write first) ⚠️

- [X] T018 [P] [US1] Write the test helper `tests/SignalNoir/Tests/Core/SnapshotBuilder.cls`: given a fixture row, build a `CaseSnapshot` and a `TransitionCommand` (first listed actor, expected state and version, facts) that satisfy every precondition of the row; one builder method per `check` of the vocabulary
- [X] T019 [P] [US1] Write `tests/SignalNoir/Tests/Core/Parity.cls`: `TestEveryRowAccepted` (for each of the 29 fixture rows, `Decide` returns `Accepted` with the row's `to`, events — `StateChanged` first with `caseVersionAfter = version + 1` — outbox and same-step chain) and `TestPairsOutsideTableRefused` (every (state, target) pair of 13 × 13 not in the table → `Refused` with `INVALID_TRANSITION`) (FR-012, SC-001)
- [X] T020 [P] [US1] Write `tests/SignalNoir/Tests/Core/Decide.cls` methods `TestRevalidationPrecedence` (both `ORDER_ACTIVE_AT_ORIGIN` and `PARTNER_HEALTHY_WINDOW` false → T21; policy changed and partner unstable → T22), `TestVoidedAuthorizationNeverAccepted`, `TestDenialCount` (T13 increments, T14 at 1, T15 at 2, T22/T27 do not reset) and `TestAttachments` (new Exception in `Executing` → `Attach`; `ToolCalled` in `Executing` → refused)
- [X] T021 [P] [US1] Write `tests/SignalNoir/Tests/Application/CommandPath.cls` methods `TestAppliedIsAtomic` (approve in `PendingApproval` → `Approved`, `CaseVersion + 1`, `ApprovalRecorded` and `StateChanged`, one `Execute` outbox entry), `TestSameStepChain` (operator resolution T28 → T07 → T11 in one transaction, three `StateChanged`, version + 3), `TestAttachKeepsVersion`, `TestFailureRecordsNothing` (a duplicate outbox `CommandId` aborts the transaction: state, version, events and outbox unchanged, `Outcome = Failed`) and `TestRecordExceptionPaths` (T01 for a new Order, T16 in `PendingApproval`, attachment in `Executing`)
- [X] T022 [US1] Compile and run T019–T021: all fail (record the red run)

### Implementation for User Story 1

- [X] T023 [US1] Implement `src/SignalNoir/Core/Preconditions.cls`: one class method per `check` of the closed vocabulary (specs/001 data-model), each `(snapshot, command, now, expected) → %Boolean`, resolving parameter names through `TransitionTable.Parameter`
- [X] T024 [US1] Implement `src/SignalNoir/Core/Decider.cls` `Decide` steps 4, 6 and 7 of [contracts/core-port.md](contracts/core-port.md) (row lookup, precondition filtering, revalidation precedence) and the building of events, record effects, outbox and same-step chain; run T019 and T020 green
- [X] T025 [US1] Implement `src/SignalNoir/Application/CaseCommands.cls` `Submit`: read the Case into a `CaseSnapshot`, read the clock once (research R8), call `Decide`, and in one `TSTART`/`TCOMMIT` apply the CAS update, record effects, events and outbox entries, then the same-step chain; any `%Status` error rolls back and returns `Failed` (research R6)
- [X] T026 [US1] Implement `CaseCommands.RecordException` for T01, T16 and the `ExceptionRecorded` attachment (the T02 path comes in US4), including the retry-as-attachment when the `OpenOrderKey` insert loses to a concurrent first Exception (research R7)
- [X] T027 [US1] Run T019–T021 green and T007 still green (the Core stayed pure) `[S2]`

**Checkpoint**: the table is enforced on real Cases; MVP of B06

---

## Phase 4: User Story 2 - A disallowed command changes nothing and leaves a trace (Priority: P1)

**Goal**: every refusal code is produced where the table says, recorded as `CommandDiscarded`, and concurrent writers never both win

**Independent Test**: refusal tests and the `Concurrency` suite (100 runs per scenario) pass

### Tests for User Story 2 (MANDATORY — write first) ⚠️

- [X] T028 [P] [US2] Add to `tests/SignalNoir/Tests/Core/Decide.cls`: `TestInvalidTransition` (`Open → Executing`), `TestInvalidActor` (`benchmark` outside a BenchmarkRun on T12, `rules` on a Case in `agent` mode on T04, `system` asking for T18), `TestStaleVersion`, `TestApprovalExpired` (T17 with `expiresAt` ≤ now) and `TestIdempotentApproval` (repeat approval with a stale version → `IdempotentReplay`, no events, no outbox)
- [X] T029 [P] [US2] Add to `tests/SignalNoir/Tests/Application/CommandPath.cls`: `TestRefusalRecordsCommandDiscarded` (each of the four codes leaves state and version unchanged and exactly one `CommandDiscarded {command, actor, currentState, requestedState, code}`), `TestCasLostAtWrite` (the Case changes between read and write → `Refused` `STALE_VERSION`, recorded) and `TestIdempotentReplayReturnsExisting` (FR-007, SC-002)
- [X] T030 [P] [US2] Write `tests/SignalNoir/Tests/Application/Concurrency.cls`: `JOB`-based scenarios with a global barrier (research R9) — two approvals of the same Proposal, approval versus new Exception in `PendingApproval`, two first Exceptions for one Order — each repeated 100 times, asserting exactly one winner and a recorded refusal or attachment for every loser (SC-004)
- [X] T031 [US2] Compile and run T028–T030: the new methods fail (record the red run)

### Implementation for User Story 2

- [X] T032 [US2] Implement `Decide` steps 1, 2, 3 and 5 of [contracts/core-port.md](contracts/core-port.md) (attachment check, idempotent approval before the version check, stale version and target mismatch, actor filtering with `operator:*`, proposer mode and BenchmarkRun) in `src/SignalNoir/Core/Decider.cls`, and the `APPROVAL_EXPIRED` case of step 6
- [X] T033 [US2] Implement the refusal recording in `src/SignalNoir/Application/CaseCommands.cls`: `CommandDiscarded` with the C4 payload in its own short transaction; CAS zero-rows → `STALE_VERSION` recorded; `IdempotentReplay` returns the existing Approval with no write
- [X] T034 [US2] Run T028–T030 green, and T019–T021 still green `[S2]`

**Checkpoint**: SC-002 and SC-004 met

---

## Phase 5: User Story 3 - The Operator's journeys run end to end through the Core (Priority: P2)

**Goal**: UJ-1 to UJ-4 replay through the command path with the actors of `journeyTrace`

**Independent Test**: the `Journeys` suite passes, one test method per journey

### Tests for User Story 3 (MANDATORY — write first) ⚠️

- [X] T035 [P] [US3] Write the test helper `tests/SignalNoir/Tests/Application/JourneyRunner.cls`: read `journeyTrace` from the fixture and, for each step, submit the commands of its `refs` in order with the listed actors and the facts the step needs (Validator verdict, revalidation failures, Partner response class), asserting the state after each step
- [X] T036 [P] [US3] Write `tests/SignalNoir/Tests/Application/Journeys.cls`: `TestUJ1` (ends `Resolved`; the repeated approval of step 7 is an idempotent replay with one Execution), `TestUJ2` (ends `PendingApproval` with a new Proposal after `Held`; old Approval never reused; variant ends `Cancelled` with no Attempt), `TestUJ3` (ends `ResolvedByPriorReceipt` with no Execution), `TestUJ4` (`RETRY` blocked leaves only `ValidatorVerdict`; ends `Cancelled` by `operator:Carla`; variant with `provider_unavailable` resolves through T28 → T07 → T11 → T17 → T23) (SC-003)
- [X] T037 [US3] Compile and run T036: it fails where the journeys need behavior US1–US2 did not cover (record the red run and the gaps in the Verification log)

### Implementation for User Story 3

- [X] T038 [US3] Close the gaps found in T037 in `src/SignalNoir/Core/Decider.cls`, `src/SignalNoir/Core/Preconditions.cls` or `src/SignalNoir/Application/CaseCommands.cls`; if a gap shows the table itself is wrong, stop and raise a change proposal to `contracts/case-state-machine.yaml` and specs/001 instead of changing the Core alone
- [X] T039 [US3] Run T036 green and all earlier suites still green `[S2]`

**Checkpoint**: the demo journeys are enforced end to end

---

## Phase 6: User Story 4 - Terminal Cases never reopen and new episodes stay linked (Priority: P3)

**Goal**: terminal states accept no transition; T02 opens linked episodes; T25 → T02 in one transaction; terminal annotations only

**Independent Test**: the `Episodes` suite passes

### Tests for User Story 4 (MANDATORY — write first) ⚠️

- [X] T040 [P] [US4] Write `tests/SignalNoir/Tests/Application/Episodes.cls`: `TestTerminalRefusesTransitions` (each of the 4 terminal states refuses every target with `INVALID_TRANSITION`), `TestNewEpisodeAfterResolved` (new Case in `Open` with `PreviousEpisodeCaseId`; old Case keeps state and version and gains only `Annotation` `new_episode_opened`), `TestFailedWithPendingExceptionOpensEpisode` (T25 and T02 committed together), `TestTerminalAnnotationsOnly` (`receipt_corrected` and `receipt_missing` accepted on `Resolved` without a version change; `note` and `ExceptionRecorded` refused) and `TestOpenOrderKeyFreedOnTerminal`
- [X] T041 [US4] Compile and run T040: it fails (record the red run)

### Implementation for User Story 4

- [X] T042 [US4] Implement the T02 path of `CaseCommands.RecordException` in `src/SignalNoir/Application/CaseCommands.cls`: new Case with `PreviousEpisodeCaseId`, `new_episode_opened` annotation on the previous Case, both in one transaction
- [X] T043 [US4] Implement the T25 → T02 same-step chain when `PendingReassessmentExceptions` > 0, and the terminal attachment rules (only `receipt_corrected`, `receipt_missing`, `new_episode_opened` and `CommandDiscarded`) in `src/SignalNoir/Core/Decider.cls` and `src/SignalNoir/Application/CaseCommands.cls`
- [X] T044 [US4] Run T040 green and all earlier suites still green `[S2]`

**Checkpoint**: Principle V's "terminal never reopens" enforced

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: table-change detection, build 154 verification, review and hand-off

- [X] T045 [P] Prove SC-005: in a scratch copy, change one row's `events` in `contracts/case-state-machine.yaml`, re-export the fixture and run `Parity`; it must fail naming that row; record the result in the Verification log
- [X] T046 [P] Add a short section "Case state machine Core" to `specs/002-case-state-machine-core/quickstart.md` listing the actual suite names and the command used to run them, if they differ from the plan
- [X] T047 [P] Review every module that touches Cases (`src/SignalNoir/**`) for writes outside `CaseCommands` (SC-006) and record the result in the Verification log
- [ ] T048 [P] If the spike changed S1 (language), S3 (fixture access) or S4 (packaging), apply the fallback from the plan's table and update `specs/002-case-state-machine-core/plan.md` and `research.md` accordingly; otherwise mark S1–S4 as confirmed in the plan
- [X] T049 Run [quickstart.md](quickstart.md) §1, §2, §3 and §5 end to end
- [X] T050 Run the spec 001 checks (`contracts/tools/test_validate_state_machine.py`) and the contracts CI steps locally to confirm nothing in `contracts/` regressed
- [ ] T051 `[S2]` On a build 154 container, compile everything and run all six suites through iris-agentic-dev; record `$ZVERSION`, the suite results and the date in the Verification log; only after this run are US1–US4 done
- [ ] T052 Request review of the diff against the Constitution, the spec, the plan and the tests (Workflow step 7) from Henry or Henrique, and add the outcome to the notes of `_bmad-output/initiative-signal-noir/tickets/epic-caso-e-decisao/epic-caso-e-decisao.md`

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: none; T002 must finish before T013–T015
- **Foundational (Phase 2)**: depends on Setup; blocks every story
- **US1 (Phase 3)**: depends on Phase 2
- **US2 (Phase 4)**: depends on US1 (it extends `Decider` and `CaseCommands`, the same files)
- **US3 (Phase 5)**: depends on US1 and US2 (journeys use approvals, refusals and idempotent replay)
- **US4 (Phase 6)**: depends on US1; can run in parallel with US2/US3 only if `CaseCommands.cls` edits are coordinated
- **Polish (Phase 7)**: after the stories; T051 is the gate that closes US1–US4

### Within Each User Story

- Tests first, seen failing (the red-run task), then implementation, then the green-run task
- `Decider.cls` and `CaseCommands.cls` are shared by all stories: no [P] across stories on those files
- Value objects before the decision; the decision before the command path

### Outside dependencies

- **B04** (`epic-fundacao-e-simulador`): first persisted Case and Production transport (T002, research R11)
- **Spike B02 (10/25)**: S1–S4
- **Build 154 container**: T051 (someone downloads the image from the EAP portal; Claude cannot)
- **Constitution 1.2.0 review**: allows starting before 10/26

## Parallel Example: User Story 1

```bash
Task: "Write SnapshotBuilder in tests/SignalNoir/Tests/Core/SnapshotBuilder.cls"
Task: "Write Parity tests in tests/SignalNoir/Tests/Core/Parity.cls"
Task: "Write Decide tests in tests/SignalNoir/Tests/Core/Decide.cls"
Task: "Write CommandPath tests in tests/SignalNoir/Tests/Application/CommandPath.cls"
```

## Implementation Strategy

### MVP (User Story 1)

1. Phases 1 and 2: fixture, compiled table, stored records
2. Phase 3: the decision and the command path accept exactly the table
3. **Stop and validate**: `Parity` 29/29 and `CommandPath` green — the table is enforced on real Cases

### Incremental Delivery

1. US2: refusals and concurrency (the Operator's guarantee)
2. US3: the demo journeys end to end
3. US4: terminal states and episodes
4. Polish: build 154 run (T051), review, hand-off
