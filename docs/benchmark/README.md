# Benchmark and reference run

How Signal Noir measures whether an Agent that reads the same Tools and faces the same protections as the
rules baseline resolves failed Orders better, and how to reproduce what is published. All data is synthetic.

> **Status.** The reference run is `run_000260`, made on 2026-11-02 under the freeze `freeze-2026-11-02`
> (prompt `agent-v5`, OpenAI `gpt-4o-mini`, baseline `rules-v2`, evaluator `scorer-v1`). Its report is
> `reference-report.json` (`development: false`, `publishableAsReference: true`), every Case of it with its
> Proposals, Timeline and Evidence is `raw-cases.json`, and the rules baseline over the same variants is
> `baseline-report.json` (`run_000261`).

## The reference result

39 Cases: five reserved test variants of P5 (one of them a prompt injection) and five of P8b, the three clean
controls (success, Partner unavailable, ambiguous identity, which is the case that ends in a Dossier), each three
times. 36 of them are investigations; `clean.success` opens no Case, as its key expects.

| | Agent (`run_000260`) | Rules baseline (`run_000261`) |
|---|---|---|
| correct | 33 | 33 |
| safe review | 6 | 6 |
| unnecessary review | 0 | 0 |
| incorrect | 0 | 0 |
| wrong Proposals blocked by the Validator / wrong effects | 0 / 0 | 0 / 0 |
| latency per Case, p50 (range over repetitions, P5 / P8b) | 2.2–2.6 s / 2.2–2.4 s | 29–32 ms / 29–31 ms |
| tool calls per Case | 6 | 6 |
| wall time of the run | 4 min 30 s | 3 min 19 s |

Every range is the same in the three repetitions: no variant changed outcome from one repetition to the next. The
six safe reviews are `P8b-test-05` (the Order states no specimen type, so neither Mapping can be shown to apply)
and `clean-ambiguous-identity-test-01` (a divergent patient record), three times each; for both the key says the
right answer is to ask a person, and each ended in `ReviewRequired` with a Dossier.

**What this shows, and what it does not.**

- **A tie, not a win.** On these variants the Agent and the rules baseline took the same Action in every Case, and
  the Agent took about 75 times as long. Nothing here shows the Agent resolving failed Orders better than the
  rules; it shows that it resolves them as well, with an LLM in the loop, under the same Tools and protections.
- **The Agent decides from facts the platform computes.** Since `agent-v4` the prompt carries `CHECKS`: the
  conditions of each Action, already evaluated by the platform from the Evidence (`DecisionFacts`), and the Agent
  chooses among Actions whose preconditions it can read as true or false. That is the same information the rules
  use, which is part of why the two agree.
- **The confidence is the platform's.** Since `agent-v5` the confidence of the final Proposal is set by the
  platform's rule (FR-021): when the model gives another value, it is replaced and the change is recorded as a
  `confidence_calibrated` Annotation. In this run the model's value was replaced in no Case (15 HIGH, 15 MEDIUM,
  6 LOW, as given), but the confidence is still not a measure of the model's own calibration.
- **Small and synthetic.** Ten reserved variants and three controls, written by one person (the answer key) and
  checked against a baseline written by another, on simulated Partners. It is evidence that the Agent is not worse
  than the rules on these shapes, not a rate to expect elsewhere.
- **Cost is not estimated.** `estCostUsdPerCase` is empty for the Agent: no price table is recorded for the model.
- **Platform guarantees.** Idempotency passed (0 duplicate Receipts over 30 effects). P3, timeout, restart,
  repeated approval and late worker are *not exercised* by this run's scenarios; the evidence for restart and late
  worker comes from the recovery suite (`Tests.Recovery.TestRecoverySuite`), recorded with the reference result
  (`Benchmark.Data.ReferenceResult`, T062).

**A discarded run.** A first reference run, `run_000241` (same freeze, request and seed), ended with the same
outcome in every Case. It is not published as the reference for two reasons: its stored report said
`publishableAsReference: false` because the report was written just before the run was marked completed (fixed in
`ReportBuilder` before `run_000260`; that file is not frozen), and its run record was later deleted by a test
suite run in the same IRIS namespace, so the report could not be rebuilt with the reviews that had since been
committed. Its numbers are in specs/010-benchmark-and-reference-run/research.md.

## What is measured, and what is not

- **Agent decision**: per family (P5, P8b), set and mode, how many Cases ended correct, in a needed review, in
  an unneeded review, or incorrect, with the proportion, p50 and p95 latency, tool calls and estimated cost per
  Case. Each figure is a range over the repetitions. A variant counts once; repetitions only give the range.
  A Case that did not decide (provider down, deadline) is listed apart, and the report shows the proportions
  with and without it. A wrong Proposal blocked by the Validator and a wrong effect sent to the Partner are two
  columns, never one number.
- **Platform guarantees**: P3, idempotency, timeout, restart, repeated approval, late worker: pass, fail, or
  *not exercised*. They hold whoever proposes; there is no score and no comparison between modes.
- **Never counted**: a Replay (a recorded response), a Case a person acted on, and the tuning set when a
  result is claimed.

## Reproduce

```sh
# the quick validation: three reference Cases, under three minutes, no key needed (Replay) or with your own
sh scripts/quick-validate.sh

# recompute the report of a run from its raw rows (independent of IRIS)
python -I scripts/benchmark/recompute.py docs/benchmark/reference-report.json
python -I scripts/benchmark/recompute.py docs/benchmark/baseline-report.json

# run it again (SN_AI_PROVIDER=openai and SN_AI_API_KEY in the container's environment; BASE is .../signalnoir/api/v1);
# for the baseline, the same request with "mode": "rules" and no provider or model
curl -s -X POST $BASE/benchmark-runs -H 'Content-Type: application/json' -d @docs/benchmark/reference-request.json

# are the frozen source files the ones that were frozen?
sh scripts/benchmark/check-freeze.sh
```

`reference-request.json` is the request of the reference run (5 test variants of each of P5 and P8b, 3
repetitions, the clean controls and the Dossier case, with the provider and model fixed at the freeze).
`quick-validation-request.json` is the request of the quick validation; its three variants are the `quickCases`
of the recorded reference result (`Benchmark.Data.ReferenceResult`): the control `clean-success-test-01`, the
P8b case `P8b-test-01` and the Dossier case `clean-ambiguous-identity-test-01`. In Replay (no key) it passes in
about 16 seconds. A report from another provider or model than the reference's says so.

## Rules the numbers rest on

Prompt, model, baseline, policies, fixtures and evaluator are frozen in one record before the reserved test runs;
the answer key and the baseline are held by different people, and the report says who held each role and how the
baseline and the evaluator were reviewed (by another member, by their author or by an automated reviewer); tuning on a
test set turns it into development data and requires a new reserved test. See
`specs/010-benchmark-and-reference-run/` (spec, plan, `contracts/scoring.md`).
