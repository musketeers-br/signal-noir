# Contract change 016 — `hybrid` proposer mode

**Status**: proposed by feature 016 (Henry), 2026-10-31; needs review by another team member.

**Scope**: one enum value. No other schema, operation, actor or code changes; fixtures stay valid.

| Schema | Before | After |
|---|---|---|
| `ProposerMode` | `[agent, rules, replay, decisions]` | `[agent, rules, replay, decisions, hybrid]` |

A hybrid Case's Proposals are authored `decisions` or `agent` (existing `Actor` values).

## Seams (v6 → v7)

- Proposer modes: + `hybrid` (Decisions first, Agent as fallback, behind the same port).
- Proposer `details` may carry `author` (the proposer that produced the answer, `hybrid` only) and
  `cascade` (the route, recorded as a `proposer_cascade` Annotation).
