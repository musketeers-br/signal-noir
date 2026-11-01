# Data Model: Decisions API as a Proposer

Decisions: [research.md](./research.md). No new table.

## Changed

- **`InvestigationRecord.tokensCached`** (integer, new): cached input tokens reported by the
  provider (FR-010). Empty for providers that do not report it.
- **`CaseRecord.proposerMode`**: may now be `decisions`; set at creation from `SN_PROPOSER_MODE`.
- **Vocabulary**: `Vocab.ACTORS` gains `decisions` (the author of a Decisions Proposal and the actor of
  its `ProposalCreated` event).

## Request (built by `Core.DecisionQuestions`, version `decisions-v1`)

```json
{"model": "gpt-6-luna",
 "input": [{"role": "user", "content": [{"type": "input_json", "data": {
   "synthetic": true, "case": {"caseId", "orderId", "partnerId"}, "order": <neutralized snapshot>,
   "evidence": [{"evidenceId", "source", "kind", "suspicious", "result": <neutralized>}]}}]}],
 "questions": [
   {"type": "choice", "name": "action", "instructions": <constant>, "choices": [
     {"value": "RETRY", ...}, {"value": "APPLY_APPROVED_MAPPING:<mappingId>", ...}*,
     {"value": "HOLD", ...}, {"value": "REQUEST_REVIEW", ...}, {"value": "other", ...}]},
   {"type": "predicate", "name": "ev:<evidenceId>", "instructions": <template over the id>}*]}
```

## Conversion outcomes (`Core.DecisionAnswer.Convert`)

| Condition (in this order) | Result |
|---|---|
| an answer `type: refusal`, or no answers | error `refused` |
| missing or duplicate `action`, unknown choice value, value outside catalog and candidates | error `invalid_response` |
| choice `other` | error `uncertain`, "proposer uncertain: other" |
| top probability < 0.5 | error `uncertain`, "proposer uncertain: below threshold" |
| top − second < 0.1 | error `uncertain`, "proposer uncertain: tie" |
| otherwise | ok: raw Proposal answer (diagnosis, action, params, confidence, preconditions) |

## Result details (proposer port)

`provider: "openai-decisions"`, `model`, `promptVersion: "decisions-v1"`, `tokensIn`, `tokensOut`,
`tokensCached`, plus `probabilities` and `confidence` of the choice for the Timeline.
