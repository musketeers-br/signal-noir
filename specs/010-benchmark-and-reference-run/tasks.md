---
description: "Task list for feature 010 — Benchmark and Reference Run"
---

# Tasks: Benchmark and Reference Run

**Input**: Design documents from `specs/010-benchmark-and-reference-run/`

**Prerequisites**: [plan.md](./plan.md), [spec.md](./spec.md), [research.md](./research.md),
[data-model.md](./data-model.md), [contracts/](./contracts/), [quickstart.md](./quickstart.md)

**Tests**: MANDATORY (Constitution, TDD; Principle IX). Every implementation task is preceded by a task
that writes the failing test. ObjectScript tests run on the live instance through iris-agentic-dev
(`iris-agentic-dev exec --container <name> --web-port <port> -n IRISAPP 'set ^UnitTestRoot="/home/irisowner/dev/tests" do ##class(%UnitTest.Manager).RunTest("SignalNoir/Tests/<path>","/noload/nodelete/recursive")'`).
Tests that need the Simulator skip when it is not reachable, as `Tests.Gates.TestGateG1` does; run them
with the Simulator web application created (`SignalNoir.Sim.Setup.EnsureWebApplication()`) and the base URL
set (`SN_SIM_BASE_URL` or `^SignalNoir.Config("simBaseUrl")`).

**Calendar gate**: satisfied (code allowed from 2026-10-26). **Functional freeze: 2026-11-05.**

**Owners** (from `contracts/coordination-010.md` and the board): Henrique = runner, scoring, report,
answer keys, reserved variants, freeze, reference run. Henry = the rules baseline, and agreement to edits
E1–E5 in his files. José = review of the baseline and evaluator, and E6 (the port). Tasks marked
**[edit En]** change a file of another feature and MUST NOT start until T002 records that owner's agreement.
Tasks marked **[person]** can be done only by the named person and are not codeable by an agent.

**Write zone**: new — `src/SignalNoir/Core/Benchmark/**`, `Core/Port/RunDirectory.cls`,
`src/SignalNoir/Application/Benchmark/**`, `Application/Model/Benchmark{Run,Item}Record.cls`,
`src/SignalNoir/Benchmark/Data/**`, `Api/BenchmarkDispatch.cls`, `Tasks/BenchmarkTask.cls`,
`tests/SignalNoir/Tests/{Core,Application,Api,Gates}/**Benchmark**`, `tests/SignalNoir/Tests/Fakes/FakeRunDirectory.cls`,
`tests/benchmark/**`, `scripts/quick-validate.sh`, `scripts/benchmark/**`, `docs/benchmark/**`,
`specs/010-benchmark-and-reference-run/**`. Edits in existing files: `Application/CaseService.cls` (E1, E2),
`Application/ResolutionValidator.cls` (E3), `Proposers/Replay.cls` (E4), `Api/Dispatch.cls` (E5),
`contracts/openapi-signalnoir.yaml` and `ui/src/lib/api/types.ts` (T011, after agreement),
`docs/specify-prompts/PARALELISMO.md` (T072). Integration files (`.github/workflows/**`, `README.md`,
`Dockerfile`, `module.xml`) are only requested in T073.

**Conventions used by every task**

- Core classes under `Core/Benchmark/` do no I/O: no globals, no `%Persistent`, `%Net`, `%File`, SQL, `$ZF`,
  `$HOROLOG`, `$ZTIMESTAMP`, `$NOW`, `$RANDOM`, device commands. Time and every input arrive as arguments.
- Scoring and statistics follow [contracts/scoring.md](./contracts/scoring.md) exactly; the table of
  `Scorer` is the table of that file.
- The runner and the report builder never reference `RecordApproval`, `Decide`, `ApplyTransition` or any
  `CaseService` command (T003 pins it).
- Services return `SignalNoir.Core.Result`; refusals are values. API errors: 400 `VALIDATION_FAILED`,
  404 `NOT_FOUND`, 409 `INVALID_TRANSITION` (plan D13).
- Open decisions Q1–Q3 take their defaults (plan): item deadline 180 s agent / 60 s rules and replay (to
  decide; a Case executing its decision gets the lease more, T077), run deadline = items × (deadline + lease)
  + 120 s; restart and late-worker evidence from the recovery suite; used sets
  declared by commit in `Benchmark.Data.SetUsage`.
- After each **[edit]** task the whole suite on `master` stays green
  (`RunTest("SignalNoir","/noload/nodelete/recursive")`).
- Commit only files of this feature. Do not commit Storage-block diffs of unrelated classes
  (`PrecedentIndexState.cls`, `PrecedentRecord.cls`).

## Format: `- [ ] [ID] [P?] [Story] Description with file path`

---

## Phase 1: Setup

- [x] T001 Confirm the baseline on a fresh container from `master`: compile (three passes), create the Simulator web application, run the full recursive suite, and record the count (expected 416 passing, 0 failing) under a new "Baseline" heading in specs/010-benchmark-and-reference-run/research.md; if it is not green, stop
- [x] T002 [person: Henrique with Henry and José] Walk specs/010-benchmark-and-reference-run/contracts/coordination-010.md with Henry (E1–E5, and that he does not read the reserved variants before the freeze) and José (E6, the review scope in contracts/scoring.md), and contracts/contract-change-010-benchmark.md (CC-1…CC-7) with both; record each decision, and that Q1–Q3 took their defaults, at the end of those two files. Do not start any **[edit]** task or T011 before this is recorded

---

## Phase 2: Foundational (blocks every story)

**Purpose**: the port, the two records, the directory and the guard tests every story needs.

- [x] T003 [P] Write guard tests in tests/SignalNoir/Tests/Core/Benchmark/TestCoreHasNoIo.cls: (a) every class in package `SignalNoir.Core.Benchmark` contains none of the forbidden tokens of Conventions (scan `%Dictionary.CompiledMethod` implementations, as tests/SignalNoir/Tests/Core/Validator/TestDeterminismNoIo.cls does); (b) the implementations of `SignalNoir.Application.Benchmark.Runner` and `ReportBuilder` do not contain `RecordApproval`, `Decide`, `ApplyTransition`; both pass vacuously now and fail on any later violation
- [x] T004 [P] Write tests/SignalNoir/Tests/Application/Benchmark/TestRunDirectorySeam.cls: `SignalNoir.Core.Port.RunDirectory` exists, declares `Find(runId)` returning a `%DynamicObject` or `""`, and `SignalNoir.Tests.Fakes.FakeRunDirectory` and `SignalNoir.Application.Benchmark.RunStore` both extend it; fails until T005, T006 and T010
- [x] T005 **[edit E6]** Create src/SignalNoir/Core/Port/RunDirectory.cls (abstract port: `Find(runId As %String) As %DynamicObject` returning `{runId, mode, status, purpose, policyVersion, mappingVersion}` or `""`; document that it is read-only and I/O belongs to the adapter)
- [x] T006 [P] Create tests/SignalNoir/Tests/Fakes/FakeRunDirectory.cls (extends the port; `Add(summary)` stores runs in a local array; `Find` returns the object or `""`)
- [x] T007 Write tests/SignalNoir/Tests/Application/Benchmark/TestBenchmarkRecords.cls: both records save and reload; `runId` is unique (a second save raises); `status` defaults to `created`; item `(runId, itemNo)` is unique; every field of data-model.md exists with its type
- [x] T008 Create src/SignalNoir/Application/Model/BenchmarkRunRecord.cls and BenchmarkItemRecord.cls per specs/010-benchmark-and-reference-run/data-model.md (indexes: `runId` unique; item `(runId, itemNo)` unique, `caseId`, `scenarioInstanceId`); compile in a fresh container (three passes) and commit the generated Storage blocks of these two classes only (verification B5)
- [x] T009 Write tests/SignalNoir/Tests/Application/Benchmark/TestRunStore.cls: `Find` returns `{runId, mode, status, purpose, policyVersion, mappingVersion}` for a stored run, `""` for an unknown, empty or null id, and reflects a status change immediately
- [x] T010 Create src/SignalNoir/Application/Benchmark/RunStore.cls implementing `Core.Port.RunDirectory` over `BenchmarkRunRecord` (read-only, SQL by `runId`); T004 and T009 pass
- [x] T011 [person: Henrique] After T002: apply CC-1…CC-7 to contracts/openapi-signalnoir.yaml and the matching types in ui/src/lib/api/types.ts in one commit, then run `uv run --with jsonschema --with pyyaml python contracts/tools/validate_fixtures.py` (still 25 valid) and `npm test` in ui/ (still green); no fixture is edited by hand

**Checkpoint**: the port, the records and the directory exist; the guard tests are in place.

---

## Phase 3: User Story 1 — A run in one mode over a scenario set (P1) 🎯 MVP

**Goal**: create and start a run in `rules`, `agent` or `replay`; the Simulator creates the tagged
instances; Cases copy the run's mode; the run reaches `completed` or `failed`; a Case outside a valid run is
unchanged.

**Independent test**: create a rules run over a few variants and read its progress to the end; send Orders
with no run id and with an unknown run id and read the mode and provenance of their Cases.

- [x] T012 [P] [US1] Write tests/SignalNoir/Tests/Core/Benchmark/TestSeed.cls: golden values for `Seed.For(baseSeed, family, variant, repetition)` (fixed input → fixed integer in 0…2³¹−1), same input twice → same value, any one changed input → a different value, repetition 1 and 2 differ
- [x] T013 [P] [US1] Write tests/SignalNoir/Tests/Core/Benchmark/TestRunPolicy.cls: `Validate(request, catalog)` refuses empty scenarios, unknown family, unknown variant, `repetitions` outside 1–10, a malformed mode or purpose, and accepts a valid request (FR-001); `purpose=reference` with any tuning variant or a mix is refused (plan D8); `Next(status, event)` allows created→running→completed|failed and refuses every other move (FR-002); `StartAllowed(activeRuns)` refuses when one is `created` or `running` (FR-005)
- [x] T014 [US1] Implement src/SignalNoir/Core/Benchmark/Seed.cls: first 31 bits of `SHA-256("base|family|variant|repetition")`, pure; T012 passes
- [x] T015 [US1] Implement src/SignalNoir/Core/Benchmark/RunPolicy.cls (`Validate`, `Next`, `StartAllowed`, each returning `{ok, errors[]}` values); T013 passes
- [x] T016 [US1] Write tests/SignalNoir/Tests/Application/Benchmark/TestCaseOpening.cls using `FakeRunDirectory`: a `running` rules run → the Case has that `runId`, `proposerMode=rules`, `replay=0`; a `running` replay run → `replay=1`; an absent run id, an unknown id, and a `completed` or `failed` run → `proposerMode=agent`, empty `runId`, `replay=0`, and the raw id kept on the `OrderRecord` (FR-003); fails until T017
- [x] T017 [US1] **[edit E1]** Edit src/SignalNoir/Application/CaseService.cls `NewCase`: ask the `RunDirectory` (injectable, default `RunStore`) and set `runId`, `proposerMode` and `replay` as T016 states; leave the rest of `NewCase` untouched; the existing 003/007 suites stay green
- [x] T018 [US1] Write tests/SignalNoir/Tests/Application/Benchmark/TestRunLifecycle.cls (live Simulator): `RunService.Create` persists a run and one item per (variant, repetition) with `Seed.For` seeds and pinned `policyVersion`/`mappingVersion` (from `fixtureSet` or `Store.InForce()`, validated with `Store.For`), expands a family+set selection through `GET /scenario-catalog`, ignores `provider`/`model` in rules mode, and returns a conflict value while another run is `created` or `running`; `Get`/`List` return contract-shaped runs with progress `casesPlanned/Opened/Terminal` (FR-001, FR-002, FR-004–FR-006)
- [x] T019 [US1] Implement src/SignalNoir/Application/Benchmark/RunService.cls (`Create`, `Get`, `List`; lock for the one-run rule; calls `RunPolicy` and `Seed`; reads the Simulator catalog only through `Interop.SimulatorHttp`; generates `runId` as `run_` + 12 URL-safe characters; starts the runner through T023's `Drive` with `Job`); T018 passes
- [x] T020 [US1] Write tests/SignalNoir/Tests/Application/Benchmark/TestPinnedVersions.cls: a Case of a run pinning an older policy version validates against that version after `Store.SetInForce` moves to a newer one (FR-006), and a Case outside a run uses the version in force; fails until T021
- [x] T021 [US1] **[edit E3]** Edit src/SignalNoir/Application/ResolutionValidator.cls `RunFor`: read the run's pins through `RunDirectory` instead of returning `null`; `TestResolutionValidator` and T020 pass
- [x] T022 [US1] Write tests/SignalNoir/Tests/Application/Benchmark/TestRunnerObserves.cls (live Simulator, rules mode, tuning variants): one `Step` creates an instance with `runId`, `repetition` and the derived seed and emits it; the intake opens the Case; the item moves planned→opened→ended; the run ends `completed` with progress equal to the plan; `Step` called twice does not duplicate an instance; a Case still undecided past the item deadline becomes `not_decided` with reason `deadline`; the runner changed no Case (compare `caseVersion` before and after) (FR-007)
- [x] T023 [US1] Implement src/SignalNoir/Application/Benchmark/Runner.cls (`Step`, `Drive` loop with `heartbeatAt`; idempotent from persisted items; triggers `OriginFeed.Poll` for intake; read-only on Cases; item and run deadlines per Q1); T022 and T003(b) pass. Verify B2 first (a `Job` started from the create request keeps running after the request ends) and record the result in research.md
- [x] T024 [US1] Write tests/SignalNoir/Tests/Application/Benchmark/TestBenchmarkTask.cls: a `running` run with a stale `heartbeatAt` is re-driven; a fresh heartbeat is left alone; a run past its deadline moves to `failed` with `failureReason=deadline`
- [x] T025 [US1] Implement src/SignalNoir/Tasks/BenchmarkTask.cls (the `Tasks.Periodic` pattern; registered where the other tasks are, see `Interop/Bootstrap.cls`); T024 passes
- [x] T026 [US1] Write tests/SignalNoir/Tests/Api/TestBenchmarkApi.cls: `POST /benchmark-runs` → 202 with `Location` and a contract-shaped run; 400 `VALIDATION_FAILED` for each refusal of T013; 409 `INVALID_TRANSITION` while a run is running; `GET /benchmark-runs` (status filter, limit) and `GET /benchmark-runs/{runId}` (404 `NOT_FOUND` for unknown) validate against the schemas of contracts/openapi-signalnoir.yaml
- [x] T027 [US1] **[edit E5]** Create src/SignalNoir/Api/BenchmarkDispatch.cls (create, get, list) and add the `Map` entries for `/benchmark-runs` and `/benchmark-reports` to the `UrlMap` of src/SignalNoir/Api/Dispatch.cls; verify B1 first (Map/Forward routes these prefixes and the `/cases` routes still work); T026 passes

**Checkpoint**: a rules run over tuning variants runs to `completed` over the real Simulator; Cases outside a run are unchanged.

---

## Phase 4: User Story 2 — Honest classification of outcomes (P1)

**Goal**: every scored Case is exactly one of correct, safe review, unnecessary review, incorrect; a blocked
wrong Proposal is counted apart from a wrong effect; "not decided" is reported apart.

**Independent test**: Cases whose final states are known are scored as the table of contracts/scoring.md says.

- [x] T028 [P] [US2] Write tests/SignalNoir/Tests/Core/Benchmark/TestScorer.cls: one test per row of contracts/scoring.md Steps 0–3 (replay, touched, not-decided reasons, non-terminal, executed Action in key, wrong Action, right Action with wrong parameters — the serum Mapping on a plasma Order —, review with `reviewIsAcceptable` true and false, no effect), the blocked-wrong-Proposal vs wrong-effect counts never summed, a Case with a blocked wrong Proposal that ends correct, parameter subset match by `Core.Canon` (extra effect keys ignored, key order irrelevant), identical output on a second run of the same input (FR-014–FR-018)
- [x] T029 [US2] Implement src/SignalNoir/Core/Benchmark/Scorer.cls (`Score(key, facts)` per contracts/scoring.md, `Parameter VERSION`); T028 and T003(a) pass
- [x] T030 [P] [US2] Write tests/SignalNoir/Tests/Application/Benchmark/TestAnswerKeys.cls: every tuning variant of families P5, P8 and clean in the Simulator catalog has a key in `Benchmark.Data.AnswerKeyTuning`; each key's Actions are in the closed catalog (`Core.ActionCatalog`); `params` are objects; no key names a variant that does not exist; a variant without a key is reported by name (FR-014)
- [x] T031 [US2] [person: Henrique] Create src/SignalNoir/Benchmark/Data/Base.cls (abstract, XData `Keys` loader like `Sim.Catalog.Loader`) and AnswerKeyTuning.cls with a key for each tuning variant of P5 (4), P8 (3) and clean (5), using the real Mapping ids of `Application.Reference` fixtures; T030 passes
- [x] T032 [US2] Write tests/SignalNoir/Tests/Application/Benchmark/TestCaseFacts.cls: from persisted Cases build the facts of contracts/scoring.md — final state, executed Action and parameters, every Proposal with its verdict, `touchedByPerson` from Timeline actors `operator:*`, and the not-decided reason read from coded fields (`InvestigationRecord.outcomeReason`, `CaseRecord.reviewReason`), including the provider-unavailable path of fixture contracts/fixtures/case.review.provider-unavailable.json. Verify B3 first; if those fields are free text, record that in research.md and add the coded marker in 006's path through coordination before continuing
- [x] T033 [US2] Implement src/SignalNoir/Application/Benchmark/CaseFacts.cls (read-only; reuses the existing read side); T032 passes
- [x] T034 [US2] Write tests/SignalNoir/Tests/Application/Benchmark/TestScoringEndToEnd.cls (live Simulator, rules mode, tuning variants with known keys): a right Mapping scores correct; a variant whose first Proposal is blocked then corrected scores correct with one blocked wrong Proposal; a needed review scores safe review; an unneeded review scores unnecessary review; a provider that is down is listed apart with both denominators; the counts of each outcome match the plan

**Checkpoint**: classification is exact on known Cases and reviewable as one table.

---

## Phase 5: User Story 3 — Automatic Approval only inside a run (P1)

**Goal**: the actor `benchmark` acts only for a Case whose run is `running`; it is labelled automatic and
names the run; the runner never approves.

**Independent test**: try the actor on a Case of a run and on a Case outside a run; read the Approval record.

- [x] T035 [US3] Write tests/SignalNoir/Tests/Application/Benchmark/TestAutomaticApproval.cls (extends the cases of tests/SignalNoir/Tests/Application/TestBenchmarkApproval.cls): in a `running` run a Case needing Approval gets an Approval by `benchmark`, labelled automatic, with the run id; a Case outside a run, a Case of an unknown run and a Case whose run has `completed` or `failed` all refuse `benchmark` through `RouteProposal` and through the decision endpoint with `INVALID_ACTOR`, recording nothing as approved; a `HOLD` Case records no Approval; the automatic Approval goes through the same revalidation and deadline as a human one; the runner's static scan (T003b) still passes (FR-008–FR-010)
- [x] T036 [US3] **[edit E2]** Edit src/SignalNoir/Application/CaseService.cls at the two automatic-Approval sites (`RouteProposal` and the `Decide` path): also require `RunDirectory.Find(rec.runId).status = "running"` before an Approval by `benchmark` is recorded; T035 and the existing `TestBenchmarkApproval` pass

**Checkpoint**: Principle IV holds: the only relaxation exists only inside a running run.

---

## Phase 6: User Story 4 — A two-part report and a comparison (P1)

**Goal**: a completed run has a report with Decision of the Agent and Platform Guarantees kept apart; two
runs over the same scenarios compare side by side; the report is recomputable from its rows.

**Independent test**: run rules and agent (or replay-free fake) over the same set; read each report and the comparison.

- [x] T037 [P] [US4] Write tests/SignalNoir/Tests/Core/Benchmark/TestStats.cls and the golden file tests/benchmark/golden/stats.json (raw rows and expected rows, 2 families, 3 repetitions, 5 variants, a not-decided Case, a repetition covering fewer variants): per-repetition counts, both denominators, nearest-rank p50/p95 (with `n=5` p95 = max and the `note` says so), means, ranges across repetitions, `repetitionsCovered`, replay and touched rows excluded, the same variant never counted twice (FR-019, FR-022, FR-028)
- [x] T038 [US4] Implement src/SignalNoir/Core/Benchmark/Stats.cls per contracts/scoring.md "Statistics"; T037 passes
- [x] T039 [P] [US4] Write tests/SignalNoir/Tests/Core/Benchmark/TestGuarantees.cls: duplicate Receipts or invalid Actions executed → fail; a stale-precondition execution → P3 fail; counts of zero with Cases exercised → pass; no Case of the family in the run → `null` (not exercised), never pass; restart and late worker take their value and `source=recovery_suite` from a supplied evidence record, `null` when absent; no comparative score is produced (FR-020)
- [x] T040 [US4] Implement src/SignalNoir/Core/Benchmark/Guarantees.cls; T039 passes
- [x] T041 [US4] Write tests/SignalNoir/Tests/Application/Benchmark/TestReport.cls (live Simulator, rules mode): a completed run has `agentDecision` rows per (family, subtype, set, mode) with counts, proportions, p50/p95, tool calls and cost; clean scenarios appear as controls and not in a family score; P9 is absent unless in the run; P3 and idempotency Cases feed only `platformGuarantees`; tuning rows are labelled development; the report states provider, model, policy, Mapping, prompt, baseline and evaluator versions, set, purpose and the `cases` rows with every field of CC-3; a report asked before the run ends returns the not-ready value (FR-019–FR-024)
- [x] T042 [US4] Implement src/SignalNoir/Application/Benchmark/ReportBuilder.cls (items + `CaseFacts` → `Scorer`, `Stats`, `Guarantees`; writes `reportJson` once when the run completes; the runner calls it); T041 and T003(b) pass
- [x] T043 [US4] Write the report cases in tests/SignalNoir/Tests/Api/TestBenchmarkApi.cls: `GET /benchmark-runs/{runId}/report` → 200 contract-shaped for a completed run, 409 `INVALID_TRANSITION` before the end, 404 unknown; `GET /benchmark-reports?runId=&runId=` → 200 side by side by mode for two completed runs over the same set, 400 `VALIDATION_FAILED` for different sets, for a replay run, for a `quick_validation` run and for fewer than two ids, 404 for an unknown run (FR-021)
- [x] T044 [US4] Add the report and comparison routes to src/SignalNoir/Api/BenchmarkDispatch.cls and the comparison builder to ReportBuilder; T043 passes
- [x] T045 [P] [US4] [person: Henrique] Create scripts/benchmark/recompute.py (standard library only; reads a report JSON, recomputes counts, proportions, both denominators, nearest-rank percentiles and ranges from `cases`, exits non-zero with the differences) and scripts/benchmark/test_recompute.py that runs it on tests/benchmark/golden/stats.json and on a deliberately altered copy (must fail); run with `python -I` (verification B6; the ObjectScript and Python results agree on the golden file)

**Checkpoint**: a rules run over tuning variants ends with a two-part report; two runs compare. **MVP of the P1 stories is complete here.**

---

## Phase 7: User Story 5 — Frozen setup, separate sets, independent hands (P2)

**Goal**: inputs are frozen in one record and checked; a run that differs, over a used set, or without distinct
roles is *development*; tuning and test are kept apart.

**Independent test**: freeze, change one frozen input, run, read the status and report; read the metadata for a run whose roles are not distinct.

- [x] T046 [P] [US5] Write tests/SignalNoir/Tests/Core/Benchmark/TestFreezeCheck.cls: equal inputs and distinct roles with reviews → not development; one differing input (prompt, model, baseline, policy or Mapping digest, fixture digest, evaluator, reserved catalog digest) → development naming that input; a set in `SetUsage` → development with the reason; the same person in two of key author, baseline author, reviewer for a family → development; a missing review record for a family → development; no freeze record → development (FR-026, FR-027, FR-029)
- [x] T047 [US5] Implement src/SignalNoir/Core/Benchmark/FreezeCheck.cls (`Evaluate(freeze, current, roles, reviews, usage, selection)` → `{development, reasons[]}`); T046 passes
- [x] T048 [P] [US5] Write tests/SignalNoir/Tests/Application/Benchmark/TestFreezeData.cls: `Roles`, `Reviews`, `SetUsage`, `Freeze` and `ReferenceResult` load as JSON, reject unknown keys, and a review entry has kind, family, author, reviewer, commit and date
- [x] T049 [US5] Create src/SignalNoir/Benchmark/Data/Roles.cls, Reviews.cls, SetUsage.cls, Freeze.cls and ReferenceResult.cls (XData, empty or placeholder records marked as such) and `Application/Benchmark/Inputs.cls` that reads the current frozen inputs (`Agent.PROMPTVERSION`, `Rules.VERSION`, `Scorer.VERSION`, the `Store` fixture digests, the digests of the reserved catalog and answer keys); T048 passes
- [x] T050 [US5] Write tests/SignalNoir/Tests/Application/Benchmark/TestRunDevelopment.cls: `RunService.Create` with purpose `reference` over tuning or mixed variants is refused (400); over test variants with a changed frozen input it is created, marked development with the reason, and its report has `development=true`, `publishableAsReference=false`, `setup` with prompt, baseline, evaluator, freeze and independence (CC-5, CC-6); a frozen input changed between creation and the first step marks the run development; tuning results are reported apart labelled development; a used set (fixture `SetUsage` line) marks every later run over it (FR-025–FR-029)
- [x] T051 [US5] Wire `FreezeCheck` and `Inputs` into `RunService.Create` and the first `Runner.Step` and add `setup` and the development fields to `ReportBuilder` in src/SignalNoir/Application/Benchmark/; T050 passes
- [x] T052 [P] [US5] Create scripts/benchmark/check-freeze.sh (POSIX; compares `git hash-object` of each file listed in `Benchmark.Data.Freeze` `files` with its recorded id; exit non-zero and name the file when one differs; exit 0 with a clear "no freeze yet" message when the record is a placeholder) and tests/benchmark/test-check-freeze.sh that proves both outcomes in a temporary git repository
- [x] T053 [US5] [person: Henry] Rules baseline: make src/SignalNoir/Proposers/Rules.cls call `Core.Conditions.Matches` with `result.synonyms` of `tool.mapping_catalog` (the Order written `soro` must find the serum Mapping, as in `Tests.Gates.TestGateG1` second case), add the test pinning `requiresApproval` of `REQUEST_REVIEW` between the catalog endpoint and the verdict, and document the baseline's rules per family in docs/benchmark/baseline-rules.md (FR-012). Henry does not read the reserved variants (T054) before the freeze. Bump `Rules.VERSION`
- [ ] T054 [US5] [person: Henrique] Replace the placeholders in src/SignalNoir/Sim/Catalog/P5Test.cls and P8Test.cls with five reserved variants each (P5, P8b), covering the shapes of the tuning set without copying them, and create src/SignalNoir/Benchmark/Data/AnswerKeyTest.cls with their keys; the clean controls and the Dossier case of the reference run (docs/benchmark/reference-request.json takes family `clean` from the test set, because a reference run takes test variants only) need test-set variants too: at least clean.success, clean.partner_unavailable and clean.ambiguous_identity, with their keys; keep all of it out of Henry's reach until T056 (separate branch or local only until the freeze); extend tests/SignalNoir/Tests/Application/Benchmark/TestAnswerKeys.cls to require a key for every test variant
- [x] T055 [US5] [person: José] After T029, T038 and T053: review the rules baseline (that it was not weakened) and the evaluator (`Scorer`, `Stats` match contracts/scoring.md) and record each review (kind, family, author, reviewer, commit, date, and `automated` when an automated reviewer did it) in src/SignalNoir/Benchmark/Data/Reviews.cls; fill `Roles.cls` for P5 and P8b with who actually held each role. Under Constitution 2.0.0 this review does not block T056 or T061: whoever does it is recorded, and the report shows it as `setup.independence.reviewStatus`
- [ ] T056 [US5] [person: Henrique] The freeze commit (one commit): fill src/SignalNoir/Benchmark/Data/Freeze.cls (id, prompt version, model, baseline version, policy and Mapping digests, evaluator version, reserved catalog and answer-key digests, the `files` list with `git hash-object` ids), together with T054's reserved variants and keys and, if T055 has not filled it, `Roles.cls` (a reference run needs the roles); the record is written by `Do ##class(SignalNoir.Application.Benchmark.FreezeDraft).Print(<model>)` in IRIS (the inputs, as a reference run computes them) and `python -I scripts/benchmark/freeze_record.py --freeze-id <id> --inputs <that line>` (the blob ids of the frozen files), run last; run `sh scripts/benchmark/check-freeze.sh` (must pass); after this commit none of those files changes without a new freeze

**Checkpoint**: a run knows whether it is reference-grade; the freeze is checked at run time and in CI.

---

## Phase 8: User Story 6 — The reference run (P2)

**Goal**: publish a reference run — 5 variants × 2 families × 3 repetitions = 30 Agent investigations plus
controls and the Dossier case — with ranges, counts and recomputable raw data.

**Independent test**: run the reference purpose and count the investigations; recompute the report from the raw rows.

- [x] T057 [US6] Write tests/SignalNoir/Tests/Application/Benchmark/TestReferencePlan.cls: a `reference` request built from docs/benchmark/reference-request.json expands to 30 investigation items (5 P5 + 5 P8b variants × 3 repetitions) plus the clean controls and the Dossier case; a variant counts once in every denominator (FR-028); a repetition-short variant is reported with `repetitionsCovered`; the request requires `provider` and `model` for the agent mode; a run that failed before ending offers no reference result (FR-030)
- [x] T058 [US6] Create docs/benchmark/reference-request.json and the reference selection support in `RunService`/`RunPolicy` (reference preset: P5/test and P8b/test, `repetitions=3`, clean controls and the Dossier variant, fixed provider and model required); T057 passes
- [x] T059 [US6] Write tests/SignalNoir/Tests/Application/Benchmark/TestProviderDiffers.cls: with a `ReferenceResult` recorded, a report whose provider or model differs has `reference.differsFromReference=true` and a warning; equal → false; no recorded reference → the report says there is none (FR-023)
- [x] T060 [US6] Implement the reference comparison fields in `ReportBuilder` (src/SignalNoir/Application/Benchmark/ReportBuilder.cls); T059 passes
- [ ] T061 [US6] [person: Henrique] After T056, with a real provider key and a fixed provider and model: create the `reference` run, wait for `completed`, and save docs/benchmark/reference-report.json, docs/benchmark/raw-cases.json and docs/benchmark/README.md (how to reproduce, what the numbers are and are not, including ties and losses); run `python -I scripts/benchmark/recompute.py docs/benchmark/reference-report.json` and `sh scripts/benchmark/check-freeze.sh`; record the run id, wall time and both results in research.md. If `development=true`, say so in the README and do not present it as the reference
- [ ] T062 [US6] [person: Henrique] Fill src/SignalNoir/Benchmark/Data/ReferenceResult.cls from T061 (per reference case the final state, Action and parameters; provider and model; the recovery-suite evidence for restart and late worker with the commit it was run on, from `Tests.Recovery.TestRecoverySuite`)

**Checkpoint**: a published reference report that anyone can recompute.

---

## Phase 9: User Story 7 — A recorded response never counts (P2)

**Goal**: a Replay Case is labelled everywhere, excluded from every metric, never comparable, and not startable from the interface.

**Independent test**: run a replay Case next to real ones and read the report and the Case.

- [x] T063 [US7] Write tests/SignalNoir/Tests/Application/Benchmark/TestReplay.cls: a replay run opens Cases with `replay=1` and proposer `Replay`; `Replay` finds the recorded answer by reference case (family/variant/repetition through the item), not by `orderId`; a replay Case is in no count, denominator, latency or cost and has `countsInMetrics=false`; the label appears on the Case header and in the report rows; a comparison naming the replay run is refused (FR-031, FR-032)
- [x] T064 [US7] **[edit E4]** Edit src/SignalNoir/Proposers/Replay.cls to resolve the recorded answer from `Benchmark.Data.ReferenceResult` by the item's reference case (`orderId` → `scenarioInstanceId` → item), keeping the existing `Record`/`Propose` shape and its callers; T063 and the existing `TestProposerModes` pass
- [x] T065 [P] [US7] Add a test to ui/tests/ (Vitest) that fails if any file under ui/src creates a benchmark run with `mode` replay or offers a replay choice; run `npm test` in ui/ (FR-031)

**Checkpoint**: Replay is honest by construction.

---

## Phase 10: User Story 8 — Quick validation in three minutes (P2)

**Goal**: one command runs three reference Cases and says, for each, "matches the reference" or "diverged" with the reason, inside three minutes.

**Independent test**: run it on a clean installation and time it; run it with another model and read the reasons.

- [x] T066 [US8] Write tests/SignalNoir/Tests/Application/Benchmark/TestQuickValidation.cls (live Simulator, replay mode and a scripted proposer): a `quick_validation` run covers exactly three Cases — one clean, one P5 or P8b, one that ends in a Dossier (P9 replaces the clean one only if in the run) —; each result is `matches_reference` or `diverged` with a reason (different Action, different final state, provider or model differs); the run is never accepted into a `reference` or `benchmark` comparison; the whole run finishes within 180 s (FR-033, FR-034)
- [x] T067 [US8] Implement src/SignalNoir/Application/Benchmark/QuickValidation.cls (the three reference cases, comparison with `ReferenceResult`) and the `quickValidation[]` section of `ReportBuilder`; mode `agent` when a provider is configured, otherwise `replay`; T066 passes
- [x] T068 [P] [US8] Create scripts/quick-validate.sh (POSIX shell and curl, style of scripts/smoke.sh): creates the `quick_validation` run, polls its report, prints one line per Case, exits 0 only when all three match, and exits non-zero when the report is not there within 180 s or any Case diverged
- [ ] T069 [US8] [person: Henrique] Measure `time sh scripts/quick-validate.sh` on a clean container in replay mode and with a real key (verification B7); record both in research.md; if the key path exceeds 180 s, lower the per-item budget for the quick purpose in `RunService` and record the change

**Checkpoint**: a juror validates the installation in under three minutes.

---

## Phase 11: Polish and cross-cutting

- [x] T070 Write and pass tests/SignalNoir/Tests/Gates/TestGateG4.cls (live): quick validation passes in replay mode; a rules-mode run over tuning variants completes with a two-part report; a `reference` run over tuning variants is refused; an Order with no run keeps mode `agent`; `benchmark` is refused outside a run
- [x] T071 Run the full recursive suite in a fresh container (three compile passes, Simulator web application, base URL set); record the count and zero failures in research.md; confirm no Storage-block diff of an unrelated class is staged
- [x] T072 Update the 010 row, the independence line and the open items of docs/specify-prompts/PARALELISMO.md; write docs/benchmark/README.md if T061 has not
- [x] T073 Request, in one batch for the integration gate and with Henry: a CI step running `sh scripts/benchmark/check-freeze.sh` and `python -I scripts/benchmark/test_recompute.py` (.github/workflows/ci.yml), and the README line for `scripts/quick-validate.sh` (with 012); record the request in specs/010-benchmark-and-reference-run/contracts/coordination-010.md
- [x] T074 Walk specs/010-benchmark-and-reference-run/quickstart.md end to end on the fresh container and record each step's result in research.md "Verification log"; fix any step that fails
- [x] T077 The item deadline is for deciding: `Runner.Observe` gives a Case that is `Approved` or `Executing` past its deadline the execution lease more (`Runner.ExecutionSeconds`, default `SN_AI_LEASE_SECONDS`), so a RETRY into timeouts that ends Failed is scored incorrect, not `deadline` (found in the agent rehearsal on tuning, P8a-tune-01); tests/SignalNoir/Tests/Application/Benchmark/TestItemDeadline.cls
- [x] T076 Align with Constitution 2.0.0 (PR #36): `FreezeCheck` no longer marks a run development for a missing, incomplete or self review (the answer key and the baseline held by one person still does); `FreezeCheck.ReviewStatus` and `setup.independence.reviewStatus` in src/SignalNoir/Application/Benchmark/ReportBuilder.cls show how each review was done; contracts/openapi-signalnoir.yaml, the capture, FR-013, FR-029, US5 and T055/T056 follow
- [x] T075 Review the whole diff against the Constitution (I, III, IV, VII, VIII above all), the spec and the plan; check that no secret appears in any report, raw file or log, that every datum is labelled synthetic, and that nothing in the runtime depends on iris-agentic-dev; record the result in research.md

---

## Dependencies and order

- **Setup** (T001–T002) first; T002 gates every **[edit]** task and T011.
- **Foundational** (T003–T011) blocks all stories. T003/T004/T006 are parallel; T005 before T010; T007→T008→T009→T010.
- **US1** → **US2** → **US4**: the report needs runs (US1) and scoring (US2). **US3** needs only US1 and T036 (E2) and can run beside US2.
- **US5** needs US2 and US4 (the evaluator and report exist to be reviewed and frozen). Within it: T053 (Henry) and T054 (Henrique) come before the freeze (T056); T055 (José) needs T029 and T038 and, under Constitution 2.0.0, no longer blocks T056: a review done later is recorded and shown in the report.
- **US6** needs US5 (T056) and a provider key. **US7** needs US1 and, for the recorded answers, T049/T062 (it can be built against placeholder data first). **US8** needs US4, US7 and T062.
- **Polish** last; T070 needs every story.

```text
T001 → T002 ─┬→ T011
             └→ [edit] tasks (T017, T021, T027, T036, T064)
Foundation T003–T010 → US1 (T012–T027) → US2 (T028–T034) ─┬→ US4 (T037–T045) → US5 (T046–T056) → US6 (T057–T062)
                         └→ US3 (T035–T036)                                     └→ US7 (T063–T065) → US8 (T066–T069)
                                                                                   all → Polish (T070–T075)
```

## Parallel opportunities

- Foundation: T003, T004, T006 together; T007 beside T009 (different files).
- US1: T012 ‖ T013; then T014 ‖ T015; T016 can be written beside T018.
- US2: T028 ‖ T030 ‖ T032.
- US4: T037 ‖ T039 ‖ T045 (three independent files).
- US5: T046 ‖ T048 ‖ T052; **people in parallel**: Henry T053, Henrique T054, José's wait.
- US7 T065 and US8 T068 are independent of ObjectScript work.
- Across people: Henrique carries US1–US4 while Henry does T053 and the E-edits and José waits for T055.

## Implementation strategy

1. **MVP = US1 + US2 + US3 + US4** (T001–T045): a rules-mode run over tuning variants ends with a scored,
   two-part report and a comparison, with Automatic Approval confined to the run. This is the first
   end-to-end slice and the one to demo and merge first. Stop and validate with quickstart steps 1–5.
2. **Then US5**, which makes the numbers mean something (freeze, independence). Start T054 (reserved
   variants) and hand T053 to Henry early: they are the calendar's long poles, with José's review.
3. **Then US7, US8 and US6** in whichever order the provider key and the freeze allow: US7 and US8 do not
   need the key (replay), US6 does and also needs the freeze.
4. Land in small PRs by story (one per phase), full suite green on each. The functional freeze is
   2026-11-05; if the reserved variants or the review are late, ship US1–US4, US7 and US8 and publish the
   reference run as *development* with the report saying so — never as the reference.
