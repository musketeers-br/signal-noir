# Phase 0 Research: Review Dossier and Operator Resolution

**Date**: 2026-10-25

## Calendar-gate exception

Henry asked for the full cycle of 009, including implementation, on 2026-10-25 (as for 003, 006,
005). Recorded for the G3 review.

## R1 — Reason mapping

`Core.DossierReason.From(reviewReason)` maps the recorded review reasons to the contract enum:

| Recorded reason (003/006) | Dossier `reason` |
|---|---|
| `provider unavailable: …` | `provider_unavailable` |
| `invalid proposer response` | `invalid_agent_response` |
| `investigation budget exceeded: …` | `budget_exceeded` |
| `investigation interrupted` | `investigation_interrupted` |
| `second rejection` | `second_denial` |
| `validator blocked: …` | `validator_blocked` |
| anything else | `review_requested` |

Each reason has a fixed plain-language explanation (which quotes the recorded reason) and a
suggested next step.

## R2 — Nothing invented

The builder receives the Evidence DTOs of the Case and only ever emits their ids. Unknowns are
generated from facts: each `absence` Evidence ("No information from <source>: <reason>"), a missing
diagnosis, no Evidence at all, unresolved identity, a prior-receipt candidate absent from the
Evidence. Tests assert every id in a Dossier exists on the Case.

## R3 — Identity collisions and prior-receipt candidates

- Collisions: patients from `tool.receipts_and_orders_by_patient` results (`items[].orderSnapshot.patient`)
  plus the Case's own Order, grouped by normalized name; a group with ≥ 2 distinct `patientId`
  becomes `collidingRecords` (`fields`: patientId, name, birthDate, sex; `divergentFields`: those
  that differ).
- Candidates: the current Proposal's `priorReceiptCandidate`, looked up in the same Evidence; the
  equivalence key of its `orderSnapshot` (core `Canon.FromSnapshot`) is compared part by part with the
  Case's Order → `mismatchedFields`.

## R4 — Validator adapter

`Application.ResolutionValidator.Validate(proposal)` calls the injected `Port.Validator` (runtime:
`Core.Validator`, seam v1) and maps to the contract verdict: `valid → accepted` with reasons
`ACTION_IN_CATALOG, PARAMS_VALID`; `invalid → blocked` with the v1 `failedPreconditions` (or
`ACTION_NOT_IN_CATALOG`) as codes. `requiresApproval` comes from `Core.ActionCatalog` (HOLD: no; the
others: yes, FR-16). When 004 lands, this adapter switches to `Validate(ValidationInput)` and 004's
reason codes; nothing else changes.

## R5 — Resolution shape

`Core.ResolutionShape.Check(request)`: top-level keys only from the contract (`kind`, `operator`,
`expectedCaseVersion`, `action`, `params`, `note` for action; `kind`, `operator`,
`expectedCaseVersion`, `reason` for cancel); operator name 1–64, no ":"; integer version; action in
the catalog and not `REQUEST_REVIEW`; params keys only those of the Action (`mappingId`,
`mappingVersion` for APPLY_APPROVED_MAPPING; `reason` for HOLD; none for RETRY); cancel needs a
non-empty reason. Missing mapping params are left to the Validator (semantic → 422).

## R6 — Approval in a resolution

Contract `Approval`: `appr_…`, `proposalId`, `decision: approved`, `by: operator:<name>`, `at`,
`expiresAt = at + 15 min` (PRD assumption), `status: valid`. 007 will own the approval command,
replays and expiry over the same record (see `contracts/coordination-004-007.md`).

## Verification log (2026-10-25, partial — usage limit reached)

| Check | Result |
|---|---|
| ObjectScript suite | Core 51/51, Application 59/59, Api 12/13 (only the pre-existing 001 `TestHealth` fails) |
| Live contract (`validate_live.py`) | review detail with dossier, resolution 400/409/422/201, action catalog, mappings: all conform |
| Browser | real Dossier renders in the console; the form refused submission without a declared name (the name typed in the browser check did not reach the field). Cancel via the console not completed — T017/T018/T019 open |
| Fixes found | SQL reserved word `at` broke the approvals query; 001 bug: `ValidatorVerdict.failedPreconditions` declared as an object dropped the Validator's codes (now `%List`) |
| Process | Dispatch changes were written before `TestResolutionApi` |

## Verification on AI Hub build 154 (2026-10-26, `dev/aihub`, Community ARM64)

| Check | Result |
|---|---|
| Platform | `IRIS for UNIX (Ubuntu Server LTS for ARM64 Containers) 2026.3.0AI (Build 154U)`, `%AI.Agent` present, Community license with Interoperability |
| ObjectScript suite (T017) | 135 pass, 1 fail (pre-existing 001 `Api.TestHealth`). Note: one `iris-agentic-dev compile` pass left `Core.CaseMachine` uncompiled without reporting an error; a direct load compiled it |
| Live contract | `validate_live.py`: all responses conform; fixtures 25/25; console 45/45 |
| Console (T018) | a `ReviewRequired` case cancelled from the dossier form in the browser: banner "Cancelled", toast, form gone, dossier moved down; Timeline has `StateChanged` and `OperatorResolution` by `operator:Henry` with the reason. The earlier failed attempt was the browser automation not focusing the name field, not a console bug |
| Copy fix | state banners no longer repeat the chip label ("Cancelled. Cancelled.") |
