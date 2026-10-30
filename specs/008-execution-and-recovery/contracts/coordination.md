# Coordination: 008 with 002, 004, 007, 009 and 010

No change to `contracts/openapi-signalnoir.yaml`, `contracts/openapi-sim.yaml`, the fixtures or the
integration files.

## 004 (Validator and reference data, Henrique)

- **`Core.Port.ExecutionPolicy` is 004's seam for revalidation** (004 US5, `Revalidate(input)`
  pure). 008 ships the default `Core.ExecutionPolicy`:
  - healthy means `UP` and no active maintenance;
  - the Order must be `active`;
  - the approval must be `valid` with `expiresAt` in the future;
  - the policy and mapping versions equal `CurrentVersions()`, which is empty, and so treated as
    unchanged, while no reference data is loaded;
  - 3 attempts, 300 s of minimum hold.
  004 replaces the instance in `ExecutionService.Default()`; callers do not change.
- **`EffectPayload(action, params, snapshot)`** is where 004 applies an approved mapping. Until
  then the default answers "mapping unavailable", and the mapping Action is held instead of sent.
- **Recording stays in 008**: `RevalidationPerformed` and the move to `Held` or `Cancelled`
  (coordination-004-006-009 "For 008"). The attempt count 004's `RETRY_BUDGET_EXHAUSTED` needs is
  the length of the Execution's attempts.

## 007 (Approval and outbox, Henry)

- `Execute` and `Reconcile` are now routed by `CommandBus`. The switch `"none"`, used by 007's
  tests and passed by `Sweeper.Run(..., "none")`, also leaves them pending.
- The approval is set `consumed` at authorization. `APPROVAL_VALID` refuses an expired approval
  without changing state. The sweeper's expiry stays the only path back to `PendingApproval`.

## 002 (Simulator) and the G1 notes

- The adapter `Interop.PartnerHttp` uses `SimulatorSource.Base()`, like the Tools and
  `OriginFeed`.
- The first delivery keeps its own key (research R4).

## API-Q11 (José, Henry)

- 008 adopts proposal 1: the key represents the effect, `H(orderId, partnerId, canonical
  payload)`, without renaming fields. Proposal 2 (renaming to `businessEffectKey`) stays open as a
  contract change.

## 010 (Benchmark)

- Recovery and P3 results are platform guarantees (Principle VIII). The recovery suite labels them
  so.
