# Phase 0 Research: Safe Execution and Recovery

**Date**: 2026-10-28

## Calendar-gate exception and ownership

Henry asked for the full cycle of 008, including implementation, on 2026-10-28, as he did for 003,
005, 006, 007, 009 and 009b. 008 moved from Henrique to Henry on the same day, so that Henrique
can focus on 004. This is recorded for the G3 review.

## R1 — Revalidation runs in `Approved`, before the authorization CAS

**Decision**: The `Execute` handler works in two steps.

1. Outside any transaction, it reads the Partner's health and the Order's status, builds the
   revalidation input and applies the rule.
2. In one commit (`AuthorizeExecution`), under the Case lock and on the Case version the request
   carries:
   - **Passed**: records the Execution (`in_progress`, generation 1, lease) and moves
     `Approved → Executing`.
   - **Order cancelled at the Origin**: records the Execution (`cancelled`, no attempts) and moves
     `Approved → Cancelled`.
   - **Any other failed check**: records the Execution (`held`) and moves `Approved → Held`.
   - **Approval no longer valid**: records only `RevalidationPerformed` and changes no state; the
     sweeper expires the approval (007, AD-24).

   In every case the commit also records `RevalidationPerformed`, marks the approval `consumed`
   (except for an invalid approval) and marks the request `done`.

**Rationale**: The 003 table is frozen and accepted. It labels `Approved → Executing` "revalidation
passed" and puts the blocking outcomes on `Approved → Held` and `Approved → Cancelled`. It has no
`Executing → Cancelled`. Between the check and the send there is one commit and one Receipt query.
That is "immediately before" in the AD-5 sense, and the CAS on the version guarantees that a
concurrent change makes the authorization lose and send nothing. The contract's
`Execution.revalidation.resultingState` and the `held` and `cancelled` outcomes fit an Execution
recorded on a blocking revalidation.

**Alternatives**:
- CAS first, then revalidation (the literal AD-5 order). It needs `Executing → Cancelled`, which
  is a change to the 003 table and to the contract's state rules.

## R2 — Classification of the Partner's answer (`Core.ResponseClass`)

**Decision**: A pure function of `{answered, status, text, json}` and the send's `orderId` and key.

| Answer | Class | Exception kind (on failure) |
|---|---|---|
| no answer / client timeout | uncertain | timeout |
| 200 with `receiptId`, matching `orderId` and `idempotencyKey` | success | — |
| 200 otherwise (free-text rejection, invalid Receipt) | uncertain | invalid_receipt |
| 503, 429 | transient | http_error |
| 504 | uncertain | timeout |
| other 5xx with an empty body | uncertain | http_error |
| other 5xx with a body | business_error | http_error |
| 4xx (400, 404, 409, 422 `IDEMPOTENCY_KEY_REUSED`) | business_error | business_rejection |

**Rationale**:
- This is the table of `openapi-sim.yaml` and AD-13.1.
- P5's "200 with a rejection in free text" can be uncertain or a business error ("decide o Core").
  It is uncertain here, because the prompt lists "200 without a valid receipt" under uncertain, and
  reconciliation is the safe reading.
- 504 is the Simulator's own gateway answer after a hold. It means "no answer in time".
- SIM-Q4 (422) is a business error: the Partner refused the key, and nothing was recorded.

## R3 — Effect key (`Core.EffectKey`), resolving API-Q11

**Decision**:
- The key is `"bek_" + hex(SHA-256(orderId | partnerId | canonical(payload)))[1..32]`.
- `canonical` is JSON with keys sorted at every level, arrays in order, and no whitespace.
- The payload is what is sent: the snapshot for `RETRY`, the mapped Order for
  `APPLY_APPROVED_MAPPING`.
- The contract field keeps the name `idempotencyKey`. Its value is the business effect key.

**Rationale**:
- API-Q11 proposal 1 says the key represents the effect, not the Proposal.
- Two Proposals with the same payload get the same key, and the Partner returns the original
  Receipt.
- A different mapping means a different payload, and so a different key.
- Renaming the field (proposal 2) is a contract change that nothing here needs. It stays open for
  José and Henry.

**Alternatives**:
- AD-21 `H(orderId, action, params, proposalId)`. It depends on the Proposal (R24/ADR-04 forbids
  that). Two Proposals with the same effect would send two keys, protected only by the prior check.

## R4 — The first delivery keeps its key

**Decision**: `OriginFeed`'s first delivery keeps `idk_first_…`. The prior check by `orderId`
finds that delivery's Receipt before any resend (AD-5 step 3). A Receipt found by Order with
another key still settles the effect: the Partner's record prevails (AD-14).

**Rationale**: The first delivery is not an authorized execution. It has no Proposal or payload
mapping, and it runs before a Case exists.

## R5 — Leases, generations and late workers

**Decision**:
- `ExecutionRecord` holds `leaseOwner` (`job:<pid>`), `leaseGeneration` and `stepLeaseUntil`.
- **Lease length**: the AD-22 step lease the bootstrap already reads, `SN_AI_LEASE_SECONDS`
  (default 300 s), which it keeps above the Partner timeout + the investigation budget. It is
  renewed by every `StartAttempt`.
- **Every write carries `(executionId, generation)`**:
  - A lower generation, or a settled outcome, is refused and recorded as `CommandDiscarded`, with
    the reason and the stale generation.
  - When the refused write held a valid Receipt, the same commit queues a `Reconcile` request
    (trigger `lost_cas`, AD-22).
- **Take-over**: `Reconcile` takes over with `generation + 1`.

## R6 — Reconciliation

**Decision**:
- A `Reconcile` request carries `{executionId, trigger}`. It is written in the commit that records
  the uncertain answer, or by the sweeper on an expired lease (`lease_expired`), or by a refused
  late write (`lost_cas`).
- The handler takes over, then queries `GET /receipts?idempotencyKey=` and, when that is empty,
  `?orderId=`. Each query is one `Reconciliation` entry (`queriedBy`, `found`, `receiptId`).
- **Found**: a `ReceiptCopy` with source `reconciliation`, and `Resolved`.
- **Not found**: the outcome goes back to `in_progress`, and the send continues with the same key
  and payload while attempts remain. Otherwise the execution fails.
- **Unreadable**: the outcome stays `reconciling` and nothing is queued. The next expired lease
  makes the sweeper ask again.
- The prior check (AD-5 step 3) is a reconciliation with trigger `prior_check`, queried by
  `orderId`. If it is unreadable, the execution goes to `reconciling` without sending.

## R7 — "Uncertain blocks every new send"

**Decision**:
- `AuthorizeExecution` refuses to authorize while another `ExecutionRecord` of the same `orderId`
  is `reconciling`. It writes nothing, and the request stays pending with status `waiting`, so the
  sweeper delivers it again.
- Within one execution, an uncertain answer always goes through `Reconcile` before the next
  attempt.

**Rationale**: Only one non-terminal Case exists per Order, so a second execution can only come
from a new Case. The explicit check makes FR-013 hold even when that structure changes.

## R8 — Held reassessment and HOLD

**Decision**:
- **HOLD**: the `Execute` request arrives with the Case in `Executing` (`DecisionProposed →
  Executing`, 003). The handler records an Execution with no approval and no attempts (`held`) and
  moves `Executing → Held`, all in one commit.
- **Sweeper pass**: for a `Held` Case whose `updatedAt` is older than the minimum hold (default
  300 s):
  - if the hold came from a version check, it moves the Case at once;
  - otherwise it reads the Partner's health, and when the Partner is `UP` with no active
    maintenance, `ReassessHeld` moves `Held → Investigating` (sweeper), with
    `ReassessmentPerformed` and the `Investigate` request.
  A Case still unhealthy writes nothing, so the Timeline gets no noise every minute.

**Rationale**: The minimum hold stops a HOLD on a healthy Partner from looping through the Agent
every sweep.

## R9 — Failure and the related Case

**Decision**:
- **Business error**: the execution is `failed` and the Case moves `Executing → Failed`. After the
  commit, the service reports the answer as a new Exception of the Order (`ProcessException`). The
  Order's latest Case is terminal, so this opens a related Case (003 FR-013) and routes it to
  investigation.
- **Exhausted transient budget**: `Failed`, with no new Exception. The partner was unavailable,
  and Held/reassessment is the path for that; it is reached by revalidation the next time.

**Rationale**: P1's second attempt is a business error that needs a new investigation (the
Mapping). Without the report, the Order would stay with a terminal Case and nothing to resolve.

## R10 — Verification on the live instance

- `GET /receipts` returns `items: []` for an unknown key (002 V3).
- The Simulator's hold is `max(clientTimeout + 5, 90 × timeScale)`. With
  a client timeout of 3 s (`Tests.Sim.ClientTimeout.Set(3)`) and `timeScale = 0.01`, a lost response
  takes ~8 s and the product's client gives up at 3 s.
- Events `PARTNER_DEGRADES`, `MAINTENANCE_STARTS` and `ORDER_CANCELLED_AT_ORIGIN` change health and
  Origin status at once (002 V5).
- **Baseline (T001)**: 221/221 on the branch start.
- **After 008 (T028)**: 269/269 ObjectScript tests on build 154, run 85. The new suites:
  - Core: `TestResponseClass`, `TestEffectKey`, `TestExecutionPolicy`;
  - Application: `TestExecution` 5, `TestRevalidation` 8, `TestReconciliation` 6, `TestLease` 5,
    `TestHeld` 3, `TestExecutionFailure` 5;
  - Api: `TestCaseDetailLayers.TestExecutionLayers`;
  - Interop: `TestPartnerHttp`, live;
  - Recovery: `TestRecoverySuite` 6, live against the Simulator, 0 duplicate Receipts.
- **Live contract check**: `validate_live.py`, extended to Cases with executions, reports "all
  responses conform". Its first run caught `revalidation.passed` stored as text. The fix writes a
  JSON boolean, and the read path normalizes the rows written before the fix.
- **Isolation**: the recovery suite sets the Simulator's client timeout through
  `Tests.Sim.ClientTimeout`, so `TestNoCrossReference` stays green.
