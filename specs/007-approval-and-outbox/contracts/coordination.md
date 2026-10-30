# Coordination: 007 with 003, 004, 006, 008, 009 and 010

No change to `contracts/openapi-signalnoir.yaml`, the fixtures or the seam.

## 004 (Validator and reference data, Henrique)

- `Core.Port.ApprovalPolicy` (`DeadlineSeconds()`, `Admit(actor, runId)`) is the seam for 004's
  `Admit(actor, run)` and `policies.approval.deadlineSeconds`. 007 ships the default
  (`Core.ApprovalPolicy`: 900 s; `benchmark` iff `runId`). 004 replaces `CaseService.Default()`'s
  policy instance; callers do not change.

## 008 (Execution, Henrique)

- `Execute` requests are queued by `PendingApproval → Approved` (and by 009's resolution).
  `Application.CommandBus.Deliver` routes them, and `Reconcile`, to `ExecutionService` (008, done
  2026-10-28); the `"none"` switch still leaves them pending for tests.
- The approval that authorizes the execution is `Case.currentApprovalId`; 008 sets it `consumed`
  when it authorizes, and checks `APPROVAL_VALID` (status `valid`, `expiresAt` in the future) at
  revalidation. An approval expired while `Executing` is 008's to refuse ("o Execution BO recusa e
  emite `Expire`", AD-24).
- The sweeper's lease pass (AD-22) is 008's; add it to `Tasks.Sweeper`.

## 003 / 006 / 009 (Henry)

- `PendingApproval → Rejected` now queues `Reassess`; `ResolveRejection` is called by the entry
  point.
- `Approved`/`Rejected` from `PendingApproval` require a recorded decision; 009's resolution writes
  its Approval before the transition.

## 010 (Benchmark)

- Automatic approval reads the Case's `runId` (003). When 010 adds the BenchmarkRun store, its
  `Admit` replaces the default's "has a `runId`" rule.

## 001 (Bootstrap) and the integration gate

- `Tasks.SweeperTask.Ensure()` is ready; the one call in `Bootstrap.OnStart` is applied at the gate
  on a clean install (research R6: test requests in the dev database would run as real
  investigations).
- Wiring every transition owner to deliver after commit is the gate's Production command service
  (AD-6); today the decision API and the sweeper deliver.
