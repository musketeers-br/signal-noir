# G1 integration notes for 004

For the integrator of gate G1. Three things 004 leaves for the integration, and two it leaves open
for 007 and 008. Nothing here changes `contracts/openapi-signalnoir.yaml`.

## 1. Fix the prototype mock, regenerate the fixtures, flip T041

**Done on 2026-10-31** (branch `g1-regenerate-fixtures-004`): the mock was fixed as in the table
below, the exporter regenerated the fixtures (only `resolution.201.action.json` changed, and the
other 24 came out byte for byte), `validate_fixtures.py` reports 25 valid and 0 invalid, and
`TestFixtureVerdicts.TestResolution201` is now the same equality as the other twelve. The text that
follows is what was done and why. Two guards of the prototype that are not Validator rules kept
their own codes (`ALREADY_IN_REVIEW`, `POLICY_CODE_DISCONTINUED`): they are in no fixture.

`contracts/fixtures/resolution.201.action.json` records the verdict of an Operator's conditional
Mapping (`map_glicj_plasma`, with its Evidence in) as `[ACTION_IN_CATALOG, PARAMS_VALID]`. The rules
of 004 give `[ACTION_IN_CATALOG, PARAMS_VALID, MAPPING_CONDITION_MATCHES, REQUIRED_EVIDENCE_PRESENT]`
(research D3). Principle III forbids a lighter rule for the Operator, so the mock is wrong, not the
rule. The fixture is generated, so it is never edited by hand (`contracts/fixtures/README.md`).

**The mock.** `validateOperatorAction` in
`_bmad-output/initiative-signal-noir/prototype-signal-noir/engine.js` builds the verdict with codes
of its own. Bring it to the closed list of `contracts/reason-codes.md`:

| The mock says | It should say |
|---|---|
| `MAPPING_UNKNOWN`, `MAPPING_VERSION_MISMATCH` | `MAPPING_NOT_FOUND` |
| `MAPPING_SOURCE_CODE_MISMATCH` | `MAPPING_SOURCE_CODE_ABSENT` |
| `MAPPING_CONDITION_MISMATCH` | unchanged |
| `IDENTITY_UNRESOLVED` | `IDENTITY_AMBIGUOUS_NO_AUTOMATIC_ACTION` (a review, not a block) |
| `ALREADY_IN_REVIEW`, `POLICY_CODE_DISCONTINUED` | not codes of 004: `REQUEST_REVIEW` is always accepted, and a discontinued code is the Partner's answer, not a Validator rule |
| accepted: `[ACTION_IN_CATALOG, PARAMS_VALID]` | the pass codes of the steps that apply, in step order: `PARAMS_VALID` only for `APPLY_APPROVED_MAPPING`; `MAPPING_CONDITION_MATCHES` only when the Mapping has conditions; `RETRY_BUDGET_AVAILABLE` only for `RETRY`; then `REQUIRED_EVIDENCE_PRESENT`; `REQUEST_REVIEW` gives `[REVIEW_ALWAYS_ACCEPTED]` |

`requiresApproval` is `false` for `HOLD`, `REQUEST_REVIEW` and `prior_receipt_confirmed`; the mock
already does this.

**Regenerate and check:**

```sh
node _bmad-output/initiative-signal-noir/prototype-signal-noir/tools/export-api-fixtures.js contracts/fixtures
uv run --with jsonschema --with pyyaml python contracts/tools/validate_fixtures.py
```

**Flip T041.** `TestFixtureVerdicts.TestResolution201IsTheKnownDivergence` fails on purpose once the
fixture is regenerated: its last two assertions state the divergence. Replace the test by the same
`Agree`-style equality the other twelve use: the verdict computed by 004 equals the one recorded in
the fixture. After that, all 13 verdicts agree and the test class has no exception.

The other fixtures use the mock's older Evidence shape (`patient.id`, `catalogVersion`, `orders` and
`receipts`). `TestFixtureVerdicts` translates the shape and nothing else. If the mock is moved to
the shapes of `contracts/validation-input.md`, the translation in `TestFixtureVerdicts` (the methods
`Snapshot`, `Receipts` and `Evidence`) can be deleted.

## 2. `identity` is not a field of `ValidationInput`

Checked on 2026-10-31: the `ValidationInput` row of `docs/seams.md` and of its copy,
`specs/001-runtime-skeleton-and-seams/contracts/seams.md`, no longer lists `identity`, and the
paragraph below the port says the Validator derives it from `evidence` and `order` with
`SignalNoir.Core.Identity`. Nothing is left to do. If a document still shows an `identity` input,
it predates the contract change (`contract-change-004-validator-seam.md`).

## 3. Rules and the specimen synonyms (coordination request 1)

Accepted by Henry on 2026-10-31 for his wave 4. `SignalNoir.Core.Conditions.Matches(conditions,
order, synonyms)` is available on this branch: `Proposers/Rules` should call it with
`result.synonyms` from `tool.mapping_catalog`, instead of its upper-case equality on
`specimen.type`. Until then Rules finds no Mapping for an Order written `soro` where the Validator
would accept one. The same Henry commitment covers a test that pins `requiresApproval` of
`REQUEST_REVIEW` between the catalog endpoint and the verdict; `TestReferenceEndpoints` already holds
that equality on the 004 side.

## Open for 007 and 008

- **Pinned versions of a BenchmarkRun (007).** `Store.For(run)` honours `run.policyVersion` and
  `run.mappingVersion` (tested), and `ResolutionValidator.RunFor(rec)` is the one place that says
  which run a Case belongs to, for the Validator input and for the Tools. No record stores the
  versions a run pins yet, so `RunFor` returns them as `null` and the versions in force apply. When
  007 records them, `RunFor` is the only place to change.
- **Attempt count (008).** `ResolutionValidator.InputFor` passes `attemptCount = 0` until 008
  records Attempts. `RETRY_BUDGET_EXHAUSTED` is exercised in 004's tests with a supplied count.
- **Revalidation (008).** `Revalidate(input, .results)` is pure; recording `RevalidationPerformed`
  and the transition to `Held` stay in 008. It reads the values of `input.observed` described in
  `contracts/validation-input.md`.
- **Prior Receipt (011).** The verdict `prior_receipt_confirmed` exists and `InputFor` supplies the
  candidate's Order snapshot from the Case's Evidence. `CaseService.RouteProposal` sends any verdict
  other than `accepted` to `ReviewRequired`, so what the Case does on a confirmation is 011's.
