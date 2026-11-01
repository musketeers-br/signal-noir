# Coordination for 010: files of other tracks and who does what

For Henry and José. Nothing here is done; each item is a small edit in a file another person owns, or a
piece of work only another person can do. Same form as `coordination-004-006-009.md`: each item says
what, where, why and what test pins it.

## Edits in files of other features (small, agreed first)

| # | File (owner) | Edit | Why | Pinned by |
|---|---|---|---|---|
| E1 | `Application/CaseService.cls`, `NewCase` (003, Henry) | ask `RunDirectory` for the run: copy its mode and `replay`, keep `runId` only when the run is `running`; otherwise mode `agent`, no run id, no replay | FR-003 | `Tests.Application.Benchmark.TestCaseOpening` |
| E2 | `Application/CaseService.cls`, the two automatic-Approval sites (`RouteProposal`, `Decide`) (007, Henry) | also require `RunDirectory.Find(runId).status = "running"` before recording an Approval by `benchmark` | FR-008, FR-009 | extends `TestBenchmarkApproval` |
| E3 | `Application/ResolutionValidator.cls`, `RunFor` (004, Henrique) | read the run's pins from `RunDirectory` instead of returning `null` | FR-006 | `TestResolutionValidator` + a new pinned-version test |
| E4 | `Proposers/Replay.cls` (006, Henry) | look up the recorded answer by the item's reference case, not by `orderId` | FR-031, FR-032 | `Tests.Application.Benchmark.TestReplay` |
| E5 | `Api/Dispatch.cls`, `UrlMap` (003/009, Henry) | add `Map` entries for `/benchmark-runs` and `/benchmark-reports` forwarding to `Api.BenchmarkDispatch` | contract | `Tests.Api.TestBenchmarkApi` |
| E6 | `Core/Port/` (001, José) | add `RunDirectory` next to the other ports | D2 | seam tests (`TestConsumerUsesSeam`) |

| E7 | `Interop/Bootstrap.cls`, `EnsureBackgroundTasks` (012, Henry) | the task list becomes `TaskClasses()` and gains `Tasks.BenchmarkTask` (drives a run again when its driver stopped) | plan D4 | `TestBenchmarkTask`, `TestBootstrap` |
| E8 | `tests/.../Support.cls` and `TestBenchmarkApproval.cls` (003/007, Henry) | a test that gives an Order a run id first registers a running run (`Support.EnsureRun`), because a Case now keeps only the id of a run that is running | E1, E2 | the suites of 003, 007 and 015 stay green |

E1–E5, E7 and E8 are each a few lines. E6 is a new file in the Core. None changes a contract, an Action or a state.

## Work only other people can do

| Who | What | Needed before |
|---|---|---|
| Henrique | the ten reserved test variants (5 P5, 5 P8b) replacing `P5-test-00` / `P8b-test-00`, and their answer keys; the answer keys of the tuning variants | the freeze |
| Henry | the rules baseline (`Proposers/Rules.cls`), including the synonyms of `Core.Conditions.Matches` (open since 004; the test that pins `requiresApproval` of `REQUEST_REVIEW` already exists, see below); **does not read the reserved variants before the freeze** | the review |
| José | the review of the baseline and of the evaluator (`Core.Benchmark.Scorer`, `Stats`): that the baseline was not weakened and the evaluator matches `contracts/scoring.md`; records author, commit and date in `Benchmark.Data.Reviews` | the freeze |
| Henrique | the freeze commit (one commit), then the reference run, then `ReferenceResult` and the published report | the quick validation (012) |
| Henry (012) | `scripts/quick-validate.sh` is written by 010; 012 wires it into the README and the smoke path | submission |

## Independence, as encoded

The report's `setup.independence` is built from `Benchmark.Data.Roles` and `Benchmark.Data.Reviews`
(CC-6). `FreezeCheck` marks a reference run **development** when, for any core family in it, the
answer-key author also wrote the baseline, or no roles are recorded. Since Constitution 2.0.0 (PR #36,
2026-11-01) a review never does: `setup.independence.reviewStatus` shows, per core family and for the
evaluator, whether the review was done by another member, by its author (`self`), by an automated reviewer,
or is incomplete or missing. The file `docs/specify-prompts/PARALELISMO.md` names the intended holders
(Henrique key, Henry baseline, José review); the data records what actually happened.

## Open questions that need a person

See the plan's *Open decisions*: Q1 (what counts as the end of a Case), Q2 (evidence for restart and late
worker), Q3 (where the used-set declaration lives).

## Decision record (T002)

**2026-10-31.** Henrique reported that Henry and José approved this document. Recorded as approved, with
no condition stated:

- Henry: E1–E5 (edits in `CaseService`, `ResolutionValidator`, `Replay` and `Dispatch`), the baseline with
  synonyms (T053), and not reading the reserved variants before the freeze.
- José: E6 (the `RunDirectory` port), the review of the baseline and of the evaluator (T055) against
  `contracts/scoring.md`.
- Q1–Q3 took their defaults (plan, Open decisions).

The approval was given outside the repository (message to Henrique). If either of them attached a
condition, add it here before the edit it affects starts.

## Henry on the edits as implemented (2026-11-01)

Henrique asked Henry to review the edits in his files as they stand in PR #32 (E1–E5, E7, E8, and the
resolution of the merge with `master` in `CaseService`: a Case of a `running` run takes the run's mode, any
other Case takes `Factory.ConfiguredMode()`). Henry answered, by message to Henrique: "Pode alterar,
acredito que o que fiz já está na master" ("go ahead and change them; I believe what I did is already in
master"). Recorded as his agreement to those edits as implemented, with no condition stated.

It does not cover:

- the points of `contract-change-010-benchmark.md` under *Applied (T011)*, which Henry still confirms in
  the review of PR #32;
- T053. Henry believed the synonyms were already in `master`. They are not: `Core.MappingMatch`, which
  the Rules use, compares the specimen type without the synonym list, so an Order written `soro` still ends
  in review (the second case of `Tests.Gates.TestGateG1` says so). The test pinning `requiresApproval` of
  `REQUEST_REVIEW` does exist (`TestReferenceEndpoints`, the endpoint against the verdict per Action). What
  is left (the synonyms in the Rules, `Rules.VERSION`, `docs/benchmark/baseline-rules.md`) stays with
  Henry: if Henrique wrote it, the baseline author and the answer-key author of P8b would be the same person
  and the reference run would be development data (FR-029).

## Request for the integration gate (T073)

Integration files are not edited by a feature (PARALELISMO.md), so these are asked for in one batch, to be
applied with Henry at the gate. Nothing here is needed to run the tests locally.

1. **CI** (`.github/workflows/ci.yml`), a step that needs only the repository and Python, in the job that
   does not start IRIS (or a new small job):

   ```yaml
   - name: Benchmark freeze, recomputation and quick validation scripts
     run: |
       sh tests/benchmark/test-check-freeze.sh
       sh tests/benchmark/test-quick-validate.sh
       python -I scripts/benchmark/test_recompute.py
       python -I scripts/benchmark/test_freeze_record.py
       sh scripts/benchmark/check-freeze.sh
   ```

   The first four prove the scripts; the last compares each frozen source file with the freeze record (it
   says "no freeze yet" and passes until T056). After the freeze, a change to a frozen file fails the build,
   which is the point.
2. **README.md** (with 012): one line for `sh scripts/quick-validate.sh` next to the smoke check, and one for
   `docs/benchmark/README.md` (how the published reference result is reproduced and what it does and does not
   show).
3. **Console types** (`ui/src/lib/api/types.ts`) are in T011 with the contract change, not here.
