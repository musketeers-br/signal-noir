# Quickstart: validate feature 010

Runnable checks that prove the feature end to end, in the order a reviewer would run them. Nothing here
needs a real provider key except step 6. Contracts and rules are linked, not repeated:
[scoring](./contracts/scoring.md), [data model](./data-model.md), [contract change](./contracts/contract-change-010-benchmark.md).

## Prerequisites

- A fresh container from the repo image, compiled (three passes), the Simulator web application created
  with `SignalNoir.Sim.Setup.EnsureWebApplication()`, and the Simulator base URL configured
  (`SN_SIM_BASE_URL`, or `^SignalNoir.Config("simBaseUrl")` on a dev instance).
- iris-agentic-dev pointed at it (`--container`, `--web-port`, namespace `IRISAPP`).
- For the reference path: the freeze commit exists (`Benchmark.Data.Freeze`), the reviews are recorded,
  and the reserved variants have replaced the two placeholders.

## 1. Pure Core suites (no HTTP, no persistence)

Run `SignalNoir.Tests.Core.Benchmark` (Seed, RunPolicy, Scorer, Stats, FreezeCheck, Guarantees, and the
static scan that the Core has no I/O). Expected: all green, including the golden file for `Stats`.

```sh
iris-agentic-dev exec --container <name> --web-port <port> -n IRISAPP \
  'set ^UnitTestRoot="/home/irisowner/dev/tests" do ##class(%UnitTest.Manager).RunTest("SignalNoir/Tests/Core/Benchmark","/noload/nodelete/recursive")'
```

Application and API suites live in `SignalNoir.Tests.Application.Benchmark` and
`SignalNoir.Tests.Api.TestBenchmarkApi`; the gate in `SignalNoir.Tests.Gates.TestGateG4`. The full run is
`RunTest("SignalNoir","/noload/nodelete/recursive")`.

## 2. A run in each mode over the same scenarios (US1, US4)

Create one run in `rules` and one in `agent` (or `replay` when there is no key) over `P5` and `P8` tuning
variants, `repetitions = 2`, then read each report and the comparison:

```
curl -s -X POST $BASE/benchmark-runs -H 'Content-Type: application/json' \
  -d '{"mode":"rules","purpose":"benchmark","repetitions":2,"seed":11,
       "scenarios":[{"family":"P5","set":"tuning"},{"family":"P8","set":"tuning"}]}'
curl -s $BASE/benchmark-runs/$RUN
curl -s $BASE/benchmark-runs/$RUN/report
curl -s "$BASE/benchmark-reports?runId=$RUN_RULES&runId=$RUN_AGENT"
```

Expected: `202` with `Location`; `progress` moves from `casesPlanned` to `casesTerminal`; the run ends
`completed`; the report has `agentDecision` rows per `(family, subtype, set, mode)` and a
`platformGuarantees` part with no comparative score; tuning rows are labelled development; the comparison
lists the two runs side by side. A report asked before the end answers `409`.

## 3. A Case outside a run (US1, US3)

Send an Order with no run id, with an unknown run id and with the id of a finished run. Expected: each
Case has `proposerMode = agent`, no `benchmark` provenance, and an attempt to approve as `benchmark`
through the decision endpoint answers `INVALID_ACTOR`; nothing is recorded as approved.

## 4. Automatic Approval only inside a run (US3)

Inside a running rules-mode run, a Case that needs Approval ends with an Approval by `benchmark`,
labelled automatic, naming the run; the runner issued no Approval (the static scan test pins this); a
`HOLD` Case has none. Expected: `SignalNoir.Tests.Application.Benchmark.TestAutomaticApproval` green.

## 5. Scoring cases with a known answer (US2)

`SignalNoir.Tests.Application.Benchmark.TestScoringEndToEnd` runs tuning variants whose final states are known: a
right Mapping (correct), a serum Mapping on a plasma Order blocked by the Validator (a blocked wrong
Proposal, then the right outcome), a needed review (safe), an unneeded review (unnecessary) and a provider
that is down (listed apart, with both denominators). Expected: each Case has the outcome of the table in
`contracts/scoring.md`, and the two wrong-things counts are separate columns.

## 6. The reference run and its recomputation (US5, US6)

Only after the freeze. Create the `reference` run (P5 and P8b test variants, 3 repetitions, a fixed
provider and model) and wait for `completed`:

```
curl -s -X POST $BASE/benchmark-runs -d @docs/benchmark/reference-request.json
```

Then, outside IRIS:

```
python -I scripts/benchmark/recompute.py docs/benchmark/reference-report.json
sh scripts/benchmark/check-freeze.sh
```

Expected: 30 agent investigations plus controls and the Dossier case in the raw rows; every metric a
range with its count and denominator; `recompute.py` reports "report matches raw data"; `check-freeze.sh`
reports no frozen file changed; `development = false` and `publishableAsReference = true`. Changing one
frozen input (a policy value, the prompt version) and creating a `reference` run gives `development =
true` with the reason, and `publishableAsReference = false`.

## 7. Replay never counts (US7)

Run a `replay` run next to a real one. Expected: the replay Cases carry `replay = true` and
`countsInMetrics = false`, are in no count, denominator, latency or cost, and a comparison that names the
replay run answers `400 VALIDATION_FAILED`.

## 8. Quick validation (US8)

```
time sh scripts/quick-validate.sh
```

Expected: three Cases (clean, P5/P8b, Dossier), each `matches_reference` or `diverged` with a reason,
exit status 0 only when all match, wall time under 180 s, and a run with purpose `quick_validation` that
never appears in a reference or benchmark comparison.

## 9. Gate G4

`SignalNoir.Tests.Gates.TestGateG4` (live): quick validation passes in replay mode, a rules-mode run completes with a
report, and a reference-purpose run over tuning variants is refused. Run the full recursive suite in a
fresh container; the count is recorded in research.md when it is run.
