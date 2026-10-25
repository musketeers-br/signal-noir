# Quickstart: validate the Validator and reference data

Validation guide for feature 004. Shapes: [data-model.md](./data-model.md),
[contracts/validation-input.md](./contracts/validation-input.md),
[contracts/reason-codes.md](./contracts/reason-codes.md).

## Prerequisites

- Dev container (build 154) up, module loaded, iris-agentic-dev configured (`IRISAPP`).
- The seam v2 change applied (research D2).

## 1. Core suites (primary check, no HTTP, no persistence)

Run through iris-agentic-dev:

- `SignalNoir.Tests.Core.Validator.TestCatalogParams` — Story 1
- `SignalNoir.Tests.Core.Validator.TestMappings` — Story 2
- `SignalNoir.Tests.Core.Validator.TestEvidenceConfidenceIdentity` — Story 3
- `SignalNoir.Tests.Core.Validator.TestApprovalPolicy` — Story 4
- `SignalNoir.Tests.Core.Validator.TestPreconditions` — Story 5
- `SignalNoir.Tests.Core.Validator.TestPriorReceipt` — Story 7
- `SignalNoir.Tests.Core.Validator.TestDeterminismNoIo` — FR-016, SC-003, SC-005

**Expected**: all pass; every test validates its input twice and compares the verdicts; the
static scan finds no I/O in the Core validator classes; 1000 validations average ≤ 50 ms.

## 2. Fixture agreement

`SignalNoir.Tests.Core.Validator.TestFixtureVerdicts` rebuilds the input of each verdict found in
`contracts/fixtures/*.json` and compares reasons and `requiresApproval`.

**Expected**: 13 match; `resolution.201.action.json` is reported as the known divergence until the
fixtures are regenerated (contract-change §Fixture divergence).

## 3. Reference data (Story 6)

- `SignalNoir.Tests.Application.Reference.TestStore` — loads 2026.10.1; a test-only version B without
  `map_glicj_soro` changes the verdict to `MAPPING_NOT_FOUND`; a run pinned to 2026.10.1 still
  accepts; a malformed fixture (unknown Action, unknown condition field, duplicate id, approval-free
  `RETRY`) is refused and the versions in force do not change.
- `SignalNoir.Tests.Application.Reference.TestMappingsMatchContractFixture` — 2026.10.1 items equal
  `contracts/fixtures/reference.mappings.json` items.

## 4. Recording (FR-018)

`SignalNoir.Tests.Application.TestValidationRecorded`: open a Case (001 path), call
`ValidationService.ValidateAndRecord` with a blocked Proposal, read the timeline.

**Expected**: one `ValidatorVerdict` event with `refId = proposalId` and the verdict payload;
`caseVersion` unchanged.

## 5. Reference endpoints (FR-026)

Until G1 wires the forward, tests use a test-only web application:

```sh
curl -s http://localhost:<52773 host port>/signalnoir/test/reference/action-catalog
curl -s "http://localhost:<52773 host port>/signalnoir/test/reference/mappings?sourceCode=GLIC-J"
```

**Expected**: four catalog entries with `externalEffect`, `requiresApproval`, `paramsSchema`,
`requiredEvidence`; two `GLIC-J` Mappings with `mappingVersion: "2026.10.1"`. Responses validate
against `contracts/openapi-signalnoir.yaml` with the capture validator of
`tests/reference-contract/`. After G1, the same calls work under `/signalnoir/api/v1/reference/…`.
