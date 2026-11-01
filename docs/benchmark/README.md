# Benchmark and reference run

How Signal Noir measures whether an Agent that reads the same Tools and faces the same protections as the
rules baseline resolves failed Orders better, and how to reproduce what is published. All data is synthetic.

> **Status.** The measuring instrument exists (runs, scoring, the two-part report, the comparison, the freeze
> check, Replay, the quick validation). The reference run has **not** been made yet: the reserved test variants
> and the freeze come first (specs/010-benchmark-and-reference-run/tasks.md, T054 to T062). Until then there are
> no published numbers here, and no claim about the Agent.

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

# are the frozen source files the ones that were frozen?
sh scripts/benchmark/check-freeze.sh
```

`reference-request.json` is the request of the reference run (5 test variants of each of P5 and P8b, 3
repetitions, the clean controls and the Dossier case, with the provider and model fixed at the freeze).
`quick-validation-request.json` is the request of the quick validation; its three variants are set when the
reference result is recorded. A report from another provider or model than the reference's says so.

## Rules the numbers rest on

Prompt, model, baseline, policies, fixtures and evaluator are frozen in one record before the reserved test runs;
the answer key, the baseline and the review are held by different people, and the report says who; tuning on a
test set turns it into development data and requires a new reserved test. See
`specs/010-benchmark-and-reference-run/` (spec, plan, `contracts/scoring.md`).
