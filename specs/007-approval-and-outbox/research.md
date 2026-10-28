# Phase 0 Research: Approval and the Transactional Outbox

**Date**: 2026-10-28

## Calendar-gate exception and ownership

Henry asked for the full cycle of 007, including implementation, on 2026-10-28, as for 003, 005,
006, 009 and 009b. 007 moved from Henrique to Henry on the same day to rebalance the waves.
Recorded for the G2 review.

## R1 — The decision command

**Decision**: `CaseService.DecideProposal(caseId, proposalId, request)`. Order of checks, after the
pure shape check and under the Case lock:

1. **Replay**: an `approved` Approval for `proposalId` with status `valid` or `consumed` → `200`
   with it and `idempotentReplay: true`, whatever the version (contract: "mesmo que
   `expectedCaseVersion` esteja vencida e mesmo que o Caso já tenha avançado").
2. **State**: the Case must be `PendingApproval` → else `409 INVALID_TRANSITION`.
3. **Current Proposal**: `proposalId` must be `currentProposalId` → else `409 STALE_VERSION` with
   `details.currentProposalId` (fixture `decision.409.stale-version.json`).
4. **Version**: `expectedCaseVersion` = `caseVersion` → else `409 STALE_VERSION`.

State before version gives the fixture's `INVALID_TRANSITION` for a Case that left
`PendingApproval` (its version also moved). Concurrent approvals serialize on the Case lock; the
loser reaches step 1 and gets the replay (FR-005).

**Alternatives**: version first (as `ResolveReview`) — would answer `STALE_VERSION` where the
contract's fixture shows `INVALID_TRANSITION`.

## R2 — No `Approved` without a recorded decision

**Decision**: `ApplyTransition` refuses `PendingApproval → Approved|Rejected` unless the payload
names `approvalId` of an `ApprovalRecord` for the Case's current Proposal whose decision matches the
target (and, for `Approved`, status `valid`). Every path that approves (decision, 009's resolution,
benchmark auto-approval) writes the record first, in the same transaction. Test helpers
(`Support.DriveTo`, manual walks) go through `DecideProposal` with a fixture Proposal.

**Rationale**: SC-001 becomes structural instead of a convention.

## R3 — Denial follow-up

**Decision**: `PendingApproval → Rejected` gains the follow-up `Reassess` (Core command enum, AD-6)
with the payload `{rejectionReason}`; the denial records `operator.denial_reason` Evidence (contract
`Evidence.source`). `CommandBus` handles `Reassess` on a `Rejected` Case by calling 003's
`ResolveRejection` (first → `Investigating` + `Investigate`; second → `ReviewRequired`). AD-24
fixes `Rejected → Investigating` as "the BP, by command"; the fixture `decision.201.denied.json`
carries a `commandId`.

**Alternatives**: no follow-up and a synchronous `ResolveRejection` in the decision (two
transitions in one request, no `commandId`, contradicts the fixture); type `Investigate` for the
denial (the investigation entry would have to start from `Rejected`).

## R4 — Approval policy port

**Decision**: `Core.Port.ApprovalPolicy` with `DeadlineSeconds()` and `Admit(actor, runId)`.
Default `Core.ApprovalPolicy`: 900 s (the same 15 min 009 used) and `benchmark` admitted iff the Case
has a `runId`. 004 owns `Admit` and `policies.approval.deadlineSeconds`
(`coordination-004-006-009.md`) and replaces the default without touching callers.

## R5 — Single entry point

**Decision**: `Application.CommandBus.Deliver(commandId)`:

- claims the request under `Lock +^SignalNoir.CommandLock(commandId)`; a request not `pending` is
  left alone (`already <status>`), so two deliveries process it once;
- loads the Case; `caseVersion ≠ caseVersionAfter` → status `discarded` + `CommandDiscarded`;
- `Investigate` → `InvestigationService.Run` (which claims it itself, 006);
- `Reassess` → `ResolveRejection`, then `done`;
- `Execute`, `Reconcile`, `Expire`, `Resume` → no handler yet: unchanged, result `waiting`.

The decision API delivers its request after the commit in a background job; the sweeper redelivers.
Other transition owners keep their current behavior (006 runs its own `Investigate`); wiring every
owner is the gate's integration of the Production command service (AD-6).

## R6 — Sweeper

**Decision**: `Tasks.Sweeper.Run(now)`, two passes (AD-8): (1) redeliver `pending` requests older
than 30 s; (2) for each `valid` approved Approval past `expiresAt` whose Case is `Approved` with it
as `currentApprovalId`: Approval `expired`, `ApprovalExpired`, `Approved → PendingApproval` by
`sweeper`. An expired Approval on a Case already `Executing` is left to 008's revalidation.
The lease pass (AD-22) is 008's. `Tasks.SweeperTask` (`%SYS.Task.Definition`) runs it every minute
(`Ensure()`, `Count()`, `Remove()`). `%SYS.Task.Definition` and `%SYS.Task` are present on build
154 (iris-agentic-dev check, 2026-10-28); `TestApprovalExpiry.TestTaskEnsuredOnce` registers and
removes the task.

**Not wired into `Bootstrap` in this feature.** The dev database holds 3,163 pending `Investigate`
requests left by test runs, 2,816 of them still at their Case's version. A scheduled redelivery
would start them as real investigations against the configured provider. The sweep is bounded
(`MAXPERRUN = 50`, oldest first) and takes a Case scope for tests; the one-line
`Tasks.SweeperTask.Ensure()` call in `Bootstrap.OnStart` is applied at the integration gate, on a
clean install (or after the test requests are cleared).

## R7 — Benchmark approval

**Decision**: in `RouteProposal`, when the verdict requires approval and
`policy.Admit("benchmark", rec.runId)`, record an Approval by `benchmark` and move
`PendingApproval → Approved` in the same commit. `ApplyTransition` refuses actor `benchmark` when
`Admit` refuses it. The decision API builds `operator:<name>` only, and `OperatorName` cannot hold a
colon, so `benchmark` cannot enter there.

## R8 — Supersede

**Decision**: when a Proposal replaces the current one (`CompleteInvestigation`, `ResolveReview`),
its `valid` Approvals become `superseded` in the same commit.

## R9 — Results (2026-10-28, IRIS 2026.3 AI Hub build 154, provider key configured)

| Check | Before (T001) | After (T022) |
|---|---|---|
| ObjectScript suite | 146/146 | 174/174 |
| Console (`npm test`, `npm run check`) | 46/46 | 46/46; 0 errors |
| Contract fixtures | 25/25 | 25/25 |
| Live contract (`validate_live.py`) | all conform | all conform, including decision 400/409/404/201/200, after the one-off repair below (206 fixture Proposals written earlier in this session without `confidence`/`versions`; `Support.FixtureProposal` now writes them complete) |

Deviations recorded honestly:

- TDD order: `DecideProposal`, the guard, the benchmark approval and the sweep were written before
  `TestDecision` and `TestBenchmarkApproval`; those tests passed on first run. `TestDecisionShape`,
  `TestApprovalPolicy`, `TestCommandBus`, `TestApprovalExpiry` and `TestDecisionApi` failed first.
- `ApprovalJson` now reloads the record: a process holding the object saw a stale status (found by
  `TestNewProposalSupersedesApproval`).
- The guard (FR-007) changed the test helpers: `Support.DriveTo` and `Support.Step` reach
  `Approved`/`Rejected` through `DecideProposal` on a fixture Proposal.

One-off repair of the dev database (iris-agentic-dev refuses `UPDATE`; run by Henry in the IRIS session on 2026-10-28, 206 rows):

```sql
UPDATE SignalNoir_Application_Model.ProposalRecord SET confidence = 'LOW', preconditionsJson = '[]', metricsJson = '{"toolCalls":0}', versionsJson = '{"policy":"fixture","mapping":"fixture","prompt":null,"model":null,"provider":null}' WHERE diagnosisJson = '{"summary":"fixture","claims":[],"hypotheses":[]}' AND (confidence IS NULL OR confidence = '')
```
