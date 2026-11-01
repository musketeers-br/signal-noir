# Contract change proposal: Benchmark report and run (010)

**Status**: proposed, not applied. `contracts/openapi-signalnoir.yaml` is frozen; nothing in it changes
until the people named below accept. Every item is **additive** (new optional fields, one enum value,
one type widened to allow `null`), so the fixtures and the console types keep working.

**Why.** The spec (FR-016–FR-018, FR-020, FR-022, FR-023, FR-026–FR-029) asks the report to say things
the contract has no place for. The checklist of the spec listed them as gaps; the plan checked each
against the schemas. API-Q1 and API-Q10 of the contract are also confirmed here in the form the contract
proposes.

**Who decides.** Henrique (owner of the report), Henry (console types, `ui/src/lib/api/types.ts`), José
(review of the evaluator). Apply in one commit with the regenerated types; `contracts/tools/validate_fixtures.py`
must stay green.

## Changes

| # | Schema | Change | Needed by |
|---|---|---|---|
| CC-1 | `AgentDecisionRow` | add optional `subtype` (string: `P8a`, `P8b`, `P5.injection`, `clean.success` …). Rows are per `(family, subtype, set, mode)` so P8b is reported apart from P8a. | FR-019 ("core families P5 and P8b") |
| CC-2 | `AgentDecisionRow` | add `counts` (object: `correct`, `safe_review`, `unnecessary_review`, `incorrect`, `notDecided`, all integers), `denominator` (`{withNotDecided, withoutNotDecided}`), `repetitionsCovered` (integer), `blockedWrongProposals` and `wrongEffects` (each a `Range`, never added together), `note` (string \| null). | FR-016, FR-017, FR-022, FR-028 |
| CC-3 | `BenchmarkCaseResult` | add `subtype`, `actionParams` (object \| null), `notDecidedReason` (`provider_unavailable` \| `run_failed` \| `deadline` \| null), `touchedByPerson` (boolean), `blockedWrongProposals` (integer), `wrongEffect` (boolean). `outcome` stays `null` for a Case that did not decide (already allowed). | FR-017, FR-018, FR-022 |
| CC-4 | `PlatformGuaranteeRow` | add `late_worker` to the `guarantee` enum; widen `passed` to `boolean \| null` where `null` means **not exercised** (never a pass); add `source` (`run` \| `recovery_suite`) and `evidenceCommit` (string \| null). | FR-020; Principle VII |
| CC-5 | `BenchmarkRun`, `BenchmarkReport` | add `development` (boolean), `developmentReasons` (string[]), `freezeId` (string \| null). Report only: `publishableAsReference` (boolean). | FR-023, FR-026, FR-027 |
| CC-6 | `BenchmarkReport` | add `setup`: `{promptVersion, baselineVersion, evaluatorVersion, freezeId, variantSet, independence: {answerKeyBy, baselineBy, reviewedBy[] {kind, family, reviewer, commit, date}}}`. | FR-023, FR-029 |
| CC-7 | `ComparativeBenchmarkReport` | add `sameScenarioSet` (boolean, always `true` in a 200) and per-run `setup` copied from each report. | FR-021, FR-023 |

## Confirmed without a schema change

- **API-Q1.** A comparison is two runs read together (`GET /benchmark-reports?runId=&runId=`); no
  `benchmark-suites` resource. The "single command" of the README calls `POST /benchmark-runs` twice.
- **API-Q10.** `POST /benchmark-runs` while a run is `created` or `running` answers 409 `INVALID_TRANSITION`.
- **API-Q2** (already proposed): malformed or refused selection is 400 `VALIDATION_FAILED`; a report before
  the run ends is 409 `INVALID_TRANSITION`; an unknown run is 404 `NOT_FOUND`.
- **Where the freeze, the reviews and the used-set declarations live.** In committed data
  (`SignalNoir.Benchmark.Data`), not behind an endpoint. Only their effect appears in the contract
  (CC-5, CC-6). Declaring a set as used is a commit, so it cannot be undone silently.
- **"Touched by a person".** Computed from the Timeline actors of the Case; no new Case field (CC-3 carries
  the result).
- **Raw data.** `BenchmarkReport.cases` is the raw data. No export endpoint (API-Q9 stays open).

## Not changed on purpose

- `ProposerMode` keeps `replay`. The API accepts it because the quick validation and the fallback video
  need it; there is no console entry point (FR-031).
- `ScenarioFamily` is unchanged. P3 and idempotency are not rows of the agent decision part; they feed
  `platformGuarantees` only.
- No new Action, state, error code or actor.

## Decision record (T002)

**2026-10-31.** Henrique reported that Henry and José approved CC-1…CC-7 as proposed. The contract
itself is changed only by T011, in one commit with the console types.
