# Implementation Plan: Safe Execution and Recovery

**Branch**: `008-execution-and-recovery` | **Date**: 2026-10-28 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `specs/008-execution-and-recovery/spec.md`

## Summary

`Application.ExecutionService` is the one execution path (AD-5). It does the I/O: Partner health,
Origin status, Receipts and delivery, all through `Core.Port.PartnerClient`, whose adapter
`Interop.PartnerHttp` speaks the Simulator's HTTP contract. Every write goes through `CaseService`,
one short transaction each, under the Case lock (Constitution V):

| Method | What it writes |
|---|---|
| `AuthorizeExecution` | The CAS that records the Execution, the revalidation and the consumed approval, and moves the Case to `Executing`, `Held` or `Cancelled`. |
| `StartAttempt` | The attempt, before the send. Renews the lease. |
| `FinishAttempt` | The answer and its class. Then: a Receipt and `Resolved`; `Failed`; a retry; or "reconciling" with a `Reconcile` request. |
| `TakeOverExecution` | The next lease generation, for reconciliation. |
| `RecordReconciliation` | The reconciliation. A Receipt found means `Resolved`. |
| `RequestReconcile` | A `Reconcile` request from the sweeper. |
| `ReassessHeld` | `Held → Investigating` by the sweeper. |

Pure rules live in the Core:
- `Core.ResponseClass` classifies `{answered, status, body}`, per the table of `openapi-sim.yaml`
  and AD-13.1.
- `Core.EffectKey` derives the effect key `H(orderId, partnerId, canonical payload)`, which
  resolves API-Q11 without renaming fields.
- `Core.ExecutionPolicy` is the default behind `Core.Port.ExecutionPolicy`. It holds the
  revalidation rule, the attempt budget, the minimum hold, the current versions and the effect
  payload. 004 replaces it.

Revalidation runs in `Approved`, before the authorization CAS, because the frozen 003 table puts
`Approved → Held` and `Approved → Cancelled` on revalidation and labels `Approved → Executing`
"revalidation passed" (research R1). `CommandBus` routes `Execute` and `Reconcile` to the service.
`Tasks.Sweeper` gains two passes:
- the lease pass (AD-22): `Executing` past its lease gets `Reconcile`; `Investigating` past its
  lease goes to `ReviewRequired`;
- the `Held` reassessment (AD-7, AD-8).

The Case detail shows executions and the Receipt copy.

## Technical Context

**Language/Version**: ObjectScript on IRIS 2026.3 AI Hub build 154 (`dev/aihub`).

**Primary Dependencies**:
- `CaseService`, `CommandBus`, `Tasks.Sweeper`, `ApprovalRecord` and `OutboxRecord` (003, 007, 009);
- the Simulator over HTTP (002), through `SimulatorSource.Base()`.

**Storage**:
- new `Application.Model.ExecutionRecord`, with attempts and reconciliations as JSON arrays (they
  are only ever read with their Execution);
- new `Application.Model.ReceiptCopyRecord`, a separate linked record (Constitution V);
- existing `CaseRecord.currentExecutionId` and `executionOutcome`.

**Testing**:
- `%UnitTest` via iris-agentic-dev, TDD.
- `Tests.Fakes.ScriptedPartner` for deterministic answers: lost response, late worker, transient
  and business errors.
- A live recovery suite against the Simulator (`idempotency.*`, `P3.*`, `clean`), with short
  client timeouts and `timeScale` 0.01.
- `FixedClock` for leases and holds.
- `tests/contract/validate_live.py` for Case detail and summaries with executions.

**Target Platform / Project Type**: single IRIS project.

**Performance Goals**:
- The partner timeout comes from `SN_PARTNER_TIMEOUT_SECONDS` (default 60), and the lease from
  `SN_AI_LEASE_SECONDS` (default 300 s, kept above the timeout + the budget by the bootstrap).
- No transaction is open during I/O.

**Constraints**:
- No contract change and no edit to the integration files.
- 004's files are untouched; its seams are ports.
- `OriginFeed`'s first delivery is unchanged.

**Scale/Scope**: one service, one adapter, two pure core rules, a default policy, two records, two
sweeper passes and one projection.

## Constitution Check

- [x] **I. Pure Core**: classification, effect key, revalidation rule and attempt budget are pure
  core classes. The Simulator is reached only over HTTP, through a port adapter in `Interop`.
- [x] **II. Closed Catalog**: no new Action. `APPLY_APPROVED_MAPPING` applies only what the policy
  port produces, and the default produces nothing until 004.
- [x] **III. One Validator**: untouched. Revalidation is the precondition re-check of AD-26, not a
  second Validator.
- [x] **IV. Human Authority**: `APPROVAL_VALID` is checked before authorizing, and an approval is
  `consumed` at authorization. Leaving `Held` goes back to `Investigating`, and a new Proposal
  supersedes everything.
- [x] **V. Case as Source of Truth**: every write is a `CaseService` command under the Case lock,
  with no I/O inside. The CAS is on the Case version and the Execution generation, and a late
  writer loses visibly (`CommandDiscarded`).
- [x] **VI. Effects at Most Once**: the request id, the execution id and the effect key are
  separate, and the effect key does not depend on the Proposal. The authorization is persisted
  before the send, and so is each attempt. Uncertain blocks: a reconciliation comes before any
  further send, and another execution of the Order waits. Leases carry a generation.
- [x] **VII. Honest Outcomes**: classes as values. A refusal fails, and is never shown as success.
  An unreadable check counts as not satisfied. "Reconciling" is reported, never shown as done.
- [x] **VIII. Honest Measurement**: P3 and recovery are platform guarantees, labelled as such in
  the recovery suite. Nothing is attributed to the Agent.
- [x] **IX. Verifiable Increments**: seven stories, tests first. US1 closes the tracer path's
  effect step.
- [x] **Platform Constraints**: synthetic data, no secrets; the Partner key is never logged
  because there is none.
- [x] **iris-agentic-dev**: compile and tests run on the live instance (research R10).

## Project Structure

```text
specs/008-execution-and-recovery/  spec.md plan.md research.md data-model.md quickstart.md tasks.md
                                   contracts/coordination.md  checklists/requirements.md
src/SignalNoir/Core/ResponseClass.cls          # classifier of Partner answers (pure)
src/SignalNoir/Core/EffectKey.cls              # effect key + canonical JSON (pure)
src/SignalNoir/Core/Port/ExecutionPolicy.cls   # revalidation, budget, hold, versions, payload (004 replaces)
src/SignalNoir/Core/ExecutionPolicy.cls        # default rules
src/SignalNoir/Core/Port/PartnerClient.cls     # + Deliver, SearchReceipts, Health, OriginStatus
src/SignalNoir/Interop/SimulatorHttp.cls       # shared HTTP call (OriginFeed delegates to it)
src/SignalNoir/Interop/PartnerHttp.cls         # PartnerClient adapter over the Simulator
src/SignalNoir/Application/ExecutionService.cls
src/SignalNoir/Application/Model/ExecutionRecord.cls  Model/ReceiptCopyRecord.cls
src/SignalNoir/Application/CaseService.cls     # execution commands, projections
src/SignalNoir/Application/CommandBus.cls      # Execute, Reconcile routes; Executions switch
src/SignalNoir/Tasks/Sweeper.cls               # lease pass, Held reassessment
src/SignalNoir/Api/Dispatch.cls                # executions and receipt in the Case detail
tests/SignalNoir/Tests/Core/  TestResponseClass  TestEffectKey  TestExecutionPolicy
tests/SignalNoir/Tests/Application/  TestExecution  TestRevalidation  TestReconciliation
                                     TestLease  TestHeld  TestExecutionFailure
tests/SignalNoir/Tests/Recovery/TestRecoverySuite.cls   # live, against the Simulator
tests/SignalNoir/Tests/Fakes/ScriptedPartner.cls
```

## Complexity Tracking

| Deviation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|--------------------------------------|
| Revalidation before the authorization CAS, not after (AD-5 lists CAS first) | The frozen 003 table has `Approved → Held/Cancelled` for revalidation and no `Executing → Cancelled` | Adding `Executing → Cancelled` changes a frozen table and the contract's state rules |
| Default execution policy before 004 | 008 starts before 004 merges (`PARALELISMO.md` allows fakes) | Waiting for 004 blocks G3 |
| `APPLY_APPROVED_MAPPING` held as "mapping unavailable" until 004 | The transformed payload needs 004's catalog | Sending the snapshot would send the wrong effect |
| Sweeper switch `"none"` also leaves `Execute`/`Reconcile` pending | 007's tests drive Cases to `Approved` and run the sweep; they must not reach a Partner | A second switch on every call site |
