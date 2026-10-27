# Quickstart: validate the Validator and reference data

Validation guide for feature 004 (revised 2026-10-26). Shapes: [data-model.md](./data-model.md),
[contracts/validation-input.md](./contracts/validation-input.md),
[contracts/reason-codes.md](./contracts/reason-codes.md).

## Prerequisites

- The dev container up (`sh dev/aihub/up.sh up`, container `signalnoir-iris`, `IRISAPP`) and the code
  compiled twice on a fresh container (`dev/aihub/README.md`); iris-agentic-dev configured.
- Baseline: the suites already on `master` pass before you change anything.

Run suites through iris-agentic-dev as in `dev/aihub/README.md`:

```sh
iris-agentic-dev exec --container signalnoir-iris -n IRISAPP \
  'set ^UnitTestRoot="/home/irisowner/dev/tests" do ##class(%UnitTest.Manager).RunTest("SignalNoir","/noload/nodelete/recursive")'
```

## 1. Core suites (primary check, no HTTP, no persistence)

- `SignalNoir.Tests.Core.Validator.TestCatalogParams` — Story 1
- `SignalNoir.Tests.Core.Validator.TestMappings` — Story 2
- `SignalNoir.Tests.Core.Validator.TestEvidenceConfidenceIdentity` — Story 3
- `SignalNoir.Tests.Core.Validator.TestApprovalPolicy` — Story 4
- `SignalNoir.Tests.Core.Validator.TestPreconditions` — Story 5
- `SignalNoir.Tests.Core.Validator.TestPriorReceipt` — Story 7
- `SignalNoir.Tests.Core.Validator.TestDeterminismNoIo` — FR-016, SC-003, SC-005

**Expected**: all pass; every test validates its input twice and compares the verdicts; the static
scan finds no I/O in the Core validator classes; 1000 validations average ≤ 50 ms.

## 2. Fixture agreement

`SignalNoir.Tests.Core.Validator.TestFixtureVerdicts` rebuilds the input of each verdict found in
`contracts/fixtures/*.json` and compares reasons and `requiresApproval`.

**Expected**: 12 of the 13 verdicts match; `resolution.201.action.json` is the known divergence until
the fixtures are regenerated (contract-change §Fixture divergence).

## 3. Reference data (Story 6)

- `SignalNoir.Tests.Application.Reference.TestStore` — loads 2026.10.1; a test-only version B without
  `map_glicj_soro` changes the verdict to `MAPPING_NOT_FOUND`; a run pinned to 2026.10.1 still
  accepts; malformed fixtures (unknown condition field, duplicate id, unknown policy key,
  out-of-range value) are refused and the versions in force do not change.
- `SignalNoir.Tests.Application.Reference.TestMappingsMatchContractFixture` — 2026.10.1 items equal
  `contracts/fixtures/reference.mappings.json` items.
- `SignalNoir.Tests.Application.Reference.TestReferenceTools` — `tool.policies` and
  `tool.mapping_catalog` return the data in force through `LocalSource`, with `synonyms`; absence when
  nothing is loaded.

## 4. The adapter and recording (FR-018)

`SignalNoir.Tests.Application.TestResolutionValidator`: open a Case, record Evidence, create a
Proposal through the investigation path and through `ResolveReview`.

**Expected**: the verdict stored on the Proposal and the `ValidatorVerdict` event carry
`verdict`, `reasons`, `requiresApproval` and `versions`; a blocked Proposal routes the Case to
`ReviewRequired`; `caseVersion` is bumped only by the transitions, as before.

## 5. Reference endpoints (FR-026)

```sh
curl -s http://localhost:52773/signalnoir/api/v1/reference/action-catalog
curl -s "http://localhost:52773/signalnoir/api/v1/reference/mappings?sourceCode=GLIC-J"
```

**Expected**: four catalog entries with `requiredEvidence` filled and `requiresApproval: false` for
`HOLD` and `REQUEST_REVIEW`; two `GLIC-J` Mappings with `mappingVersion: "2026.10.1"` (no longer
`"unloaded"`). The existing `TestResolutionApi` and the console tests (`ui/tests`) keep passing.
