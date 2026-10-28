# Implementation Plan: Approval and the Transactional Outbox

**Branch**: `007-approval-and-outbox` | **Date**: 2026-10-28 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `specs/007-approval-and-outbox/spec.md`

## Summary

`CaseService.DecideProposal(caseId, proposalId, request)` is the one decision command: a pure shape
check (`Core.DecisionShape`), then, under the Case lock, replay → state → current Proposal →
version, then the Approval (`ApprovalRecord`, 009's) and the transition in one commit. Approve
writes `ApprovalRecorded` and `PendingApproval → Approved` with its `Execute` request; deny writes
the denial, `operator.denial_reason` Evidence and `PendingApproval → Rejected` with a `Reassess`
request. `ApplyTransition` refuses `Approved`/`Rejected` from `PendingApproval` unless the event
names a recorded decision for the current Proposal, and refuses the actor `benchmark` on a Case
without `runId`. The approval deadline and benchmark admission come from a port
(`Core.Port.ApprovalPolicy`, default `Core.ApprovalPolicy`: 15 min, `benchmark` iff `runId`) that
004 replaces. `RouteProposal` approves automatically as `benchmark` inside a run.

`Application.CommandBus.Deliver(commandId)` is the single entry point: it claims a pending request
under a per-command lock, discards it (with `CommandDiscarded`) when the Case version differs, routes
`Investigate` to `InvestigationService` and `Reassess` to `ResolveRejection`, and leaves types
without a handler (008/010) pending. `Tasks.Sweeper.Run()` redelivers pending requests older than a
grace period and expires approvals past their deadline (`Approved → PendingApproval` by `sweeper`,
`ApprovalExpired`); `Tasks.SweeperTask` schedules it every minute through `%SYS.Task`
(`Ensure()`; the bootstrap call waits for the integration gate, research R6). The API adds
`POST /cases/{caseId}/proposals/{proposalId}/decision`, which delivers its request after the commit
in a background job.

## Technical Context

**Language/Version**: ObjectScript on IRIS 2026.3 AI Hub build 154 (`dev/aihub`).

**Primary Dependencies**: `CaseService`, `Core.CaseMachine`, `ApprovalRecord` (009),
`OutboxRecord` (003), `InvestigationService` (006), `%SYS.Task`.

**Storage**: existing `ApprovalRecord`, `OutboxRecord`, `EvidenceRecord`; no new class. Outbox
status gains `discarded`.

**Testing**: `%UnitTest` via iris-agentic-dev (TDD); `FixedClock` for deadlines; JOB races for
concurrency; `BrokenCmdIds` for the injected storage failure; `tests/contract/validate_live.py`
extended to the decision operation; console tests unchanged (built against the fixtures).

**Target Platform / Project Type**: single IRIS project.

**Performance Goals**: decision commit in one short transaction under the Case lock; delivery after
commit, never inside it.

**Constraints**: no contract change; no edit to the integration files; 004's policy files untouched.

**Scale/Scope**: one command, one entry point, one sweep, one API route.

## Constitution Check

- [x] **I. Pure Core** — decision shape, deadline arithmetic and admission are pure core
  (`DecisionShape`, `ApprovalPolicy`); the Application gathers rows and persists.
- [x] **II. Closed Catalog** — no Action added; command types stay the Core enum.
- [x] **III. One Validator** — untouched; benchmark approval happens only after the same verdict.
- [x] **IV. Human Authority** — `Approved` needs a recorded decision for the current Proposal
  (guard in `ApplyTransition`); deadline; only the sweeper expires; automatic approval only inside a
  BenchmarkRun.
- [x] **V. Case as Source of Truth** — approval, state, event, Evidence and request in one commit
  under the Case lock; CAS on version, state and current Proposal.
- [x] **VI. Effects at Most Once** — a request is claimed once under a lock and checked against
  `caseVersionAfter`; replays queue nothing; 008 sets `consumed`.
- [x] **VII. Honest Outcomes** — conflicts and refusals as values with the closed codes; a request
  without handler is reported as waiting, never as done.
- [x] **VIII. Honest Measurement** — automatic approval labelled `benchmark`; refused outside a run.
- [x] **IX. Verifiable Increments** — five stories, tests first.
- [x] **Platform Constraints** — synthetic data, no secrets.
- [x] **iris-agentic-dev** — `%SYS.Task.Definition` and `%SYS.Task` present on build 154 (research
  R6); the task registration is covered by a test.

## Project Structure

```text
specs/007-approval-and-outbox/  spec.md plan.md research.md data-model.md quickstart.md tasks.md
                                contracts/coordination.md  checklists/requirements.md
src/SignalNoir/Core/DecisionShape.cls             # request shape (pure)
src/SignalNoir/Core/Port/ApprovalPolicy.cls       # deadline + admission (004 replaces the default)
src/SignalNoir/Core/ApprovalPolicy.cls            # default: 15 min, benchmark iff runId
src/SignalNoir/Core/CaseMachine.cls               # PendingApproval>Rejected follow-up Reassess
src/SignalNoir/Application/CaseService.cls        # DecideProposal, guard, benchmark auto-approval,
                                                  # supersede, ExpireApproval, Approval policy property
src/SignalNoir/Application/CommandBus.cls         # single entry point
src/SignalNoir/Tasks/Sweeper.cls  Tasks/SweeperTask.cls
src/SignalNoir/Api/Dispatch.cls                   # POST .../decision
tests/SignalNoir/Tests/Core/  TestDecisionShape  TestApprovalPolicy
tests/SignalNoir/Tests/Application/  TestDecision  TestApprovalExpiry  TestCommandBus  TestBenchmarkApproval
tests/SignalNoir/Tests/Api/  TestDecisionApi
tests/SignalNoir/Tests/Support.cls                # DriveTo goes through the decision
tests/contract/validate_live.py                   # decision operation
```

## Complexity Tracking

| Deviation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|--------------------------------------|
| Guard on `Approved`/`Rejected` changes test helpers (`DriveTo`, manual walks) | SC-001: no `Approved` without a recorded approval, structurally | Leaving the generic transition open keeps a path around the decision |
| Default approval policy before 004 | 007 starts before 004 merges (`PARALELISMO.md` allows the fake) | Waiting for 004 blocks G2 |
| Sweeper task not wired into `Bootstrap` yet | The dev database holds ~2,800 live `Investigate` requests left by tests; a scheduled redelivery would start them as real investigations (research R6) | Wiring it now would spend provider calls on test data; the gate wires it on a clean install |
