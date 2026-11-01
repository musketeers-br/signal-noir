# Implementation Plan: Benchmark and Reference Run

**Branch**: `010-benchmark-and-reference-run` | **Date**: 2026-10-31 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/010-benchmark-and-reference-run/spec.md`

## Summary

Build the instrument that tests the thesis: a `BenchmarkRun` that opens real Cases from Simulator
scenarios in one mode, scores each against a pre-declared answer key, and publishes a two-part report
(agent decision, platform guarantees) with counts, denominators, ranges over repetitions and the raw rows,
so anyone can recompute it. The scoring, the statistics, the seed derivation, the run rules and the
"is this run development data?" decision are **pure Core** code. The runner is an application service that
reaches the Simulator only over its HTTP contract and **only observes**; the one Approval inside a run stays
where 007 put it (the process that drives the Case) and is tightened so it exists only for a run that is
`running`. Frozen setup, independence and used-set declarations are committed, versioned data checked at run
time and in CI. A reference run (5 variants × 2 families × 3 repetitions = 30 Agent investigations, plus
controls and the Dossier case), a recorded reference result, a Replay that never counts, and a three-minute
quick validation complete it.

Verified on the live instance before planning (research V1–V4): the Simulator already carries `runId` to the
feed, a Case copies it, and today **nothing checks that the run exists** and the mode is always `agent`. That
gap is what the run directory (D2) closes.

## Technical Context

**Language/Version**: ObjectScript on the repo image (`iris --version` reports 2026.2.0.221; the project
target for AI Hub is build 154, 001-V1). Nothing in 010 calls the AI Hub API directly: the Agent runs
through the existing `Proposers.Agent`.

**Primary Dependencies**: `%RegisteredObject` and `%DynamicObject`/`%DynamicArray` in the Core;
`%Persistent` for two records; `%CSP.REST` for the API; `%Net.HttpRequest` only through the existing
`Interop.SimulatorHttp`; `%UnitTest`. Python standard library for `scripts/benchmark/recompute.py`; POSIX
shell and curl for `quick-validate.sh` and `check-freeze.sh`. No new runtime dependency.

**Storage**: two persistent classes (`BenchmarkRunRecord`, `BenchmarkItemRecord`); committed XData for the
answer keys, roles, reviews, used-set declarations, the freeze and the recorded reference result; the
published report and raw data as files under `docs/benchmark/`.

**Testing**: `%UnitTest` through iris-agentic-dev on the live instance; the Core suites need no HTTP or
persistence; application suites use `Tests.Fakes` (a fake `RunDirectory`, `ScriptedProposer`, the existing
fakes); a live gate (`TestGateG4`) against the Simulator. A golden file shared by the ObjectScript `Stats`
tests and the Python recomputation. TDD: each task starts with its failing test.

**Target Platform**: the single `iris` container; the quick validation and the freeze check run from the
host or CI with POSIX shell.

**Project Type**: single IRIS/IPM project: a new Core package, a new Application package, one API class, one
task, two scripts, and six small edits in files of earlier features (listed in
[contracts/coordination-010.md](./contracts/coordination-010.md)).

**Performance Goals**: reference run (≈ 40 investigations, one at a time) ≈ 15 minutes; quick validation
≤ 180 s (spec 3 min); report build for 40 Cases well under a second (SC of the spec has no stricter bound).

**Constraints**: Core has no I/O (static scan); the runner never approves, writes a Case or a Proposal
(static scan); one run at a time; Replay never counted; frozen inputs checked at run start and in CI; no
change to the frozen contract without the contract-change proposal; no new Action, state, error code or
actor; all data synthetic; no secret in a report or raw data; the code of this feature is written after
2026-10-26 (calendar gate satisfied).

**Scale/Scope**: 4 run modes of work (rules, agent, replay, quick); reference run 30 investigations + 5
controls/dossier; ≈ 12 Core test classes, ≈ 8 application suites, 1 API suite, 1 gate; about 25 tasks.

## Constitution Check

*GATE: passed before Phase 0; re-checked after Phase 1 (below).*

- [x] **I. Pure Core** — scoring, statistics, seed, run rules, freeze/independence decision and guarantee
  evaluation are in `Core.Benchmark.*` with no I/O (static scan test, like 004's). The runner and report
  builder are application; they call the Core and copy no rule. The Simulator is reached only over HTTP
  through `SimulatorHttp` (D1, D4). The new port `RunDirectory` is owned by the Core.
- [x] **II. Closed Action Catalog / Read-Only Agent** — no new Action; the Agent's Tools are untouched; the
  runner is not an Agent Tool. Payloads stay data. No runtime code execution: the answer key is data
  compared by `Core.Canon`, never evaluated.
- [x] **III. One Validator** — every Proposal in a run, in any mode, goes through the same Validator; the
  run only pins the policy and Mapping versions (`Store.For(run)`, already tested). Rules and Agent share
  Tools, Evidence and protections (FR-011).
- [x] **IV. Human Authority** — Automatic Approval stays the single relaxation, only for a Case whose run is
  `running` (D2: the directory refuses unknown, ended or absent runs; the actor `benchmark` is refused for a
  Case outside a run through every path). The runner issues none. The automatic Approval is revalidated like
  a human one (007, unchanged).
- [x] **V. Case as Source of Truth** — the runner never writes a Case; the only Case change 010 causes is
  the existing intake opening a Case, now with the run's mode, inside `CaseService`'s transaction. The run
  record is not a Case record; its own writes are single-record and use a lock for the one-run rule.
- [x] **VI. Effects at Most Once** — untouched. The report's platform part *reports* duplicate Receipts and
  stale executions; it does not weaken or bypass any gate.
- [x] **VII. Honest Outcomes** — "not decided" is a value with a reason, not a fifth score; a guarantee not
  exercised is `null`, not a pass; a partial report is never presented as final; a refusal is a 400/409,
  never a success; fact (counts), diagnosis (outcome) and absence (not decided, not exercised) are separate
  fields.
- [x] **VIII. Honest Measurement** — the whole feature. Same Tools and protections for both modes; setup
  frozen in one commit and checked at run time and in CI; Replay excluded from every metric; all outcomes
  published with counts, both denominators, dispersion, latency, cost and raw rows; repetitions never counted
  as independent cases; tuning vs test; the roles of key and baseline recorded and enforced as
  *development* when one person holds both; reviews recorded and shown in the report by status, never
  blocking (Constitution 2.0.0).
- [x] **IX. Verifiable Increments** — sliced by behavior (a run that opens Cases in a mode → scoring → report
  → freeze → reference → replay and quick validation), each with its test; the dependency on the baseline
  and the review is explicit.
- [x] **Platform Constraints** — synthetic data labelled in runs and reports; secrets only at runtime (the
  report carries provider and model, never a key); no image is pushed; no untested provider is announced as
  validated (the report warns when provider or model differs from the reference).
- [x] **iris-agentic-dev** — platform claims were verified on the live instance (research V1–V4); the rest
  is in the verification backlog B1–B7 with the task that uses each; nothing in the runtime depends on it
  (the freeze source check is a repository script, not iris-agentic-dev).

**Post-design re-check (Phase 1)**: unchanged; no violation to track. Two points were examined and
resolved rather than waived: (1) the edit of `CaseService.NewCase` is in another person's file but moves no
rule out of the Core (it calls a port); (2) `RunDirectory` adds a lookup at Case opening, which is I/O in the
application layer, not the Core.

## Project Structure

### Documentation (this feature)

```text
specs/010-benchmark-and-reference-run/
├── plan.md                                  # this file
├── research.md                              # decisions D1–D14, verification V1–V4, backlog B1–B7
├── data-model.md                            # records, port, Core classes, committed data, state machine
├── quickstart.md                            # runnable validation, in review order
├── contracts/
│   ├── scoring.md                           # classification and statistics rules (the evaluator)
│   ├── contract-change-010-benchmark.md     # CC-1…CC-7: additive changes to the frozen contract
│   └── coordination-010.md                  # edits in others' files, work only others can do
├── checklists/requirements.md               # spec quality (passed)
└── tasks.md                                 # /speckit-tasks — not created here
```

### Source Code (repository root)

```text
src/SignalNoir/
├── Core/
│   ├── Port/RunDirectory.cls                # NEW  Find(runId) → run summary | ""
│   └── Benchmark/                           # NEW  pure, no I/O
│       ├── Seed.cls  RunPolicy.cls  Scorer.cls  Stats.cls  FreezeCheck.cls  Guarantees.cls
├── Application/
│   ├── Model/BenchmarkRunRecord.cls         # NEW
│   ├── Model/BenchmarkItemRecord.cls        # NEW
│   ├── Benchmark/                           # NEW
│   │   ├── RunStore.cls                     #   implements Core.Port.RunDirectory
│   │   ├── RunService.cls                   #   create / get / list; one-run lock; pins
│   │   ├── Runner.cls                       #   Step / Drive; observe only
│   │   ├── ReportBuilder.cls                #   cases → Scorer/Stats/Guarantees → report
│   │   └── QuickValidation.cls              #   three reference cases, compare to ReferenceResult
│   ├── CaseService.cls                      # EDIT NewCase, two automatic-Approval sites (E1, E2)
│   └── ResolutionValidator.cls              # EDIT RunFor reads the run's pins (E3)
├── Benchmark/Data/                          # NEW  committed XData
│   ├── Base.cls  AnswerKeyTuning.cls  AnswerKeyTest.cls  Roles.cls  Reviews.cls
│   └── SetUsage.cls  Freeze.cls  ReferenceResult.cls
├── Api/
│   ├── BenchmarkDispatch.cls                # NEW  the contract's benchmark routes
│   └── Dispatch.cls                         # EDIT UrlMap: two Map entries (E5)
├── Proposers/Replay.cls                     # EDIT key by reference case (E4)
└── Tasks/BenchmarkTask.cls                  # NEW  re-drive a stale running run

tests/SignalNoir/Tests/
├── Core/Benchmark/                          # Seed, RunPolicy, Scorer, Stats, FreezeCheck, Guarantees,
│                                            # TestCoreHasNoIo, golden data
├── Application/Benchmark/                   # CaseOpening, AutomaticApproval, RunLifecycle, RunnerObserves,
│                                            # ScoringEndToEnd, Report, Replay, QuickValidation
├── Api/TestBenchmarkApi.cls
├── Fakes/FakeRunDirectory.cls
└── Gates/TestGateG4.cls

scripts/
├── quick-validate.sh                        # NEW  one command, ≤ 180 s, exit status by result
└── benchmark/
    ├── recompute.py                         # NEW  independent recomputation from raw rows
    └── check-freeze.sh                      # NEW  frozen files vs the freeze record (CI)

docs/benchmark/                              # NEW  published after the reference run
├── reference-request.json  reference-report.json  raw-cases.json  README.md
```

**Structure Decision**: single IRIS project, extending the existing layers. The new Core package follows
`Core.Validator`'s style (pure classes, `%DynamicObject` in and out); committed data follows `Sim.Catalog.*`
and 004's fixtures (XData, loaded by class); the API follows the thin-dispatch style of `Api.Dispatch`.

## Engineering Standards (how the approach meets them)

- **SOLID / hexagonal.** `RunDirectory` is a port owned by the Core; `RunStore` is the adapter. `Scorer`,
  `Stats`, `FreezeCheck` and `Guarantees` each have one reason to change (the evaluator is reviewed as a
  unit). `Runner` depends on the Simulator only through `SimulatorHttp`.
- **TDD.** Task order is test first; the Core suites need no persistence and run in seconds.
- **Errors as values.** Every service returns `Core.Result`; refusals are 400/404/409 values; "not
  decided" and "not exercised" are values.
- **YAGNI.** One run at a time, items sequential, no `benchmark-suites`, no export endpoint, no console
  entry point, no recorded-response editor.
- **Contract-first.** Every need beyond the frozen contract is in `contract-change-010-benchmark.md`;
  nothing is adjusted silently.

## Open decisions (need a person; each has a default so work can start)

| # | Question | Default taken in this plan | Who |
|---|---|---|---|
| Q1 | How long may a Case of a run stay undecided before it is *not decided* (per item deadline)? | agent 180 s, rules/replay 60 s, counted from the Case opening, to decide; a Case that decided in time and is Approved or Executing gets the execution lease more (`SN_AI_LEASE_SECONDS`, 300 s) so its effect is scored (amended 2026-11-01, agent rehearsal); a run's own deadline is items × (deadline + lease) + 120 s | Henrique |
| Q2 | Evidence for `restart` and `late worker`: a scenario cannot restart IRIS or race a worker. | the recovery suite of 008, recorded with its commit in `ReferenceResult` and shown as `source: recovery_suite`; `not exercised` when absent | Henrique + Henry |
| Q3 | Where is a set declared *used*? | a committed line in `Benchmark.Data.SetUsage` (auditable, not undoable silently), not an endpoint | Henrique + José |

The first two also appear in `coordination-010.md` and in the contract change (CC-4).

## Dependencies and risks

- **Critical path (calendar).** Functional freeze 2026-11-05. Order is fixed by the board: baseline and
  evaluator ready → one freeze commit → reference run → report. The code of this feature can finish
  ahead of that order; the reference run cannot. José's review no longer blocks the freeze (Constitution
  2.0.0): it is recorded when done and the report shows its status.
- **Reserved variants.** `P5Test` and `P8Test` are one-variant placeholders; ten real variants and their
  answer keys are required before the freeze. If they are late, only a development reference can exist, and
  the report will say so rather than claim more.
- **Baseline.** `Proposers.Rules` still ignores synonyms (open since 004, Henry wave 4); a weak baseline is
  exactly what the review exists to catch, and what the thesis cannot survive.
- **Five variants and p95.** With n = 5 per repetition the p95 equals the maximum. The report states this.
- **Files of other tracks.** Six small edits (E1–E6) need Henry's agreement first, as in 004. Until then
  the work can proceed against `Tests.Fakes.FakeRunDirectory`.
- **Storage blocks.** New persistent classes carry generated Storage blocks; the unrelated `Precedent*`
  blocks that appear when compiling must not be committed (B5).
