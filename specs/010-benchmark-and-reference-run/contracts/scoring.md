# Scoring and statistics

The rules of `Core.Benchmark.Scorer` and `Core.Benchmark.Stats`. Normative for the evaluator the José
review covers. Anything not written here is not a rule of the evaluator.

## Inputs

For a scored Case: its **answer key** (declared before the run) and its **facts** (see
[data-model.md](../data-model.md)). A Case is scored only if its item is in the *test* set (a *tuning*
item is scored too but reported apart, labelled development) and the Case is not a replay and was not
touched by a person.

## Step 0 — is it a decision at all?

| Condition (checked in this order) | Result |
|---|---|
| the run's mode is `replay` | not scored, `countsInMetrics = false` |
| `touchedByPerson` | not scored, `countsInMetrics = false`, flagged |
| `notDecidedReason` is set (`provider_unavailable`, `run_failed`, `deadline`) | `outcome = null`, listed apart |
| the Case is still in a non-terminal state and not in `ReviewRequired` | `outcome = null`, reason `deadline` |
| otherwise | go to Step 1 |

## Step 1 — the effect of the Case

| Final state | Effect |
|---|---|
| `Resolved`, `ResolvedByPriorReceipt` | the executed Action and its effective parameters |
| `Held` | `HOLD` (when the Held came from a `HOLD` Proposal) or none (when it came from a failed Revalidation: the Action was blocked before it was sent) |
| `ReviewRequired` | review |
| `Failed`, `Cancelled`, `Rejected` | none; scored as `incorrect` unless the key accepts the matching review |

## Step 2 — classification (exactly one)

| Effect | Key says | Outcome |
|---|---|---|
| an Action whose action and parameters are in `acceptable` | — | **correct** |
| an Action not in `acceptable`, or in it with parameters that do not match | — | **incorrect** (and `wrongEffect += 1`) |
| review | `reviewIsAcceptable = true` | **safe review** |
| review | `reviewIsAcceptable = false` | **unnecessary review** |
| none (failed Revalidation, cancelled at the Origin) | the key lists the matching state | **correct** |
| none | otherwise | **incorrect** |

"Parameters match" = every key of the key's `params` equals the effect's value after `Core.Canon`
canonicalisation (not text comparison). The effect may carry more keys.

## Step 3 — the two counts that are never added

- **blockedWrongProposals**: Proposals of the Case whose verdict was `blocked` or `review` and whose
  action and parameters are not in `acceptable`. A proposer error that the protection caught.
- **wrongEffect**: 1 when Step 2 produced `incorrect` because an Action was *sent*. A wrong effect.

A Case can have `blockedWrongProposals = 1` and still be **correct** (a second Proposal was right), or
**safe review**. The report shows both counts as separate columns and never a sum.

## Statistics

For each row key `(family, subtype, set, mode)`:

1. Take the scored Cases of **one repetition**. `variantCount` = the number of variants in that repetition.
2. `count[o]` for each outcome; `proportion[o] = count[o] / variantCount` (denominator A, including
   `notDecided`) and `proportion'[o] = count[o] / (variantCount − notDecided)` (denominator B). Both are
   published.
3. Latency p50 and p95: **nearest rank** over the Cases of the repetition: sort ascending; the value at
   index `ceil(p × n)` (1-based). With `n = 5`, p95 is the maximum, and the row's `note` says so.
4. Tool calls per Case and estimated cost per Case: arithmetic mean over the repetition.
5. The row's **range** for any of these values is `{min, max}` across the repetitions. A variant counts
   once in every denominator; the repetitions supply only the range.
6. `repetitionsCovered` = the number of repetitions with at least one scored Case. If lower than the run's
   `repetitions`, the row says so and the report does not present the range as a k-run range.

Latency is `InvestigationRecord.durationMs` of the Investigation that produced the final Proposal. Cost
is `estCostUsd`; a mode that has no cost (rules) reports 0, not null.

## Golden data

`tests/` holds one golden file (raw rows and the expected rows) read by both `Tests.Core.Benchmark.TestStats`
and `scripts/benchmark/recompute.py`. The two implementations must agree on it, and the recomputation
script must agree with the reference run's published report.
