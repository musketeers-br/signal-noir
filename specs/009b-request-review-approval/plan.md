# Implementation Plan: Correction 009b — Approval Policy for a Request for Review

**Branch**: `009b-request-review-approval` | **Date**: 2026-10-26 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `specs/009b-request-review-approval/spec.md`

## Summary

`Core.ActionCatalog.RequiresApproval(action)` becomes `ExternalEffect(action)`, so `REQUEST_REVIEW`
reports no Approval. The catalog endpoint and the Validator adapter
(`Application.ResolutionValidator`) both read that one rule, so the catalog and every recorded
verdict change together. The routing in `CaseService.RouteProposal` already sends a request for
review to `ReviewRequired` before reading the flag, so no transition changes; a test pins that.
The console's offline mock (`ui/src/lib/api/fixtures.ts`) derives `requiresApproval` from the
same rule. 009's coordination note is corrected.

## Technical Context

**Language/Version**: ObjectScript on IRIS 2026.3 AI Hub build 154 (`dev/aihub`); TypeScript
(SvelteKit 3.1, Svelte 5.57) for the console mock.

**Primary Dependencies**: existing `Core.ActionCatalog`, `Application.ResolutionValidator`,
`CaseService`; Vitest for the console.

**Storage**: N/A (no persisted shape changes).

**Testing**: `%UnitTest` via iris-agentic-dev; Vitest; `tests/contract/validate_live.py`.

**Target Platform / Project Type**: single IRIS project plus the static console.

**Performance Goals / Constraints**: N/A. No contract, fixture or seam change (FR-006).

**Scale/Scope**: one rule, three readers (catalog, verdict, mock), one document.

## Constitution Check

- [x] **I. Pure Core** — the policy stays a pure rule in `Core.ActionCatalog`; the adapter and the
  endpoint read it and do not restate it.
- [x] **II. Closed Action Catalog** — no Action added or removed; only the reported policy.
- [x] **III. One Validator** — the verdict still comes from the single adapter; its Approval flag
  now agrees with the catalog.
- [x] **IV. Human Authority** — effectful Actions keep requiring Approval (tests pin `RETRY` and
  `APPLY_APPROVED_MAPPING`); `REQUEST_REVIEW` has no effect to authorize.
- [x] **V. Case as Source of Truth** — no command path changes; a test pins that a request for
  review still ends in `ReviewRequired` with a Dossier and no `PendingApproval`.
- [x] **VI. Effects at Most Once** — N/A (no effect path touched).
- [x] **VII. Honest Outcomes** — the catalog and the verdict stop reporting a policy the product
  does not have.
- [x] **VIII. Honest Measurement** — N/A.
- [x] **IX. Verifiable Increments** — four stories, each with its test written first.
- [x] **Platform Constraints** — synthetic data; no secrets; no image.
- [x] **iris-agentic-dev** — no new platform claim; tests run through it as in 009.

## Project Structure

```text
specs/009b-request-review-approval/  spec.md plan.md research.md data-model.md quickstart.md tasks.md
                                     contracts/README.md  checklists/requirements.md
src/SignalNoir/Core/ActionCatalog.cls                       # RequiresApproval = ExternalEffect
tests/SignalNoir/Tests/Core/TestActionCatalog.cls           # policy per Action, rule holds for all
tests/SignalNoir/Tests/Application/TestInvestigation.cls    # REQUEST_REVIEW verdict + routing
tests/SignalNoir/Tests/Api/TestResolutionApi.cls            # catalog endpoint reports the policy
ui/src/lib/api/fixtures.ts                                  # mock catalog uses the same rule
ui/src/lib/api/fixtures.test.ts (or the existing mock test) # mock policy test
specs/009-review-dossier-and-resolution/contracts/coordination-004-007.md
```

**Structure Decision**: same layout as 009; no new class.

## Complexity Tracking

None.
