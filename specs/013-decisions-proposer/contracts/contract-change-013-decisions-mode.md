# Contract change 013 — `decisions` proposer mode

**Status**: proposed by feature 013 (Henry), 2026-10-31. Applied to
`contracts/openapi-signalnoir.yaml` and `docs/seams.md` with the implementation; needs review by
another team member before merge.

**Scope**: additive enum values only. No operation, schema shape, state, Action, event type or error
code changes. Existing fixtures stay valid.

## HTTP

| Schema | Before | After |
|---|---|---|
| `ProposerMode` | `[agent, rules, replay]` | `[agent, rules, replay, decisions]` |
| `Actor` pattern | `^(system\|agent\|rules\|replay\|benchmark\|sweeper\|operator:…)$` | adds `decisions` |

## Seams (v5 → v6)

| v5 | v6 |
|---|---|
| — | New port `DecisionsRuntime`: `Decide(body, timeoutSeconds) -> Result`; `details.answer` is the parsed response, `details.status` the HTTP status. Failures: `provider_unavailable` (message holds only status and error code). |
| Proposer failure codes `provider_unavailable`, `invalid_response`, `refused`, `budget_exceeded` | + `uncertain` (message is the review reason). |
| — | Proposer `details` may carry `tokensCached`. |
