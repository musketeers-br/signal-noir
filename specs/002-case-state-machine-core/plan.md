# Implementation Plan: Case state machine Core (Phase B)

**Branch**: none (spec directory `002-case-state-machine-core`) | **Date**: 2026-10-22 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `/specs/002-case-state-machine-core/spec.md`

## Summary

Enforce the normative Case state machine (`contracts/case-state-machine.yaml`, T01–T29) on real Cases:
1. A pure Core decision, `SignalNoir.Core.Decider.Decide(snapshot, command, now) → Decision`, holding the rows as compiled data and the preconditions as named checks (research R4, R5).
2. The single Application command path, `SignalNoir.Application.CaseCommands`, which records each decision atomically with compare-and-swap, or records `CommandDiscarded` (R6, R7).
3. A parity test against a JSON export of the YAML, plus scenario tests for refusals, concurrency, journeys UJ-1 to UJ-4 and episodes (R3, R9).

ObjectScript is the **provisional** language (R1). Every decision that depends on the 10/25 spike is marked **SPIKE-DEPENDENT** below and in research, each with its fallback.

## Spike-dependent decisions

| # | Decision | What the spike must confirm | Fallback if it does not | Research |
|---|---|---|---|---|
| S1 | ObjectScript for Core, Application and tests | nothing for ObjectScript itself; Q-F (Embedded Python version) only matters if the team prefers R4 option 2 or 3 | option 2: Python method bodies in the same classes, same signatures and tests; option 3 needs a Constitution amendment and AD-1/AD-16 changes. Decide by 10/27 | R1 |
| S2 | Tests run on build 154 through iris-agentic-dev | a build 154 container is up and reachable (Atelier REST, port 52773) | run on the current dev container (2026.2 Build 221U) as provisional runs; a task is done only after its suite passes on build 154 | R2 |
| S3 | Parity test reads `tests/fixtures/case-state-machine.json` | `%UnitTest` can read a file from the tests directory inside the build 154 container | the export tool also writes `SignalNoir.Tests.Core.TableFixture` with the JSON in `XData`; the test reads that | R3 |
| S4 | Classes declared in `module.xml` and loaded by IPM | IPM installs on build 154 (AD-27) | load and compile through iris-agentic-dev only; `module.xml` changes wait for B04 | R10 |

## Technical Context

**Language/Version**: ObjectScript on IRIS AI Hub EAP build 154 (provisional — S1). Dev tooling: Python 3.12 via `uv` for the JSON export of the table, next to the existing contract tools.

**Primary Dependencies**: none beyond IRIS (`%RegisteredObject`, `%Persistent`, SQL, `%DynamicObject`, `%UnitTest`). The Core does not depend on AI Hub (`%AI.*`).

**Storage**: IRIS persistent classes under `SignalNoir.Application.Store` — Case (with the `OpenOrderKey` unique index), TimelineEvent, OutboxEntry — reusing whatever B04 already created (R11).

**Testing**: `%UnitTest` packages `SignalNoir.Tests.Core.*` and `SignalNoir.Tests.Application.*`, run through iris-agentic-dev on the live instance (S2); TDD, each test written and seen failing before the code. The JSON fixture's freshness is checked in the contracts CI.

**Target Platform**: the IRIS AI Hub build 154 container of the submission (S2).

**Project Type**: domain core and application layer of an IRIS Interoperability product (hexagonal, AD-1).

**Performance Goals**: `Decide` well under 1 ms per call (a table lookup and a few checks); a command, including its transaction, within NFR-3's 5 s budget with a large margin. No load target beyond the demo and the Benchmark.

**Constraints**: Core with no I/O (Principle I); one short transaction per command with no external I/O (AD-2); optimistic CAS, no locks (AD-3); outbox in the same transaction (AD-20); English everywhere (Language); no change to Dockerfile or compose files (owned by B04 and the template).

**Scale/Scope**: 29 transitions, 10 attachment kinds, 4 refusal codes; about 8 classes in Core and Application, 3 persistent classes (shared with B04), 6 test suites.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- [x] **I. Pure Core** — `Decider`, `TransitionTable`, `Preconditions` and the value objects live in `SignalNoir.Core` with no I/O; a test asserts the absence of persistence and I/O references. All callers go through `SignalNoir.Application.CaseCommands`. The Simulator is not touched.
- [x] **II. Closed Action Catalog / Read-Only Agent** — no Action added; the table rows are compiled `XData`, never code built from input.
- [x] **III. One Validator** — the Core consumes the Validator's verdict as a fact; it never decides a verdict itself. The Validator is out of scope.
- [x] **IV. Human Authority** — expiry only by `sweeper` (T18); `APPROVAL_EXPIRED` at the authorization CAS (T17); voided authorization never accepted again; `benchmark` only in T12 on a BenchmarkRun Case.
- [x] **V. Case as Source of Truth** — single command path; state, events and outbox in one short transaction; CAS on every transition; append-only Timeline; terminal never reopens (T02 for new episodes).
- [x] **VI. Effects at Most Once** — the Core enforces "one Execution in flight", authorization before the effect (T17), and the uncertainty block (D4); the effect key itself is story 2.3.
- [x] **VII. Honest Outcomes** — `Decision` and `CommandResult` are values; refusals are recorded and returned as refusals; infrastructure errors become `Failed`, never `Applied`.
- [x] **VIII. Honest Measurement** — N/A beyond keeping `benchmark` confined to T12.
- [x] **IX. Verifiable Increments** — extends B04's tracer slice (R11); the journey and episode suites make the behavior observable end to end, not a layer on its own.
- [x] **Platform Constraints** — build 154 as the target; synthetic labels on every Case; no secrets; no image published.
- [x] **Language** — all classes, comments, test names and this plan in English.
- [ ] **iris-agentic-dev** — classes compile and tests run through it (pass). Platform claims verified on build 154: **not yet**; the current container is 2026.2 Build 221U without `%AI.Agent` (checked 2026-10-22). Tracked as S2–S4 and in Complexity Tracking.

**Post-design re-check (Phase 1)**: unchanged. The only open gate is the build 154 verification, which the spike or the first build 154 container closes. No principle is violated by the design.

## Project Structure

### Documentation (this feature)

```text
specs/002-case-state-machine-core/
├── spec.md
├── plan.md              # this file
├── research.md          # R1–R11, spike-dependent items marked
├── data-model.md        # value objects and stored records
├── quickstart.md        # how to validate
├── contracts/
│   ├── core-port.md     # Decide: provisional ObjectScript form
│   └── command-path.md  # CaseCommands: the only mutation path
├── checklists/requirements.md
└── tasks.md             # /speckit-tasks
```

### Source Code (repository root)

```text
src/SignalNoir/
├── Core/
│   ├── Decider.cls              # Decide(snapshot, command, now)
│   ├── TransitionTable.cls      # XData: 29 rows, attachment matrix, parameters
│   ├── Preconditions.cls        # one method per check of the closed vocabulary
│   ├── CaseSnapshot.cls         # value objects (%RegisteredObject)
│   ├── TransitionCommand.cls
│   └── Decision.cls
└── Application/
    ├── CaseCommands.cls         # Submit, RecordException
    ├── CommandResult.cls
    └── Store/                   # shared with B04 (R11)
        ├── Case.cls             # + OpenOrderKey unique index
        ├── TimelineEvent.cls
        └── OutboxEntry.cls

tests/
├── fixtures/case-state-machine.json   # generated from the YAML (R3)
└── SignalNoir/Tests/
    ├── Core/Parity.cls, Decide.cls, TableFixture.cls (fallback S3, generated)
    └── Application/CommandPath.cls, Concurrency.cls, Journeys.cls, Episodes.cls

contracts/tools/export_state_machine_json.py   # YAML → JSON (and XData fallback)
.github/workflows/contracts.yml                # + JSON freshness check
```

**Structure Decision**: packages and test naming follow the spine (Design Paradigm, `SignalNoir.Tests.<Package>`). `src/dc/sample` and `module.xml` renaming stay with B04 (S4). Docker and compose files are not touched.

## Complexity Tracking

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| Tests may run on the 2026.2 dev container before build 154 is available (S2), while the Constitution (1.2.0) asks for tests on the contest build | Lets TDD start now, as the 1.2.0 amendment intends; the Core has no AI Hub dependency, so results are representative | Waiting for build 154 blocks the work the amendment opened. Mitigation: a task counts as done only after its suite passes on build 154 |
| Constitution 1.2.0 (lifting the calendar gate) is pending team review | This plan assumes code may start before 10/26 | If the review rejects 1.2.0, the tasks wait until 10/26 unchanged; nothing in the design depends on the date |
