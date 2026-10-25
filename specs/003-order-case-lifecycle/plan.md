# Implementation Plan: Order Intake and Case Lifecycle

**Branch**: `003-order-case-lifecycle` | **Date**: 2026-10-25 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `specs/003-order-case-lifecycle/spec.md`

## Summary

Turn the 001 walking skeleton into the real Order/Case lifecycle. Intake checks the Origin's
synthetic Order shape in the core, refuses malformed Orders with a recorded reason, and stores an
immutable, correlated Order with a canonical equivalence key computed in the core. A Case opens on
the first Exception (not on acceptance), at most one non-terminal Case exists per orderId (unique
index), later Exceptions join it, and a post-terminal Exception opens a related Case. The core
`CaseMachine` holds the full transition → actor → follow-up table. `CaseService` commits state,
Timeline event and outbox entry in one short transaction under a per-Case lock, with an explicit
`caseVersion` compare-and-swap, and serves contract-shaped list (opaque cursor, both directions,
filters), detail and incremental Timeline projections whose visibility watermark guarantees no
reader ever skips a late-confirmed event. The seam changes this needs are recorded as contract
change 003 and published as `docs/seams.md` v3.

## Technical Context

**Language/Version**: ObjectScript. Target platform per Constitution is IRIS AI Hub EAP build 154;
the running dev container `congenial-waffle-iris-1` reports `IRIS for UNIX (Ubuntu Server LTS for
ARM64 Containers) 2026.2 (Build 221U)` (see research R0). Nothing in this feature uses `%AI.*`.

**Primary Dependencies**: IRIS `%Persistent`, `%DynamicObject`, `%SQL.Statement`, `%CSP.REST`,
`%UnitTest`. No new library.

**Storage**: `%Persistent` classes in `SignalNoir.Application.Model` (namespace `IRISAPP`). New:
`ExceptionRecord`, `IntakeRefusalRecord`. Extended: `OrderRecord`, `CaseRecord`, `OutboxRecord`.

**Testing**: `%UnitTest` (`SignalNoir.Tests.*`) on the live instance through iris-agentic-dev;
concurrency tests use `JOB` workers; a Python conformance check validates live API responses
against `contracts/openapi-signalnoir.yaml` (same validator approach as
`contracts/tools/validate_fixtures.py`).

**Target Platform**: single IRIS container, `/signalnoir/api/v1`.

**Project Type**: single IRIS/IPM project (backend + REST + Production).

**Performance Goals**: transitions and appends are short transactions with no I/O; list/detail/
timeline answer from indexes (no full scans beyond the page). Polling at 1–2 s (AD-17) is the load
profile.

**Constraints**: Calendar gate — no submission code before 2026-10-26 (implementation of this plan
starts on that date). Integration files (`module.xml`, compose, workflows, README) are not edited.
Frozen inputs are not edited; seam changes go through contract change 003.

**Scale/Scope**: tens to hundreds of synthetic Cases per Benchmark run; one Production.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- [x] **I. Pure Core** — Order shape check (`Core.OrderShape`), equivalence key (`Core.Canon`),
  transition/actor/follow-up table and Exception routing (`Core.CaseMachine`), rejection rule and
  cursor codec (`Core.Cursor`) are pure classes in `SignalNoir.Core`; `Application`, `Api` and
  `Interop` call them. Nothing references the Simulator.
- [x] **II. Closed Action Catalog / Read-Only Agent** — no Action added; Order text is stored as
  data and never interpreted; no runtime code execution.
- [x] **III. One Validator** — not exercised; transitions that depend on a verdict are only
  allowed to the `system` actor that will call the single Validator (004).
- [x] **IV. Human Authority** — `PendingApproval → Approved/Rejected` only for `operator:<name>` and
  `benchmark`; expiry only for `sweeper`, returns to `PendingApproval`, and clears the current
  Approval reference so it cannot authorize.
- [x] **V. Case as Source of Truth** — every write through `CaseService`; state + event + outbox in
  one `TSTART/TCOMMIT` with no I/O; CAS on `caseVersion` + expected state + expected target;
  append-only Timeline; terminal never reopens; related Case on a new episode.
- [x] **VI. Effects at Most Once** — no effect here; follow-up work is written once with the
  transition and carries `caseVersionAfter` for the consumer to re-check (AD-4).
- [x] **VII. Honest Outcomes** — every refusal is a `Result` with a closed code and `details`;
  intake refusals are recorded; HTTP maps them to 400/404/409, never 200.
- [x] **VIII. Honest Measurement** — N/A (Benchmark not touched; `runId` only carried through).
- [x] **IX. Verifiable Increments** — tasks sliced by the six user stories, each with its failing
  test first; dependencies explicit in tasks.md.
- [x] **Platform Constraints** — synthetic data only (intake refuses `synthetic != true`), no
  secret in Timeline or logs, no image published. Build caveat recorded in R0.
- [x] **iris-agentic-dev** — the platform behaviors this plan relies on (unique index with empty
  values, `#5800` on version mismatch, lock release deferred to `TCOMMIT`) were verified live
  (research "Verification log"); tests run through it; runtime does not depend on it.

### Post-design re-check (after Phase 1)

All gates still pass. The seam changes (AcceptOrder returns an Order reference, new
`RecordException`, CAS expectations on `Transition`, `Result.details`, new id prefixes, closed
Timeline event types) are explicit in `contracts/contract-change-003-case-lifecycle-seam.md`; no
frozen HTTP contract changes.

## Project Structure

### Documentation (this feature)

```text
specs/003-order-case-lifecycle/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   └── contract-change-003-case-lifecycle-seam.md
├── checklists/requirements.md
└── tasks.md            # /speckit-tasks
```

### Source Code (repository root)

```text
src/SignalNoir/
├── Core/
│   ├── Vocab.cls            # + actors rules/replay, EXCEPTIONKINDS, EVENTTYPES, prefixes corr_/exc_
│   ├── CaseMachine.cls      # full transition table, actors, follow-up, Exception routing, rejection rule
│   ├── OrderShape.cls       # NEW: structural check of the Origin Order -> ordered reasons
│   ├── Canon.cls            # + FromSnapshot, UTC offset normalization, key -> parts
│   ├── Cursor.cls           # NEW: opaque (lastEventAt, caseId) codec
│   ├── Result.cls           # + details
│   ├── Dto/CaseException.cls  # NEW
│   ├── Dto/Order.cls        # + correlationId, transactionId(s), partnerId, runId
│   ├── Dto/Case.cls         # + denialCount, previousCaseId, currentProposalId, ... (additive)
│   └── Port/CaseCommands.cls  # + RecordException; Transition expectations (contract change 003)
├── Application/
│   ├── CaseService.cls      # intake, RecordException, CAS transitions, projections, recovery
│   ├── SystemClock.cls      # UTC with milliseconds ($ZTIMESTAMP)
│   └── Model/
│       ├── OrderRecord.cls       # + correlationId, transactionIds, partnerId, runId
│       ├── CaseRecord.cls        # + caseVersion, openOrderId (unique), denialCount, previousCaseId, ...
│       ├── ExceptionRecord.cls   # NEW
│       ├── IntakeRefusalRecord.cls # NEW
│       ├── CaseEventRecord.cls   # unchanged shape
│       └── OutboxRecord.cls      # + payloadJson, dispatchedAt
├── Api/Dispatch.cls         # list (cursor/direction/filters), detail, timeline; 400/404 envelopes
└── Interop/
    ├── Service/OrderIn.cls  # Accept(json, transactionId, runId), ReportException(...)
    └── Bootstrap.cls        # + RecoverInterrupted on start
tests/SignalNoir/Tests/
├── Core/        TestOrderShape, TestCanon, TestCaseMachine (table), TestCursor
├── Application/ TestIntake, TestExceptionRouting, TestTransitions, TestConcurrency,
│                TestRestart003, TestRejectionExpiry, TestProjections
├── Api/         TestCasesRead (extended), TestTimelineRead
└── Fakes/       FakeCaseCommands/FakeCaseQueries updated to the v3 seam
tests/contract/validate_live.py   # live responses vs openapi-signalnoir.yaml (dev tool)
docs/seams.md                     # v3 (contract change 003)
```

**Structure Decision**: same single IRIS/IPM layout as 001; this feature only adds classes inside
the existing packages and one dev-only conformance script under `tests/`.

## Complexity Tracking

| Deviation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|--------------------------------------|
| Seam change (contract change 003) | The spec opens the Case on the first Exception, not on acceptance; the 001 seam's `AcceptOrder → CaseRef` cannot express that, and the CAS needs expected state/target | Keeping `AcceptOrder` opening a Case contradicts FR-010; a parallel private API would bypass the published seam |
| Short per-Case `LOCK` inside the transition transaction | Makes the CAS check-and-write atomic and serializes `seq` assignment so commits are in `seq` order (no gaps for readers, FR-031) | `$INCREMENT` alone leaves gaps on rollback and lets seq N+1 commit before N; relying only on `VERSIONPROPERTY` cannot cover attachments, which must not bump `caseVersion` |
| `caseVersion` kept separate from the `VERSIONPROPERTY` row version | Attachments must update `lastEventSeq` on the Case row without changing `caseVersion` (FR-021) | Using the row version as `caseVersion` would bump it on every attachment |
