# Contract change 004 — Validator seam v2

**Status**: proposed (feature 004). Applies to `docs/seams.md` and its spec-side copy
`specs/001-runtime-skeleton-and-seams/contracts/seams.md`.
**Why**: v1 cannot express the product contract's verdict (`ValidatorVerdict` in
`contracts/openapi-signalnoir.yaml`) nor FR-016 of spec 004 (every input as a parameter).
**Who is affected**: 006, 007, 008, 009, 010 (consumers through the port or `FakeValidator`). None
consumes v1 yet.
**When**: the document change landed on `master` on 2026-10-24 (seam v2; v3 and v4 by 003 and 006
since). The code still implements v1; the code change (DTO, port, fake, seam tests) is the first
implementation task of 004.

**Revision 2026-10-26** (after 003, 005, 006, 009 merged): `identity` is removed from
`ValidationInput`; the Validator derives it from `evidence` and `order` with the Core identity rule.
The row above is the revised one. `docs/seams.md` and its spec-side copy still list `identity` in the
`ValidationInput` row; removing it is a documentation-only edit to apply on `master` (separate
commit, no consumer reads `ValidationInput` yet). `Proposal.confidence` is already `HIGH` / `MEDIUM`
/ `LOW` in seam v4.

## Changes to `docs/seams.md`

### DTO table

Replace the `ValidatorVerdict` row and add three rows:

| DTO | Required fields |
|-----|-----------------|
| `ValidatorVerdict` | `verdict` (`accepted` / `blocked` / `review` / `prior_receipt_confirmed`), `reasons` (ordered closed codes), `requiresApproval`, `versions` (`policy`, `mapping`), `at` |
| `ValidationInput` | `proposal`, `evidence[]`, `order` (snapshot), `priorReceiptOrder?`, `attemptCount`, `run` (`inRun`, `runId`, `policyVersion`, `mappingVersion`), `reference` (snapshot), `observed?` (Revalidation only), `now` |
| `PreconditionResult` | `check`, `expected`, `observed`, `passed`, `evidenceId?` |
| `Admission` | `admissible`, `label` (`human` / `automatic`), `reason?` |

The `Proposal` DTO gains `scope`, `confidence`, `preconditions[]` (`check`, `expected`) and
`priorReceiptCandidate?`, matching the product contract's `Proposal`.

### Port

Replace the Validator section with:

```
Validate(input: ValidationInput) -> ValidatorVerdict
Revalidate(input: ValidationInput) -> ValidatorVerdict + [PreconditionResult]
Admit(actor, run) -> Admission
```

Deterministic, origin-blind, no I/O: every input arrives in `ValidationInput`, including `now` and the
reference-data snapshot. Reason codes come from the closed list of
`specs/004-validation-and-reference-data/contracts/reason-codes.md`.

### Fakes

| Fake | Behaviour |
|------|-----------|
| `FakeValidator` | configurable `ValidatorVerdict` (default `accepted`, `requiresApproval = true`, reasons `[ACTION_IN_CATALOG]`), configurable `PreconditionResult[]` and `Admission` |

### Consumer guarantee

Unchanged in spirit: a consumer of v2 compiles and tests against the port and `FakeValidator` with no
edits to 004's files.

## Code changes (first task of 004, after 2026-10-26)

- `src/SignalNoir/Core/Dto/ValidatorVerdict.cls`, `Dto/Proposal.cls`, new `Dto/ValidationInput.cls`,
  `Dto/PreconditionResult.cls`, `Dto/Admission.cls`, `Dto/ReferenceData.cls`.
- `src/SignalNoir/Core/Port/Validator.cls` — three abstract methods.
- `tests/SignalNoir/Tests/Fakes/FakeValidator.cls`, `tests/SignalNoir/Consumer/Consumer.cls`,
  `tests/SignalNoir/Tests/Seam/TestConsumerUsesSeam.cls` — v2 shape (`verdict = "accepted"`).

## Fixture divergence

`contracts/fixtures/resolution.201.action.json` shows an Operator `APPLY_APPROVED_MAPPING` with the
conditional mapping `map_glicj_plasma` accepted with reasons `[ACTION_IN_CATALOG, PARAMS_VALID]`. Under
the one Validator (Principle III) the same Proposal from any origin yields `[ACTION_IN_CATALOG,
PARAMS_VALID, MAPPING_CONDITION_MATCHES, REQUIRED_EVIDENCE_PRESENT]`. Fix the prototype mock so the
Operator path uses the same reason rules, regenerate the fixtures with
`tools/export-api-fixtures.js`, and re-run `contracts/tools/validate_fixtures.py`. No hand edit.
Still divergent on `master` as of 2026-10-26: the 2026-10-25 fixture change only renamed
`ALTA/MEDIA/BAIXA` to `HIGH/MEDIUM/LOW`.

## Items for Henry

See [coordination-004-006-009.md](./coordination-004-006-009.md): the edits to files merged by
003/006/009 and the two baseline requests. The Evidence convention is no longer a request: it is
defined on the real Evidence DTO (006).
