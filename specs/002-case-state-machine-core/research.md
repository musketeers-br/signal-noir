# Research: Case state machine Core (Phase B)

**Feature**: [spec.md](spec.md) | **Plan**: [plan.md](plan.md) | **Date**: 2026-10-22

Decisions marked **SPIKE-DEPENDENT** rely on something the 10/25 spike (B02) must confirm on IRIS AI Hub build 154. Each one names its fallback, so the work can start now and switch without replanning if the spike contradicts it. Everything else rests on standard IRIS behavior or on decisions already adopted in the architecture spine.

## R1 — Implementation language: ObjectScript (provisional) — **SPIKE-DEPENDENT**

- **Decision**: ObjectScript for the Core, the Application command path and their tests, as AD-1 and AD-16 assume today (option 1 of specs/001 research R4).
- **Rationale**: it needs no amendment and no AD change, it matches the `%UnitTest` rule of the Constitution, and nothing in the Core needs Python. The Core uses only classes, SQL, transactions and `$INCREMENT`, which every IRIS build has.
- **Spike dependency**: Q-F (Embedded Python version on build 154) matters only if the team wants option 2 or 3 of R4. ObjectScript does not depend on it.
- **Fallback if the spike changes the choice**: option 2 (Python methods `[Language = python]` inside the same ObjectScript classes) keeps class names, DTOs and tests and replaces method bodies only; option 3 would require a Constitution amendment and AD-1/AD-16 changes. **Decide by 10/27**: after that, switching costs a rewrite of the Core.
- **Alternatives considered**: options 2 and 3 of R4 (deferred to the spike); a separate Python service (forbidden by Principle I and AD-1: the Core lives in `SignalNoir.Core`, with no I/O).

## R2 — Where the tests run — **SPIKE-DEPENDENT**

- **Decision**: all tests run through iris-agentic-dev on the contest instance (IRIS AI Hub EAP build 154), as the Constitution (1.2.0, Workflow) and FR-014 require.
- **Spike dependency**: a build 154 container must be up and reachable by iris-agentic-dev (Atelier REST on the community image's private web server, port 52773).
- **Fallback**: while build 154 is not up, run the Core and Application tests on the current dev container (`IRIS 2026.2 Build 221U`, checked on 2026-10-22) — the Core does not depend on AI Hub, which is why AD-28 already plans its `%UnitTest`s on a public IRIS image. Those runs are **provisional**: a task is done only after the same suite passes on build 154 (see Complexity Tracking in the plan).
- **Alternatives considered**: waiting for build 154 before writing any test (wastes the days the 1.2.0 amendment opened); running only in CI (CI cannot load the EAP image, AD-28).

## R3 — How the parity test reads the normative table — **SPIKE-DEPENDENT**

- **Decision**: a dev tool `contracts/tools/export_state_machine_json.py` (Python, like the other contract tools) converts `contracts/case-state-machine.yaml` into `tests/fixtures/case-state-machine.json`. The parity `%UnitTest` reads that file with `%DynamicAbstractObject.%FromJSONFile()`. The CI step of specs/001 also checks the JSON is up to date (`git diff --exit-code`), the same way the fixtures are checked.
- **Spike dependency**: specs/001 research R4 — `%UnitTest` must be able to read a file from the tests directory inside the build 154 container (the submission compose does not mount the repository, AD-27).
- **Fallback**: the export tool also writes a generated test class `SignalNoir.Tests.Core.TableFixture` with the JSON in an `XData` block; the parity test reads the `XData` instead of a file. No file access in the container is needed. The Core itself never reads either one (FR-012).
- **Alternatives considered**: reading the YAML in ObjectScript (no YAML parser in IRIS); hand-copying the table into the test (defeats the parity test).

## R4 — How the Core holds the table

- **Decision**: the Core keeps the declarative part of each row — Id, from, to, actors, events, follow-up work, chained rows — as data in an `XData` JSON block of `SignalNoir.Core.TransitionTable`, and each precondition `check` of the table's closed vocabulary (specs/001 data-model) as a named class method of `SignalNoir.Core.Preconditions`. `Decide` selects the candidate rows for (state, requested target), filters by actor, evaluates the checks, and returns a value.
- **Rationale**: the row data stays reviewable next to the YAML, and the checks stay real code with unit tests. `XData` is class metadata compiled with the class: reading it is not I/O, and no code is built from input (Principle II). The parity test (R3) catches any drift between the `XData` and the YAML.
- **Alternatives considered**: one method per transition (29 near-duplicate methods, harder to compare with the table); generating the class from the YAML at build time (one more build step; the generated diff is hard to review — specs/001 R4).

## R5 — Results as values

- **Decision**: `Decide` returns a `SignalNoir.Core.Decision` object with `Kind` ∈ {`Accepted`, `Refused`, `Attach`} and the fields of [contracts/core-port.md](contracts/core-port.md). The Application command path returns a `SignalNoir.Application.CommandResult` value to every caller. Neither throws for a predictable outcome; `%Status` errors stay at the persistence edge and become a `Failed` result (Principle VII).
- **Alternatives considered**: throwing exceptions for refusals (control flow by exception, forbidden by Principle VII); returning `%Status` from the Core (mixes infrastructure errors with domain refusals).

## R6 — Atomic recording and optimistic concurrency

- **Decision**: the command path runs one short transaction per command (`TSTART`/`TCOMMIT`), with no external I/O inside: read the Case, call `Decide`, then for `Accepted` update the Case with a compare-and-swap (`UPDATE … WHERE ID = ? AND CaseVersion = ? AND State = ?`, plus the target id) and insert the Timeline events (`seq` by `$INCREMENT` on a per-Case global) and the outbox entries; zero rows updated means another writer won → `STALE_VERSION`. For `Refused`, insert only `CommandDiscarded`. For `Attach`, insert the event without touching `CaseVersion`.
- **Rationale**: AD-2, AD-3 and AD-20 as adopted; no locks; the transaction never waits on the network.
- **Alternatives considered**: `LOCK` on the Case (pessimistic, rejected by AD-3); writing the outbox after commit (loses work on a crash, rejected by AD-20).

## R7 — One non-terminal Case per Order

- **Decision**: the persistent Case has a computed, stored property `OpenOrderKey` = `orderId` while the state is non-terminal and `"closed:" _ caseId` once terminal, with a unique index on it. Opening a Case (T01, T02) inserts under that index; a concurrent second first-Exception fails the insert and is retried as an attachment to the winner.
- **Rationale**: AD-25 asks for a unique index guaranteeing at most one non-terminal Case per `orderId`; a computed key makes it a plain unique index.
- **Alternatives considered**: a check-then-insert in code (races under concurrency); a separate "open cases" table (two writes to keep in step).

## R8 — Clock and time

- **Decision**: the Application reads the clock once per command (`$ZTIMESTAMP`, converted to ISO-8601 UTC) and passes it to `Decide` as `now`; the Core never reads a clock (FR-001).
- **Alternatives considered**: `$ZTIMESTAMP` inside the Core (makes expiration tests time-dependent and breaks purity).

## R9 — Concurrency tests

- **Decision**: concurrency scenarios start N background processes with `JOB` against the same Case, wait on a global barrier, and assert that exactly one write wins and every loser left its refusal; each scenario repeats 100 times (SC-004).
- **Alternatives considered**: simulating interleavings in one process (does not exercise the CAS for real).

## R10 — Packaging and loading — **SPIKE-DEPENDENT**

- **Decision**: classes under `src/SignalNoir/` (packages `Core`, `Application`) and tests under `tests/SignalNoir/Tests/` (convention `SignalNoir.Tests.<Package>`), loaded and compiled through iris-agentic-dev (`compile`, `doc`), and declared in `module.xml` for IPM.
- **Spike dependency**: IPM is not preinstalled in build 154 (stack research §1.7); AD-27 installs it at build time. Whether that works on build 154 is part of B04/B02.
- **Fallback**: during development, load and compile only through iris-agentic-dev; `module.xml` changes wait for B04's bootstrap. This feature does not touch the Dockerfile or the compose files.
- **Dependency**: `module.xml` today still names the template (`dc-sample`); renaming the module belongs to B04, not here.

## R11 — Overlap with B04's persisted Case

- **Decision**: this feature reuses the persistent Case, Timeline and outbox classes that B04 creates for the first persisted Case, adding only the fields the table needs (`CaseVersion`, `DenialCount`, `StepLeaseUntil`, `PreviousEpisodeCaseId`, `OpenOrderKey`, `PendingReassessmentExceptions`). If B04 has not created them when this feature starts, this feature creates them under `SignalNoir.Application.Store` and B04 adopts them.
- **Rationale**: Principle IX (extend the tracer slice, do not build a parallel layer) and AD-2 (one mutation path).
- **Coordination**: José owns both B04 and B06; the first task of this feature checks what exists.
