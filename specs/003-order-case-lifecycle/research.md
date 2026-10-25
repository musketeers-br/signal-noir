# Phase 0 Research: Order Intake and Case Lifecycle

**Date**: 2026-10-25
**Instance**: `congenial-waffle-iris-1`, namespace `IRISAPP`, reached through iris-agentic-dev
(`--container congenial-waffle-iris-1 -n IRISAPP`).

## Calendar-gate exception

- **Record**: on 2026-10-25 Henry explicitly authorized implementing feature 003 before the
  Constitution's calendar gate (no submission code before 2026-10-26). The exception covers this
  feature only; it is recorded here so the G1 review can see it. No other feature is affected.

## R0 — Platform build of the dev instance

- **Finding**: `$ZVERSION` on the running dev container is `IRIS for UNIX (Ubuntu Server LTS for
  ARM64 Containers) 2026.2 (Build 221U)`, not AI Hub build 154 as recorded in 001's research.
- **Decision**: Proceed. This feature uses no `%AI.*` API and no build-specific behavior; every
  platform behavior below is generic `%Persistent`/locking semantics.
- **Follow-up**: the gate integrator re-runs this feature's suites on the build 154 container
  before G1. Recorded, not blocking.

## R1 — Where the Case opens

- **Decision**: `AcceptOrder` stores the Order only and returns the orderId; a new
  `RecordException(orderId, exception)` command opens or joins the Case.
- **Rationale**: FR-010 (Case on first Exception); FR-003 (no Case for refused Orders); FR-012/013
  (routing depends on the existing Case state).
- **Alternatives considered**: keep `AcceptOrder → CaseRef` (contradicts FR-010); open the Case on
  acceptance in a hidden state (invents a state, violates the closed vocabulary).
- **Consequence**: seam change → `contracts/contract-change-003-case-lifecycle-seam.md`, published
  as `docs/seams.md` v3; 001 tests and fakes that relied on the old semantics are updated in the
  same change.

## R2 — At most one non-terminal Case per orderId

- **Decision**: `CaseRecord.openOrderId` holds the orderId while the Case is non-terminal and is
  cleared on the transition to a terminal state; `Index openOrderIdx On openOrderId [ Unique ]`.
  Opening a Case and the uniqueness check happen in the same transaction under
  `LOCK +^SignalNoir.OrderLock(orderId)`, so a concurrent opener waits and then joins.
- **Rationale**: AD-25 asks for a unique index; the lock turns a would-be `#5808` into a clean
  "join the existing Case", and the index is the safety net.
- **Alternatives considered**: the 001 global `^SignalNoir.OpenCaseByOrder` (no atomicity with the
  Case row); a unique index on `(orderId, terminal)` (several terminal Cases would collide).
- **Verified live**: a unique index accepts several rows with an empty value and refuses a
  duplicate non-empty value with `ERROR #5808: Key not unique`.

## R3 — Compare-and-swap and Case version

- **Decision**: add an explicit `CaseRecord.caseVersion` incremented by exactly one on each
  transition. `Transition` takes `LOCK +^SignalNoir.CaseLock(caseId)` inside the transaction, reloads
  the row, compares expected `caseVersion`, optional expected state and optional expected target
  (`currentProposalId` / `currentExecutionId`), writes, then commits. A mismatch returns
  `STALE_VERSION` with `details` (expectedCaseVersion, caseVersion, lastEventSeq, state,
  currentProposalId, serverTime). The `VERSIONPROPERTY` row version stays as a second guard; a
  `#5800` on save is also mapped to `STALE_VERSION`.
- **Rationale**: FR-019/020/021. Attachments update `lastEventSeq` on the row, so the row version
  cannot double as `caseVersion`.
- **Alternatives considered**: row version as `caseVersion` (bumps on attachments); compare
  without lock (race between read and save, only caught as `#5800` after the event rows were
  written).
- **Verified live**: saving an object whose row was updated by another writer returns
  `ERROR #5800: Concurrency failure on update: object versions not the same`.
- **AD-3 note**: the lock is held only for the few statements of the commit, never across a read
  shown to a user or any I/O; it is the mechanism that makes the compare-and-swap atomic, not a
  pessimistic lock in the AD-3 sense.

## R4 — Timeline sequence and late confirmation

- **Decision**: `seq` = `CaseRecord.lastEventSeq + 1`, assigned under the per-Case lock and saved on
  the Case row in the same transaction as the event row. Readers return only events with
  `seq <= CaseRecord.lastEventSeq` (the committed watermark).
- **Rationale**: FR-023 (no reuse, no gap) and FR-031 (no skipped event). Because the lock is held
  until `TCOMMIT`, commits of one Case happen in `seq` order and the watermark only advances past
  committed events.
- **Alternatives considered**: `$INCREMENT` (not rolled back → gaps; out-of-order commits → a
  poller that saw N+1 skips N forever); reader-side "wait for gaps" (unbounded wait).
- **Verified live**: a `LOCK -` issued inside a transaction is deferred: another process could not
  acquire the lock until the holder's `TCOMMIT`.

## R5 — Order shape check

- **Decision**: `Core.OrderShape.Check(snapshot) → ordered reason list` for the Origin
  `SyntheticOrder` required fields (`orderId`, `partnerId`, `patient.patientId`, `exams[≥1].code`,
  `specimen.specimenId`, `specimen.collectedAt` parseable, `requestedAt`, `synthetic = true`).
  Reasons are stable strings such as `missing:specimen.specimenId`, `unreadable:specimen.collectedAt`,
  `not_synthetic`.
- **Rationale**: FR-002/003; Principle I (rule in the core, no I/O); `%DynamicObject` is an
  in-memory value, not I/O.
- **Alternatives considered**: JSON Schema validation at runtime (needs a library and the frozen
  sim contract at runtime); checking in the Business Service (rule outside the core).
- **Refusal record**: `IntakeRefusalRecord` keeps the reasons, the moment, the transaction id and
  the orderId when present; the HTTP/Production caller receives `VALIDATION_FAILED` with the
  reasons in `details`.

## R6 — Equivalence key

- **Decision**: `Core.Canon.FromSnapshot(snapshot)` builds `patientId|CODES|collectedAtUTC|specimenId`
  then `Canonize`. `NormalizeUtc` is extended to apply `±HH:MM`/`±HHMM` offsets (today it strips
  them, which yields a wrong UTC instant). Output keeps seconds precision with `Z`.
- **Rationale**: FR-006 and acceptance US1-3 (same key across order/case/offset variants).
- **Alternatives considered**: `$ZDATETIMEH(…,3)` with offset handling by the platform (behavior
  with offsets not verified; pure arithmetic over `$ZDATEH` keeps the core deterministic and
  testable).

## R7 — Exception routing and related Cases

- **Decision**: `Core.CaseMachine.RouteException(latestState) →` one of `open` (no Case or latest is
  terminal → new Case, with `previousCaseId` when one exists), `attach` (`Investigating`, `Approved`,
  `Executing`) or `attach_and_investigate` (other non-terminal states → transition to
  `Investigating`, follow-up `Investigate`). Exceptions are `ExceptionRecord` rows; the Timeline
  gets `ExceptionRecorded`; the new Case's `CaseOpened` payload carries `previousCaseId`.
- **Rationale**: FR-009–013; AD-24 (new Exception in `Approved`/`Executing` is attachment only);
  Constitution V (related Case on a new episode). The `Failed → Investigating` note in AD-24 is
  not adopted (terminal never reopens; spec Assumptions).

## R8 — Closed Timeline event types and actors

- **Decision**: `Vocab.EVENTTYPES` = the contract's `TimelineEventType` enum. Transitions write
  `StateChanged` with `{from, to, reason, caseVersionAfter}`; opening writes `CaseOpened`; an
  Exception writes `ExceptionRecorded`. `Append` refuses an unknown type with `VALIDATION_FAILED`.
  `Vocab.ACTORS` gains `rules` and `replay` to match the contract's `Actor` pattern.
- **Rationale**: FR-023, FR-032 (responses must validate). 001 wrote `OrderAccepted`,
  `CaseTransition` and `ReviewRequired` types, which the contract does not allow.

## R9 — List cursor and projections

- **Decision**: `Index activityIdx On (lastEventAt, caseId)`; list via `%SQL.Statement` ordered by
  `(lastEventAt, caseId)` DESC for `older`, ASC and strictly greater for `newer`, with filters
  `state` (list), `status`, `pendingApproval`, `runId`, `includeBenchmark`, `limit`. The cursor is
  `Core.Cursor.Encode(lastEventAt, caseId)` = base64url of `lastEventAt|caseId`; a cursor that does
  not decode to a valid pair is `VALIDATION_FAILED`. `lastEventAt` uses millisecond UTC
  (`$ZTIMESTAMP`) so ordering is stable.
- **Rationale**: FR-028, contract `listCases` description.
- **Detail**: `CaseDetail` with empty `evidence/proposals/approvals/executions`, `diagnosis`,
  `currentProposalId`, `receipt`, `dossier` = `null` until their features fill them, `metrics` =
  `{}`, `denialCount`, `order` as `OrderView` (equivalence key split into parts). `SystemClock`
  moves from `$H` (local time) to `$ZTIMESTAMP` (UTC).

## R10 — Restart recovery

- **Decision**: `CaseService.RecoverInterrupted()` runs from `Bootstrap.OnStart`. A Case in
  `Investigating` whose `Investigate` outbox entry is `dispatched` (picked up, not finished) moves
  to `ReviewRequired` with reason `investigation interrupted`. A `pending` entry is left for the
  consumer (it was never started).
- **Rationale**: FR-026/027; AD-4. The outbox consumer arrives with 006/007; the status values are
  defined now so recovery does not change later.

## R11 — Delivery attempt boundary

- **Decision**: this feature exposes the command that records an attempt's failure
  (`OrderIn.ReportException` → `CaseService.RecordException`) and the closed Exception kinds; the
  outbound HTTP adapter that performs the delivery and classifies `{status, body}` is wired at the
  G1 integration with 002 and the Partner classifier (AD-13, 008).
- **Rationale**: keeps 003 testable with no Simulator and no classifier; the spec's acceptance
  scenarios are exercised by reporting the attempt outcome.

## Verification log (iris-agentic-dev, 2026-10-25)

| Check | Command (summary) | Result |
|---|---|---|
| Build | `exec 'write $ZVERSION'` | `2026.2 (Build 221U)` (see R0) |
| Unique index with empty values | throwaway `SNProbe003.Uniq` with `Index … [ Unique ]`, two empty rows, two `"X"` rows | empty rows saved; duplicate → `#5808` |
| Version mismatch | open row, `UPDATE` via SQL, save stale object | `#5800 Concurrency failure on update` |
| Lock release in transaction | `TSTART`, `LOCK +`, `LOCK -`, `JOB` tries `LOCK +…:0` before `TCOMMIT` | worker could not acquire (`$TEST=0`) |
| Cleanup | `$System.OBJ.Delete("SNProbe003.*")`, globals killed | done |

## Implementation verification log (iris-agentic-dev, 2026-10-25)

| Check | Result |
|---|---|
| Baseline before 003 (T001) | The first baseline read the result global of the wrong namespace and is not reliable. On master's source, `Api.TestHealth:TestHealthPayloadShape` cannot pass (`$Find(reason, "provider unavailable") = 1` can never be true; `$Find` returns the position after the match). Left as is: it belongs to 001. |
| Full suite after 003 (T054) | `SignalNoir.Tests.*`: 82 test methods pass, 1 fails (the pre-existing `TestHealth` above). Includes 100 concurrent two-writer trials (`TestConcurrency.TestTwoWritersOneWins`) and 10 concurrent first-Exception trials. |
| Contract conformance of live HTTP (T046) | `tests/contract/validate_live.py` against `/signalnoir/api/v1`: list, `newer` polling, next page, filters, 3 details, 6 Timeline pages, 404 and 400 envelopes — all conform. The first run found `seq` serialized as a string; fixed (`+ev.seq`). |
| Frozen fixtures | `contracts/tools/validate_fixtures.py`: 25 valid, 0 invalid (contract untouched). |
| Container restart (T039) | `docker restart congenial-waffle-iris-1` with three Cases: `Open` (v1, seq 2) and `PendingApproval` (v4, seq 5) came back identical; the `Investigating` Case with a dispatched Investigate request came back `ReviewRequired`, reason `investigation interrupted`, via `^%ZSTART` → `Bootstrap.OnStart` (`recoveredCases = 1`). |
| Web application | `Bootstrap.EnsureWebApplications` failed on this build: `Security.Applications.Type = 18` is refused (`MAXVAL 9`). Changed to `2` (CSP/REST); the API answers after start-up. |
| Shared lock for readers | IRIS reads are uncommitted by default, so `GetTimeline` takes a shared lock on the Case before reading the watermark; `TestProjections.TestLateConfirmationIsNeverSkipped` proves a held commit is neither shown early nor skipped. |
| 001 core bugs found | `Canon.OrderCodes` sorted with the numeric `<` (no effect on strings); `Canon.EquivalenceKey` used `$Get(list.GetAt(i))` (runtime `<PROPERTY DOES NOT EXIST>`); `NormalizeUtc` dropped offsets instead of applying them. All fixed with tests. |
| Legacy dev data | The model storage was regenerated (new global names), so rows written by 001 tests are no longer read; nothing was deleted. |
