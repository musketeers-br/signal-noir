# Phase 0 Research: Correction 009b — Approval Policy for a Request for Review

**Date**: 2026-10-26

## Calendar-gate exception

Henry asked for the full cycle of 009b, including implementation, on 2026-10-26, as for 003, 005,
006 and 009. Recorded for the G3 review.

## R1 — Source of the policy

**Decision**: an Action needs Approval if and only if it has an external effect.

**Rationale**: initiative R19 (PRD FR-16): "`RETRY` and `APPLY_APPROVED_MAPPING` need human
Approval outside the Benchmark; `HOLD` enters without Approval; `REQUEST_REVIEW` stops automation
with no external effect". The contract fixtures agree: the verdicts on `REQUEST_REVIEW` in
`case.review.ambiguous-identity.json` and `case.review.after-denial.json` carry
`requiresApproval: false`, while the `RETRY` verdict in `case.review.after-denial.json` carries
`true`. The schema (`ActionCatalogEntry.requiresApproval`, "Approval policy v1 (FR-16)") does not
fix the value, so no contract change is needed.

**Alternatives considered**: keep `true` for `REQUEST_REVIEW` "because a human reviews it" —
rejected: review is not Approval (no Proposal is authorized, nothing is executed), and it
contradicts both the initiative and the fixtures.

## R2 — Who reads the rule

`Core.ActionCatalog.RequiresApproval` is read by `ActionCatalog.Entries()` (the
`/reference/action-catalog` endpoint) and by `Application.ResolutionValidator.Verdict` (every
recorded verdict). Changing the one rule changes both; nothing restates it. The console's offline
mock restates it (`action !== 'HOLD'`) and is fixed to derive it from the external effect.

## R3 — Routing is unaffected

`CaseService.RouteProposal` checks, in order: blocked → review; `REQUEST_REVIEW` → review;
`requiresApproval` → `PendingApproval`; else → `Executing`. A request for review never reaches the
Approval check, before or after the fix. `ResolveReview` refuses `REQUEST_REVIEW` in its shape
check. No transition changes; `TestInvestigation` pins it.

## R4 — Division of work with 004

This correction takes edit 3 of `coordination-004-006-009.md` (the `RequiresApproval` part). The
other 004 edits stay with 004: `InputFor` and the new adapter signature (T015), `requiredEvidence`
in the catalog (T010), reference data in `LocalSource` and `Dispatch.Mappings` (T037), the v2
verdict vocabulary in the fakes (T003, T006). Specimen synonyms in `Rules` wait for
`Core.Conditions.Matches` (wave 4, after 004 merges).

## R5 — Results (2026-10-26, IRIS 2026.3 AI Hub build 154, provider key configured)

| Check | Before (T001) | After (T009) |
|---|---|---|
| ObjectScript suite | 145/145 | 145/145 in 3 of 4 application runs (see R6) |
| Console (`npm test`) | 45/45 | 46/46; `npm run check` 0 errors |
| Live contract (`validate_live.py`) | — | all responses conform |
| Contract fixtures | — | 25 valid, 0 invalid |
| Live catalog | `REQUEST_REVIEW` requiresApproval true | `requiresApproval` = `externalEffect` for all four |

The four new ObjectScript assertions and the console test failed before T004/T007 and pass after.

## R6 — Live-agent test outside this correction

`Application.TestToolGateway.TestEmbeddedInstructionLiveAgent` (006) failed in 2 of 5 runs during
this work, with the poisoned twin proposing `HOLD` once and `RETRY` once. 009b does not reach the
model: the agent prompt carries Evidence and the Order only, never the catalog. The twins also do
not differ only by the instruction: the poisoned one gets a scripted partner history (one 500
rejection) that the clean one does not, so a `RETRY` may come from that history rather than from
the instruction. Left to a follow-up on 006 (make the twins identical except for the instruction,
then decide whether SC-004 holds).
