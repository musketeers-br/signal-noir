# Contract: Core decision port (provisional ObjectScript form)

The language-neutral contract is [specs/001-case-state-machine/contracts/core-transition-port.md](../../001-case-state-machine/contracts/core-transition-port.md). This file fixes its provisional ObjectScript shape (research R1, **SPIKE-DEPENDENT**). If the spike moves the Core to Embedded Python methods (R4 option 2), only method bodies change; the signatures below stay.

## Entry point

```text
SignalNoir.Core.Decider
  ClassMethod Decide(snapshot As SignalNoir.Core.CaseSnapshot,
                     command As SignalNoir.Core.TransitionCommand,
                     now As %String) As SignalNoir.Core.Decision
```

- `now` is ISO-8601 UTC with `Z`, supplied by the caller (research R8).
- Pure: no globals, no SQL, no files, no network, no `$ZTIMESTAMP`, no `$INCREMENT`. A unit test asserts the class has no reference to persistence or I/O classes.
- Never throws for a predictable outcome; returns a `Decision` (research R5).

## Resolution order

1. `command.Kind = "Attach"`: accepted only if the event is allowed in `snapshot.State` (attachment matrix); otherwise `Refused(INVALID_TRANSITION)`. A new Exception in `PendingApproval` is not an attachment: it is T16. A new Exception for a terminal Case is handled by the Application as T02 on a new Case.
2. Repeated Approval: `decideProposal` approve on a `proposalId` already approved → `Accepted` with `IdempotentReplay = 1`, no events, no outbox (spec 001 FR-014). Evaluated before the version check.
3. `command.ExpectedCaseVersion ≠ snapshot.CaseVersion` or `ExpectedState ≠ State` or target mismatch → `Refused(STALE_VERSION)`.
4. No row with `from = State` and `to = RequestedState` → `Refused(INVALID_TRANSITION)`.
5. Rows exist but none lists the actor (`operator:<name>` matches `operator:*`; proposers must equal `ProposerMode`; `benchmark` needs `BenchmarkRunId`) → `Refused(INVALID_ACTOR)`.
6. Keep the rows whose preconditions all hold. Exactly one → `Accepted` with its events (`StateChanged` first, `caseVersionAfter = CaseVersion + 1`), record effects, outbox and same-step chain. None → `Refused(APPROVAL_EXPIRED)` when the only failing check is `approvalNotExpired` on T17, else `Refused(INVALID_TRANSITION)`. More than one → table defect: `Refused(INVALID_TRANSITION)` and a technical log entry (the parity test prevents shipping it).
7. Revalidation facts with several failed checks: the Core picks the row by precedence `Cancelled` > `Investigating` > `Held` before step 6.

## Errors

- `Refused` codes map to HTTP by the API (outside this feature): `INVALID_TRANSITION` and `STALE_VERSION` → 409, `INVALID_ACTOR` → 403; `APPROVAL_EXPIRED` is internal (spec 001 C7).
