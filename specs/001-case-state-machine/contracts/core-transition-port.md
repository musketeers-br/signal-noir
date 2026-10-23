# Contract: Core transition port (for Phase B)

This is the shape the Core will have from 10/26 on. It is here so that José, Henrique and the Bench use the same vocabulary. It is **not** code of this story, and it is language-neutral: the Phase B Plan chooses the implementation language (research R4).

## Decision function (pure, no I/O)

```text
decide(snapshot: CaseSnapshot, command: TransitionCommand, now: UtcDateTime) -> Decision
```

- `CaseSnapshot`: the fields of Part 2 of the [data-model](../data-model.md), read by the Application.
- `TransitionCommand`: `{ transitionId?, requestedTo, actor, expectedState, expectedCaseVersion, targetId (proposalId or executionId), facts }`. `facts` carries what came from outside and was already recorded as Evidence or a verdict: the Validator verdict, the Revalidation result, the class of the Partner response, the Reconciliation result.
- `Decision` is a value, never an exception (Principle VII):
  - `Accepted { transitionId, to, events[], recordEffects[], outbox[], sameStep[] }`;
  - `Refused { code: INVALID_TRANSITION | INVALID_ACTOR | STALE_VERSION | APPROVAL_EXPIRED, discardedEvent }`;
  - `Attach { event }`, for commands that are an attachment in that state (for example, a new Exception in `Executing`).

## Resolution rules

1. No row with `from = snapshot.state` and `to = requestedTo` → `INVALID_TRANSITION`.
2. A row exists, but `actor` does not match `actors` → `INVALID_ACTOR`. This includes `benchmark` without a BenchmarkRun and a proposer different from the Case's mode.
3. `expectedCaseVersion` ≠ `snapshot.caseVersion` → `STALE_VERSION`. The exception is the repeated Approval (FR-014), which returns an idempotent `Accepted` with no transition.
4. Several rows for the same (from, to) pair, such as T05/T06 and T19/T20 → pick the only one whose preconditions hold. If two hold, the table is wrong, and the Phase A validator already refuses it.
5. False precondition → `Refused` with the code of the matching rule; when there is no specific code, `INVALID_TRANSITION`.
6. Revalidation with several false preconditions → precedence `Cancelled` > `Investigating` > `Held` (D3).

## Who calls it

Only the Application (AD-2) calls it, inside the short transaction: it reads the snapshot, calls `decide` and records the `Accepted` result (state, events, outbox) or the `CommandDiscarded` of `Refused`. No BS, BP, BO, sweeper or endpoint repeats these rules (Principle I).

## Parity test

The Phase B parity test walks every row of `contracts/case-state-machine.yaml`. For each one it builds a snapshot that satisfies the preconditions and checks that `decide` accepts with the same `to`, `events` and `outbox`. Then it walks the Cartesian product states × targets and checks that every pair outside the table yields `INVALID_TRANSITION`.
