# Research: Benchmark and Reference Run

**Feature**: 010-benchmark-and-reference-run | **Date**: 2026-10-31 | **Plan**: [plan.md](./plan.md)

This file records the decisions the spec left to the plan, what was read in the repository, and what
was verified on the live instance with iris-agentic-dev. Platform facts verified by earlier features are
cited as "001-Vn" / "004-Dn". Everything the plan relies on that is not verified is listed in
**Verification backlog** and MUST be verified before `/speckit-implement` reaches the task that uses it.

## What already exists (read on 2026-10-31, `master` at 9adfc41)

| Piece | State | Consequence for 010 |
|---|---|---|
| Simulator `POST /scenarios` + `POST /scenarios/{id}/emissions` | done (002) | Accept `runId`, `repetition`, `seed`, `timeScale`; the feed item carries `runId` (V1). |
| Order → `OrderRecord.runId` → `CaseRecord.runId` | done (003) | The run id already travels; nothing says whether the run exists. |
| `CaseService.NewCase` | done (003) | Hard-codes `proposerMode = "agent"` and `replay = 0`. No run lookup (V2). |
| Automatic Approval (`RouteProposal`, `Decide`) | done (007) | Calls `Policy().Admit("benchmark", rec.runId)`; `Admit` is true for any non-empty id, even a run that was never created (V2). |
| `Proposers.Factory`, `Rules`, `Agent`, `Replay` | done (006) | Mode selects the class at one place. `Replay` is keyed by `orderId`, which differs on every scenario instance (D11). |
| Reference data pinning | done (004) | `Store.For(run)` honours `run.policyVersion` / `run.mappingVersion`; `ResolutionValidator.RunFor` returns `null` pins until a run records them. |
| `InvestigationRecord` | done (006) | Has `mode`, `provider`, `model`, `promptVersion`, `policyVersion`, `mappingVersion`, `durationMs`, `toolCalls`, `tokensIn/Out`, `estCostUsd`, `outcomeReason`. Enough for latency, tool calls and cost. |
| Recovery suite | done (008) | `Tests.Recovery.TestRecoverySuite` has `TestLostResponse`, `TestRepeatedClickAndCommand`, `TestRestartDuringExecuting`, `TestLateWorker`, `TestBlockingPreconditions`. |
| BenchmarkRun record, run API, runner, scorer, report | **absent** | This feature. |
| Reserved test variants | **placeholders** | `P5Test` and `P8Test` hold one shape-only variant each (`P5-test-00`, `P8b-test-00`). The real ten are Henrique's deliverable at the freeze. |
| Tuning variants | P5: 3 + 1 injection; P8: `P8a-tune-01`, `P8b-tune-01`, `P8b-tune-02`; clean: 5; P3: 3; idempotency: 3 | Enough to develop against, not for the reference. |

## Verification log (iris-agentic-dev, container `signalnoir-g1`, namespace `IRISAPP`, 2026-10-31)

Container: IRIS `2026.2.0.221.0com` (the repo image), built from `master` at 9adfc41. The project target
build for AI Hub is 154 (001-V1); nothing in 010 touches the AI Hub API.

- **V1 — the Simulator carries the run to the feed.** `POST /scenarios` with
  `{"family":"P5","variant":"P5-tune-01","seed":9,"runId":"run_probe010","repetition":1}` returned an
  instance echoing `runId` and `repetition`; `POST …/emissions` returned a feed item with
  `"runId":"run_probe010","repetition":1` and an Order id derived from the instance
  (`ORD-sci_…-0001`). Confirms FR-007 can be met over the HTTP contract alone.
- **V2 — the gap the spec closes.** With `^SignalNoir.Config("simBaseUrl")` set, `OriginFeed.Poll()`
  accepted the item and opened a Case with `runId = run_probe010` and `proposerMode = agent`, though no
  run named `run_probe010` exists. `ApprovalPolicy.Admit("benchmark", "run_never_created")` returned `1`.
  So today (a) the mode is never copied from a run, (b) any non-empty id is a "valid" run, (c) the actor
  `benchmark` is admitted for runs that do not exist. FR-003, FR-008 and FR-009 need a run directory.
  (Probe data was left in the throwaway container only; nothing was committed.)
- **V3 — version parameters exist.** `Proposers.Rules` has `Parameter VERSION = "rules-v1"` and
  `Proposers.Agent` has `Parameter PROMPTVERSION = "agent-v1"`. These are what a freeze can name at run
  time (D8).
- **V4 — source reads are refused at run time by design.** `%Compiler.UDL.TextServices` called through
  `iris-agentic-dev exec` was refused (`CODE_EDIT_BLOCKED`, "reaching class or routine code … is
  refused"). A class-source digest therefore cannot be a *runtime* check, and iris-agentic-dev must not be
  bent to do it (it is a development tool, not a dependency). The source digest is a **repository** check
  (D8).

## D1 — Shape: pure Core, application runner, committed data

**Decision.** Four parts, inward dependencies only (Principle I):

1. `SignalNoir.Core.Benchmark.*` — pure, no I/O: `Scorer` (classification), `Stats` (percentiles,
   proportions, ranges), `Seed` (derivation), `RunPolicy` (create-time rules, run state machine),
   `FreezeCheck` (compare inputs with the freeze record; roles; what makes a run *development*),
   `Guarantees` (pass / fail / not exercised from counts).
2. `SignalNoir.Application.Benchmark.*` — the run service, the runner, the report builder, the quick
   validation, and `RunStore`, the implementation of the new port `Core.Port.RunDirectory`.
3. `SignalNoir.Benchmark.Data.*` — committed, versioned XData (answer keys, the freeze record, the review
   records, the declarations of used sets, the recorded reference result), the same pattern as
   `Sim.Catalog.*` and 004's fixtures.
4. `SignalNoir.Api.BenchmarkDispatch` — the endpoints of the contract.

**Rationale.** The scoring rules decide whether the thesis is supported; they are the part that must be
testable exhaustively and without I/O (Constitution I, VIII). The runner is the only part that talks to
the Simulator, and it does so only through `Interop.SimulatorHttp`.

**Alternatives.** A single `BenchmarkService` doing scoring inline: rejected (cannot be tested without
Cases). Scoring in the console: rejected (the report must be the same for any client).

## D2 — Run directory: how a Case learns its run (FR-003, FR-006, FR-008, FR-009)

**Decision.** A new inner port `Core.Port.RunDirectory` with `Find(runId)` returning `{runId, mode, status,
purpose, policyVersion, mappingVersion}` or empty. `CaseService.NewCase` asks it once, at opening:

- the run exists and is `running` → `rec.runId = runId`, `rec.proposerMode = run.mode`,
  `rec.replay = (mode = replay)`;
- absent, unknown or not `running` → `rec.runId = ""`, mode `agent`, `replay = 0`. The raw id stays on the
  `OrderRecord` for diagnosis.

Because the Case now keeps only a *valid* run id, `ApprovalPolicy.Admit(actor, runId)` stays pure and its
existing rule ("benchmark only with a non-empty run id") becomes correct without changing the Core. For
the window in which a run ends while a Case is in flight, the two call sites in `CaseService` also ask
`RunDirectory` that the run is still `running` before they record an automatic Approval.

**Rationale.** One lookup at the boundary, no rule copied into the Core. Closes V2 for all three
requirements at once. The `Admit` unit tests of 007 keep passing.

**Alternatives.** Put the run status into `Admit` (an I/O argument in a pure function): rejected. Resolve
the mode in `Proposers.Factory`: rejected, it only sees `proposerMode`, and the `replay` flag and the run
id must be set on the Case anyway.

**Cost.** A small edit to `CaseService` (Henry's 003/007 file), listed in
[contracts/coordination-010.md](./contracts/coordination-010.md).

## D3 — Run record, items and pinning (FR-001, FR-002, FR-004–FR-006)

**Decision.** Two new persistent classes in `Application.Model` (see [data-model.md](./data-model.md)):
`BenchmarkRunRecord` (identity, mode, purpose, status, provider and model, repetitions, seed, the
**pinned** policy and Mapping versions, the selection, progress counters, development flag and reasons,
the freeze copy, the final report, heartbeat) and `BenchmarkItemRecord` (one row per planned scenario,
variant and repetition, with its seed, scenario instance, Case and status).

The pins are chosen at creation (`fixtureSet` of the request, else `Store.InForce()`), validated with
`Store.For(run)` and stored. `ResolutionValidator.RunFor(rec)` then reads the run through `RunDirectory`
and returns the pins instead of `null` (the one place 004 named for this). A Case validates against the
pins from its first Proposal to its end (FR-006).

**Seed (FR-004).** `Core.Benchmark.Seed.For(baseSeed, family, variant, repetition)` = the first 31 bits of
`SHA-256("base|family|variant|repetition")`, a pure function with golden-value tests. With the Simulator's
own determinism (`(family, variant, seed)` ⇒ same responses) this gives FR-004 end to end.

**Alternatives.** Keep the plan in the run's JSON only: rejected, the report and the progress need to be
queried per item and survive a restart.

## D4 — The runner: observe, resume, never approve (FR-002, FR-005, FR-007)

**Decision.** `Application.Benchmark.Runner.Step(runId)` is one idempotent step that reads the persisted
items and does the next thing that is missing:

1. an item `planned` → `POST /scenarios` (family, variant, derived seed, `runId`, `repetition`) and
   `POST …/emissions` through `SimulatorHttp`; store `scenarioInstanceId`; then run the product's own
   intake once (`OriginFeed.Poll`) so the Case opens now instead of at the next scheduled read;
2. an item `opened` → read the Case (read-only) and mark `ended` when it is terminal or in
   `ReviewRequired` (the contract's `casesTerminal`); mark `not_decided` when the Case sits in a
   non-terminal state past the item deadline;
3. all items ended → build and store the report, `completed`.

`RunService.Create` persists the run and the plan, then `JOB`s `Runner.Drive(runId)`, which loops `Step`
with a short pause and updates `heartbeatAt`. A periodic task (`Tasks.BenchmarkTask`, the `Periodic`
pattern) re-drives a `running` run whose heartbeat is stale, so a restart does not strand a run. Items run
**one at a time**: the reference run is about 40 investigations, each bounded by the Investigation budget
(20 s default), so about 15 minutes, which is acceptable; parallelism is YAGNI.

The runner has no write path to Cases: it never calls `CaseService` commands. The intake it triggers is
the product's own process that opens the Case; the Approval of FR-008 is still emitted by
`CaseService.RouteProposal` ("the process that opens and drives the Case"), unchanged from 007 and
tightened by D2. A test fails if `Runner` or `ReportBuilder` reference `RecordApproval`, `Decide` or
`ApplyTransition` (a static scan like 004's `TestDeterminismNoIo`).

**One run at a time (FR-005, API-Q10).** `RunService.Create` takes a lock and refuses with 409
`INVALID_TRANSITION` when a run is `created` or `running`. A run stuck `running` after a crash is
re-driven by the task or failed with a reason when it passes its deadline; it never blocks forever.

**Alternatives.** One long-lived JOB per run with no persisted plan: rejected (a restart loses it).
Letting the console drive: rejected (the console is out of scope and a run must not depend on a browser).

## D5 — Scoring (FR-014–FR-018)

The full rules are in [contracts/scoring.md](./contracts/scoring.md). In short:

- **Answer key** per variant, declared before the run, in XData (`Benchmark.Data.AnswerKeyTuning`, and
  `AnswerKeyTest` for the reserved set, committed at the freeze by its holder): the acceptable Actions
  with their parameters, whether review is acceptable, and notes. `params` is a subset match on canonical
  values (a Mapping id, a retry flag), compared with `Core.Canon`, never as text.
- **Final effect** is what the Case ended with: an executed Action with its parameters, a `Held`, or
  review. Classification: **correct** (effect in the key), **safe review** (review and the key accepts
  review), **unnecessary review** (review and the key does not), **incorrect** (an effect not in the key
  or in the key with wrong parameters). A Case that never decided for a reason outside the decision is
  **not decided**, reported apart (D6).
- **Two counts that are never added:** *blocked wrong Proposal* (a Proposal outside the key that the
  Validator stopped) and *wrong effect* (an Action outside the key that was sent).
- A Case acted on by a person (any Timeline event whose actor is `operator:*`) is *touched* and leaves the
  agent decision metrics (FR-018).

**Rationale.** The four categories plus the two counts are the spec's. Putting "review is also acceptable"
in the key, not in the scorer, keeps the evaluator free of opinions: the key is the single place a person
says what is right, and it is reviewable.

## D6 — "Not decided" is a value, not a fifth score (FR-017, Principle VII)

**Decision.** `BenchmarkCaseResult.outcome` is `null` for a Case that did not decide (the contract already
allows `null`), with a `notDecidedReason` (`provider_unavailable`, `run_failed`, `deadline`). A Case touched
by a person is a different thing: `countsInMetrics = false` with its own flag. The report's rows carry
`counts`, `notDecided` and **two denominators**, with and without them, so a provider outage cannot turn
into "safe review". The reason is read from the Investigation's `outcomeReason` and the Case's
`reviewReason`, never by matching text (pinned by a test; backlog B3).

This needs fields the contract does not have: see
[contracts/contract-change-010-benchmark.md](./contracts/contract-change-010-benchmark.md).

## D7 — Statistics (FR-019, FR-022, FR-028)

**Decision.** `Core.Benchmark.Stats` computes, per (family, subtype, set, mode) and **per repetition**: the
count of each outcome, its proportion over the number of *variants* of that repetition, p50 and p95
latency (nearest-rank over the Cases of the repetition), and tool calls and estimated cost per Case
(means). The **range** reported is the minimum and maximum of those per-repetition values across
repetitions. A variant therefore enters every denominator once; repetitions supply only the range
(FR-028). When fewer than k repetitions completed for a variant, the row records `repetitionsCovered`
instead of presenting a k-run range.

Nearest-rank is chosen because it needs no interpolation, so an independent implementation (D9) agrees bit
for bit. With 5 variants a p95 is the maximum; the report says so in a `note` rather than hide it.

## D8 — Frozen setup, development data and independence (FR-025–FR-029)

**Decision.** Four committed XData records, all in `SignalNoir.Benchmark.Data`:

- `Freeze` — one record: `freezeId`, the commit, and the inputs: prompt version (`Agent.PROMPTVERSION`),
  model, baseline version (`Rules.VERSION`), policy and Mapping versions with the digest of each fixture
  (004's `Store`), the evaluator version (`Scorer.VERSION`), the digest of the reserved catalog and of the
  answer keys, and `files`: the git blob id of each frozen source file.
- `Roles` — who prepared the reserved cases and the answer key, who wrote the baseline, per family.
- `Reviews` — the review records (kind baseline | evaluator, family, author, reviewer, commit, date, and
  `automated` when an automated reviewer did it).
- `SetUsage` — one line per declared-used set (`P5/test`, `P8/test`) with who, when and why. A set that
  appears here is development data. It is declared by commit, not by an endpoint, so it is auditable and
  cannot be undone silently.

`Core.Benchmark.FreezeCheck.Evaluate(freeze, current, roles, reviews, usage, selection)` returns
`{development, reasons[]}`. A run is marked **development** (it runs, its report says why, and it is not
publishable as the reference) when: a frozen input at run time differs from the record, the set was
declared used, the author of a family's answer key also wrote its baseline, or no roles are recorded for
the family. A review never marks a run development (amended 2026-11-01 for Constitution 2.0.0, Principle
VIII): `FreezeCheck.ReviewStatus` says how each was done (`other_member`, `self`, `automated`,
`incomplete`, `missing`) and the report shows it in `setup.independence.reviewStatus`. **Refused** at creation (400): empty selection,
unknown family or variant, tuning variants (alone or mixed) with purpose `reference`.

Runtime compares the declared versions and the fixture and catalog digests (V3). Source files cannot be
hashed at run time (V4), so the **repository** check is a script, `scripts/benchmark/check-freeze.sh`,
that compares `git hash-object` of each frozen file with the record and runs in CI: a frozen file changed
without a new freeze fails CI. The freeze commit is one commit, as `PARALELISMO.md` requires.

**Rationale.** Static data in the repository is reviewable and cannot be edited through the API; version
parameters alone can be forgotten, the CI check cannot.

## D9 — Raw data and an independent recomputation (FR-022, SC-reproducible)

**Decision.** The raw data of a run is `BenchmarkReport.cases` (one row per Case: ids, family, subtype,
variant, set, repetition, final state, Action, params, outcome, latency, tool calls, cost, replay,
`countsInMetrics`, `touchedByPerson`, `notDecidedReason`). The reference run's report and its raw data are
committed under `docs/benchmark/`, and `scripts/benchmark/recompute.py` (Python standard library only,
independent of ObjectScript) recomputes counts, proportions, p50/p95, ranges and the denominators from the
raw rows and fails if they differ from the report. Two implementations agreeing is the evidence that "the
report is reproducible from raw data"; the ObjectScript `Stats` is tested against the same golden file.

**Alternatives.** Publish the report only: rejected (FR-022). A new export endpoint: rejected (API-Q9 stays
open; `cases` is enough).

## D10 — Platform guarantees (FR-020)

**Decision.** The six guarantees are computed by `Core.Benchmark.Guarantees` from facts the application
already records, with an explicit third state:

| Guarantee | Evidence in the run | Source |
|---|---|---|
| P3 | executions with a stale precondition, invalid Actions executed | Cases of family P3 in the run |
| idempotency | duplicate Receipts per effect key | all Cases that executed |
| timeout | uncertain outcomes that were reconciled with no resend before | Cases with an uncertain outcome |
| repeated approval | exactly one effective Approval per Proposal | idempotency variants |
| restart | no duplicate effect after a restart during `Executing` | recovery suite (`TestRestartDuringExecuting`) |
| late worker | a late worker did not overwrite a later execution | recovery suite (`TestLateWorker`) |

A guarantee the run did not exercise reports **not exercised**, never "pass" (Principle VII: absence is
not a negative). The platform scenarios (P3, idempotency) are part of a run when its selection lists them,
run in the run's own mode, and appear **only** in this part of the report, never in the agent decision part.

`restart` and `late worker` need a process restart or a racing worker, which a scenario cannot cause
through the Simulator. Their evidence is the recovery suite of 008, recorded with its commit in
`Benchmark.Data.ReferenceResult` when the reference run is published, and shown with `source:
recovery_suite`. **The spec does not say this; it is Q2 in the plan's open decisions.**

## D11 — Replay (FR-031, FR-032)

**Decision.** A replay run sets `mode = replay`; its Cases open with `replay = 1` and proposer `Replay`.
`Proposers.Replay` today looks up `^SignalNoir.Replay(orderId)`, but a new scenario instance has a new
`orderId` every time, so a recorded answer would never be found. Recorded answers are re-keyed by the
**reference case** (`family/variant/repetition`) in `Benchmark.Data.ReferenceResult`; `Replay` resolves the
key through the item (`orderId` → `scenarioInstanceId` → item). Replay Cases carry `countsInMetrics =
false`, are excluded from every count, denominator, latency and cost, and a comparative request that
includes a replay run is refused with 400 `VALIDATION_FAILED` (the contract already says so). No console
entry point is built (the console is out of scope); the API accepts `mode=replay` because the quick
validation and the fallback video need it.

## D12 — Quick validation (FR-033, FR-034)

**Decision.** `scripts/quick-validate.sh` (bash and curl, the style of `scripts/smoke.sh`) creates one run
with purpose `quick_validation` over three recorded reference cases and polls its report. The three cases
follow the spec: **clean** (a `clean-success` variant), **P5/P8b** (one reserved variant of the reference),
and **Dossier** (`clean-ambiguous-identity`, which ends in `ReviewRequired` with a Dossier; fixture
`case.review.ambiguous-identity.json`). The mode is `agent` when a provider is configured, else `replay`
(deterministic, no key). The report's `quickValidation[]` compares each Case with the recorded
`ReferenceResult` (final state, Action, params) and, for a live agent run, adds "provider or model differs
from the reference". Budget: 3 Cases × the Investigation budget (20 s) plus intake is about 90 s; the
script exits non-zero when the report is not there within 180 s. `quick_validation` runs never enter
`reference` or `benchmark` comparisons (`RunPolicy` refuses them).

## D13 — API and wiring

The routes of the contract, forwarded from the existing dispatch by `Map` entries to
`Api.BenchmarkDispatch` (`/benchmark-runs`, `/benchmark-runs/:runid`, `/benchmark-runs/:runid/report`,
`/benchmark-reports`). Errors follow API-Q2: 400 `VALIDATION_FAILED` (malformed or refused selection), 404
`NOT_FOUND`, 409 `INVALID_TRANSITION` (a run is running; a report asked before the run ends). A created run
answers 202 with `Location`. The report of an unfinished run is never partial (FR-024).

## D14 — Calendar and critical path

Today is 2026-10-31; the functional freeze is 2026-11-05. The order in `PARALELISMO.md` for wave 5 is
mandatory: baseline and evaluator ready → José's review (commit and date recorded) → one freeze commit
(prompt, model, baseline, policies, fixtures, evaluator, reserved variants) → reference run → report with
the independence metadata. The code of 010 (runner, scorer, report, API, freeze machinery) does not depend
on that order and can be finished first; the reference run cannot. The tasks will mark the things only
other people can do: **the ten reserved variants and their answer key (Henrique)**, **the baseline
(Henry)** and **its review (José)**.

## Verification backlog (iris-agentic-dev, before the task that uses each)

- **B1.** `%CSP.REST` `Map` with `Forward` for the prefixes `/benchmark-runs` and `/benchmark-reports`
  routes to `Api.BenchmarkDispatch` and the existing `/cases` routes still work (D13).
- **B2.** A `JOB`-started driver survives the end of the HTTP request that created it, and the periodic
  task can re-drive a stale run (the pattern of `CommandBus.DeliverJob` and `Tasks.Periodic`; confirm the
  heartbeat logic on the live task manager) (D4).
- **B3.** `InvestigationRecord.outcomeReason` and `CaseRecord.reviewReason` for the provider-unavailable
  path (fixture `case.review.provider-unavailable.json`) are stable, coded values, not free text. If not,
  a coded marker is added in 006's path (coordination) (D6).
- **B4.** `Core.Canon` canonical comparison of `params` for the answer-key subset match, with the real
  Mapping ids of 004 (D5).
- **B5.** The new persistent classes compile with generated Storage blocks, which are committed like the
  other models (`Application/Model/*` carry them). Compile in a fresh container (3 passes) and commit the
  blocks; do not commit Storage diffs of unrelated classes (the `Precedent*` classes of 013 show them).
- **B6.** `scripts/benchmark/recompute.py` runs with `python -I` on the golden raw data and agrees with
  `Core.Benchmark.Stats` on it (D9).
- **B7.** The quick validation fits in 180 s on the repo image with a real provider key; replay mode is the
  deterministic fallback (D12).

## Baseline (T001, 2026-10-31)

Fresh container `signalnoir-010` (image `congenial-waffle-iris:latest`, repo mounted at
`/home/irisowner/dev`, `master` at 9adfc41 plus the 010 specification), 274 classes compiled at start,
Simulator web application created with `SignalNoir.Sim.Setup.EnsureWebApplication()`.

- Full recursive suite: **436 methods, 436 passed, 0 failed** (a clean single run).
- A first pair of overlapping runs showed 2 failures, both in `Tests.Gates.TestGateG1`. Cause found:
  `^SignalNoir.Config("simBaseUrl")` had been set on the instance, and with it set the Simulator Tools
  take part in the plasma Order's investigation and the gate's expected Mapping no longer comes out. With
  the setting empty the gate passes (2 of 2). **Consequence for 010:** tests that need the base URL set
  it in `OnBeforeAllTests` and restore it in `OnAfterAllTests`; the baseline suite must run with it empty.
  Running two suites at once on one instance is not supported (shared extents).
- `tests/sim-contract/captures/*.json` are rewritten by the Simulator contract tests when the suite runs
  on the mounted directory (they were already modified in the working tree before this work). They are
  not part of this feature and are not committed.
- The exec client times out on a long suite while the suite goes on; the result is read from
  `%UnitTest_Result` by polling until the instance stops growing.

## Implementation log (2026-11-01, container `signalnoir-010`)

- **B1 resolved differently.** No `Map`/`Forward` is needed: the benchmark routes are plain `Route`
  entries in `Api.Dispatch.UrlMap` whose methods delegate to `Api.BenchmarkDispatch`; the handlers return
  `{status, headers, body}` and are tested without HTTP, like the other dispatch tests.
- **B2.** `Runner.Drive` runs in its own `Job`; a per-run lock (`^SignalNoir.BenchmarkDrive(runId)`) makes a
  second driver exit at once; `Runner.Resume` (the scheduled task) re-drives a running run whose heartbeat
  is older than 90 s. `Tests.Application.Benchmark.TestBenchmarkTask` covers stale, live, late and completed
  runs.
- **B3 resolved without touching 006.** The coded reason is on the Case's Dossier: `Core.DossierReason`
  turns the free "provider unavailable" text into `provider_unavailable`, stored in `DossierRecord.reason`.
  `CaseFacts` reads that, never the text of `InvestigationRecord.outcomeReason`.
- **B5.** Compiling the two new persistent classes in the mounted container wrote their Storage blocks into
  the files; they are committed with the classes.
- **B6 done.** `scripts/benchmark/recompute.py` and the ObjectScript `Stats` agree on
  `tests/benchmark/golden` (the Python tests and `TestStats.TestTheGoldenRowsAreReproduced`).
- **Tooling finding.** A long test run through `iris-agentic-dev exec` is killed when the client times out
  (`<DISCONNECT>`); start suites with `Job ##class(%UnitTest.Manager).RunTest(...)` and read
  `^UnitTest.Result`. Two suites must not run at once on one instance.
- **Refinement of CC-2.** `counts` and `denominator` are ranges over the repetitions, not single integers,
  because a repetition can cover fewer variants; see contracts/contract-change-010-benchmark.md.

### Suite after US1, US3 and the Core of US2 and US4 (2026-11-01)

Full recursive suite on the fresh container: **531 methods, 531 passed, 0 failed** (baseline 436, plus 95
new methods). New classes: `Core.Benchmark` (Seed, RunPolicy, Scorer, Stats, Guarantees and the no-I/O
scan, 45 methods), `Application.Benchmark` (records, store, case opening, lifecycle, pinned versions, runner,
task, answer keys, case facts, automatic approval, 46 methods), `Api.TestBenchmarkApi` (4 methods). The
Python tests of `scripts/benchmark/recompute.py` pass (9). Not yet written: `TestScoringEndToEnd` (T034),
the report builder and its endpoints (T041 to T044).

### Suite after the report builder (2026-11-01)

Full recursive suite: **541 methods, 541 passed, 0 failed**. New: `ReportBuilder` (build, store once, report,
comparison), `TestReport` (7), `TestScoringEndToEnd` (1), the report and comparison cases of `TestBenchmarkApi`
(2). The runner now stores the final report before it marks the run completed, and fails the run with
`report_error` if the report cannot be built.

### Suite at the end of the code that does not wait for people (2026-11-01)

Full recursive suite on the fresh container: **599 methods, 599 passed, 0 failed** (baseline 436). Scripts:
`tests/benchmark/test-check-freeze.sh`, `tests/benchmark/test-quick-validate.sh` and
`scripts/benchmark/test_recompute.py` pass; the console's `no-replay-entry` test passes (3).

Findings worth the reviewers' time:

- **The rules baseline, live.** In the gate (`TestGateG4`), the baseline run against the Simulator-backed Tools chose
  `HOLD` ("partner unstable") for `P8b-tune-01`, where with local Tools (`TestGateG1`) it chose the plasma Mapping.
  The Partner's failure history in this throwaway container is long, so part of it is the environment, but it is
  also what the baseline does with a noisy history, which is what its review (T055) is for. The gate therefore
  checks that the Case was decided and scored, not what the baseline chose.
- **A wrong HOLD is incorrect but sent nothing**, so it is not a wrong effect (`Scorer`, `contracts/scoring.md`).
- **Replay** resolves `@ev:<source>` references only for recordings by reference case; the older recording by
  Order id (006) is played as it is, because `TestProposerModes` pins that an answer with unresolved tokens is
  refused.
- **One flaky test was found and fixed:** `TestRunnerObserves.TestACaseThatDoesNotDecideInTimeIsNotDecided`
  assumed two steps were enough. One earlier failure of `TestReport.TestRepetitionsGiveARangeAndAVariantCountsOnce`
  in a combined run did not repeat in 3 further runs and has no known cause; it is noted here, not explained.
- **The reference run needs test-set variants for the clean controls and the Dossier case too** (a reference run
  takes test variants only): added to T054.

### Quickstart walked (T074, 2026-11-01, container `signalnoir-010`, over real HTTP)

- Steps 1 and 7 (Core suites, Replay) and 3 to 5 (Cases outside a run, automatic Approval, scoring) are pinned by
  the suites above. Steps 2, 8 and the error paths were walked with `curl` against the running application.
- `POST /benchmark-runs` (rules, one control and `P8b-tune-01`) answered `202` with the run; a second `POST` while it
  ran answered `409`; `GET /benchmark-runs/{id}` followed it to `completed`; `GET …/report` answered `200` with
  both parts; `GET /benchmark-reports?runId=&runId=` over two completed runs answered `200` with 4 agent-decision
  rows and 12 guarantee rows (6 per run, tagged by run), one id answered `400`, an unknown one `404`.
- **Time.** The first run took about two minutes because its first read of the Origin feed worked through the
  backlog this container's Simulator holds from earlier tests; the second, identical run took **6 s**. A fresh
  installation has an empty feed. The quick validation (three Cases) therefore fits its three minutes with room
  (B7 still wants a measurement with a real key, T069).
- `scripts/quick-validate.sh` against the real application chose `replay` (no provider configured), created
  nothing and failed at once with the application's own message, because the reserved variants its request names
  do not exist yet. That is the right failure.
- The agent-decision part of that run shows the baseline's `HOLD` for `P8b-tune-01` (scored incorrect, no wrong
  effect); see the finding above.

### Review of the diff against the Constitution (T075)

Checked by search over the new code, and by the suites: **I** `Core.Benchmark` references nothing outside the Core and is
scanned for I/O by `TestCoreHasNoIo`; the Simulator is reached only through `Interop.SimulatorHttp`, and
`TestNoCrossReference` passes. **II** no Tool and no Action added; the answer key is data compared by canonical value.
**III** the run only pins the versions the one Validator uses. **IV** the actor `benchmark` is admitted only for a Case
whose run is `running`, on both paths (`TestAutomaticApproval`); the runner and the report builder reference no
approval or transition (scanned). **V** the runner writes only run and item records; the one thing it causes in a Case
is the product's own intake opening it. **VI** untouched. **VII** "not decided" and "not exercised" are values with a
reason; a refusal is a 400/404/409. **VIII** same Tools for both modes, freeze checked at creation, at the first step and
in CI, Replay and touched Cases outside every metric, roles recorded and enforced. **Platform constraints**: no
`api_key`, password or secret in any new runtime file, report or script; every datum is labelled synthetic;
nothing in the runtime names iris-agentic-dev. No violation found. Two caveats stay open and are named above: the
heuristics behind `staleExecutions` and `resentBeforeReconcile` have no failure-data test, and the one unexplained
flake.
