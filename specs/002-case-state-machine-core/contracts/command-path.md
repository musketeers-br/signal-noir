# Contract: Application command path (provisional ObjectScript form)

The only way to change a Case (AD-2, spec FR-003). Callers: the Production (BS/BP/BO), the API, the sweeper and the Benchmark. All of them are outside this feature and call this contract.

## Entry points

```text
SignalNoir.Application.CaseCommands
  ClassMethod Submit(caseId As %String,
                     command As SignalNoir.Core.TransitionCommand) As SignalNoir.Application.CommandResult

  ClassMethod RecordException(orderId As %String, exception As %DynamicObject,
                              actor As %String) As SignalNoir.Application.CommandResult
```

- `Submit` covers T03–T29 and every attachment on an existing Case.
- `RecordException` covers the Exception entry point: T01 (first Case), T02 (new episode after a terminal Case), T16 (`PendingApproval`), or an `ExceptionRecorded` attachment, chosen by the Core from the Order's latest Case.

## CommandResult (value)

| Field | Values |
|---|---|
| `Outcome` | `Applied`, `Attached`, `Refused`, `IdempotentReplay`, `Failed` |
| `CaseId` | the Case written (the new one for T01/T02) |
| `State`, `CaseVersion` | after the command |
| `RefusalCode` | when `Refused` |
| `Events` | the Timeline `seq` numbers written |
| `OutboxCommandIds` | the work items queued |
| `FailureText` | when `Failed` (infrastructure error; nothing was recorded) |

## Guarantees

1. One short transaction per command, with no external I/O inside (AD-2).
2. `Applied`: state, `CaseVersion + 1`, all events and all outbox entries of the transition **and of its same-step chain** are committed together, or none is (spec FR-004). Each chained step emits its own `StateChanged` and increments `CaseVersion` once.
3. `Refused`: only `CommandDiscarded` is committed; state and `CaseVersion` unchanged (FR-006).
4. Compare-and-swap lost at write time (another writer committed first) → `Refused` with `STALE_VERSION`, recorded like any refusal; jobs may retry once (AD-3).
5. `Failed` is never reported as `Applied`.
6. No caller reads the clock for the Core: `Submit` reads it once and passes it to `Decide`.
