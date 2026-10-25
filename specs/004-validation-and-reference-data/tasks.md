---

description: "Task list for feature 004 — Validator and Versioned Reference Data"
---

# Tasks: Validator and Versioned Reference Data

**Input**: Design documents from `specs/004-validation-and-reference-data/`

**Prerequisites**: [plan.md](./plan.md), [spec.md](./spec.md), [research.md](./research.md),
[data-model.md](./data-model.md), [contracts/](./contracts/), [quickstart.md](./quickstart.md)

**Tests**: MANDATORY (Constitution, TDD; Principle IX). Every implementation task is preceded by a
task that writes the failing test; ObjectScript tests run on the live instance through
iris-agentic-dev.

**Calendar gate**: no task that writes code under `src/` or `tests/` may start before 2026-10-26.

**Write zone**: `src/SignalNoir/Core/{Validator,Reasons,Conditions,Catalog}.cls`,
`src/SignalNoir/Core/Port/Validator.cls`,
`src/SignalNoir/Core/Dto/{Proposal,ValidatorVerdict,ValidationInput,PreconditionResult,Admission,ReferenceData}.cls`,
`src/SignalNoir/Application/ValidationService.cls`, `src/SignalNoir/Application/Reference/**`,
`src/SignalNoir/Api/Reference.cls`, `tests/SignalNoir/Tests/Core/Validator/**`,
`tests/SignalNoir/Tests/Application/Reference/**`,
`tests/SignalNoir/Tests/Application/TestValidationRecorded.cls`,
`tests/SignalNoir/Tests/Api/TestReference.cls`, `tests/reference-contract/**`, the three seam files
named in T003/T006, and `specs/004-validation-and-reference-data/**`. Integration changes are listed
for G1 (T046).

**Conventions used by every task**

- Core classes do no I/O: no globals, no `%Persistent`, `%Net`, `%File`, SQL, `$ZF`, `$HOROLOG`,
  `$ZTIMESTAMP`, `$NOW`, `$RANDOM`, device commands (research D13). Time comes from `input.now`.
- Verdict composition and the reasons rule follow research D3 exactly; reason codes come only from
  [contracts/reason-codes.md](./contracts/reason-codes.md).
- Input shape follows [contracts/validation-input.md](./contracts/validation-input.md).
- Every Core test validates each input twice and asserts identical serialized verdicts.
- Test style follows `tests/SignalNoir/Tests/Core/TestCaseMachine.cls` (`%UnitTest.TestCase`, one
  `Method Test…` per acceptance scenario, message names the scenario).

## Format: `[ID] [P?] [Story] Description`

---

## Phase 1: Setup

- [ ] T001 Confirm specs/004-validation-and-reference-data/research.md "Verification log" has V1 (compiled XData readable, package classes listable), V2 (`%CSP.REST` `<Map Forward>`) and V3 (test-only web application from `%UnitTest`) recorded as passing; if any is missing, stop
- [ ] T002 [P] Create tests/reference-contract/validate_reference_captures.py mirroring contracts/tools/validate_fixtures.py against `contracts/openapi-signalnoir.yaml` (schemas: the 200 response of `getActionCatalog` and `listApprovedMappings` by JSON pointer), with tests/reference-contract/captures/manifest.json = `{"fixtures": []}`; fail when either operationId has no capture

---

## Phase 2: Foundational (seam v2, DTOs, vocabularies, test inputs)

**⚠️ CRITICAL**: blocks every story.

- [ ] T003 Write failing seam tests for v2: update tests/SignalNoir/Consumer/Consumer.cls to build a `ValidationInput` and call `Validate`, `Revalidate` and `Admit` on the port, and tests/SignalNoir/Tests/Seam/TestConsumerUsesSeam.cls to assert `verdict = "accepted"`, `requiresApproval = 1`, `reasons` = `[ACTION_IN_CATALOG]` from the fake (docs/seams.md v2)
- [ ] T004 [P] Write failing tests/SignalNoir/Tests/Core/Validator/TestDtos.cls: `ValidationInput.FromJson` accepts the example of contracts/validation-input.md and exposes every field; `ValidatorVerdict.ToJson()` has exactly `verdict`, `reasons`, `requiresApproval`, `at` (+ `versions`) with the contract types; `PreconditionResult.ToJson()` matches the contract `PreconditionResult`
- [ ] T005 Implement src/SignalNoir/Core/Dto/ValidatorVerdict.cls (v2), extend src/SignalNoir/Core/Dto/Proposal.cls (`scope`, `confidence`, `preconditions`, `versions`, `priorReceiptCandidate`), and create src/SignalNoir/Core/Dto/ValidationInput.cls, PreconditionResult.cls, Admission.cls, ReferenceData.cls with `FromJson`/`ToJson`, until T004 passes
- [ ] T006 Implement the v2 port in src/SignalNoir/Core/Port/Validator.cls (abstract `Validate(input)`, `Revalidate(input)` returning the verdict plus a list of `PreconditionResult`, `Admit(actor, run)`), and tests/SignalNoir/Tests/Fakes/FakeValidator.cls v2 (configurable verdict, results, admission; defaults per docs/seams.md v2), until T003 passes and tests/SignalNoir/Tests/Seam/TestFakesNotRuntime.cls still passes
- [ ] T007 [P] Write failing tests/SignalNoir/Tests/Core/Validator/TestReasons.cls: the list equals contracts/reason-codes.md (32 codes, in table order), every code has a non-empty English text, `IsReason` rejects anything else, and the 9 fixture codes are present
- [ ] T008 Implement src/SignalNoir/Core/Reasons.cls (`Parameter CODES`, `Text(code)`, `IsReason(code)`, `Order(code)`, `Kind(code)`) until T007 passes
- [ ] T009 [P] Write failing tests/SignalNoir/Tests/Core/Validator/TestCatalog.cls: exactly the four Actions with `externalEffect`, `paramsSchema` and `requiredEvidence` per data-model "Action catalog"; `IsAction` agrees with `SignalNoir.Core.Vocab.IsAction`
- [ ] T010 Implement src/SignalNoir/Core/Catalog.cls (entries as data-model, `ParamsValid(action, params)`, `RequiredEvidence(action)`, `Entries()` as `ActionCatalogEntry` JSON without `requiresApproval`, which comes from policy) until T009 passes
- [ ] T011 Create the test-only builder tests/SignalNoir/Tests/Core/Validator/Inputs.cls: an in-memory `ReferenceData` equal to policy and mappings 2026.10.1 (data-model), Orders `plasmaOrder`/`serumOrder`/`legacyTshOrder` (raw, lower-case `plasma`/`soro`), Evidence sets complete per Action, and `Proposal(action, params, confidence)` helpers; no persistence

**Checkpoint**: seam v2 compiles and its consumer test passes; vocabularies ready.

---

## Phase 3: User Story 1 — Only catalog Actions with valid parameters pass (P1) 🎯 MVP

**Goal**: steps 1–4 of the pipeline, verdict composition, and recording on the Case.

**Independent Test**: quickstart §1 (TestCatalogParams) and §4 (recording).

- [ ] T012 [P] [US1] Write failing tests/SignalNoir/Tests/Core/Validator/TestCatalogParams.cls covering spec US1 AS1–AS6 and the edge cases "missing Action / confidence / versions → blocked, never an exception" and "same Proposal from agent, rules, operator, benchmark origins → identical verdict" (FR-017)
- [ ] T013 [US1] Implement in src/SignalNoir/Core/Validator.cls the pipeline frame (research D3): steps 1–4, the `REQUEST_REVIEW` short-circuit, block/review/accepted composition, reasons rule and `requiresApproval` placeholder from `reference.policies.approval`, `at = input.now`, versions from the snapshot; until T012 passes
- [ ] T014 [P] [US1] Write failing tests/SignalNoir/Tests/Application/TestValidationRecorded.cls: open a Case through `SignalNoir.Application.CaseService`, call `ValidateAndRecord(caseId, input)` with a blocked Proposal; timeline has one `ValidatorVerdict` event with `refId = proposalId`, payload `{proposalId, verdict, reasons, requiresApproval, versions}`, actor = origin actor; `caseVersion` unchanged; returns the verdict
- [ ] T015 [US1] Implement src/SignalNoir/Application/ValidationService.cls `ValidateAndRecord(caseId, input)` (Core `Validator.Validate`, then `CaseService.Default().Append` with a `TimelineEvent` of type `ValidatorVerdict`) until T014 passes
- [ ] T016 [US1] Run T012 and T014 green through iris-agentic-dev

**Checkpoint**: 006/009 can call `ValidateAndRecord`; unknown Actions never pass.

---

## Phase 4: User Story 2 — A Mapping is applied only when it exists and its conditions match (P1)

**Goal**: step 6 with canonical condition matching.

**Independent Test**: quickstart §1 (TestMappings).

- [ ] T017 [P] [US2] Write failing tests/SignalNoir/Tests/Core/Validator/TestConditions.cls: `specimenType` against `specimen.type` matches `plasma`→`PLASMA`, `soro`→`SERUM`, with spaces and mixed case; `specimenUnit` against `specimen.unit`; empty conditions always match; absent Order field never matches; source code found among `exams[].code` case-insensitively
- [ ] T018 [US2] Implement src/SignalNoir/Core/Conditions.cls (`Canonical(field, value, synonyms)`, `Matches(conditions, order, synonyms)`, `HasSourceCode(order, code)`, field→path table per research D7) until T017 passes
- [ ] T019 [P] [US2] Write failing tests/SignalNoir/Tests/Core/Validator/TestMappings.cls covering spec US2 AS1–AS5 (plasma accepted with `MAPPING_CONDITION_MATCHES`; serum blocked `MAPPING_CONDITION_MISMATCH`; unknown id or version `MAPPING_NOT_FOUND`; missing source code `MAPPING_SOURCE_CODE_ABSENT`; unconditional `map_tsh_legacy` accepted without `MAPPING_CONDITION_MATCHES` in reasons) and SC-006 (exactly one of the two `GLIC-J` Mappings accepted per Order)
- [ ] T020 [US2] Add step 6 to src/SignalNoir/Core/Validator.cls using `Conditions` and `input.reference.mappings` until T019 passes
- [ ] T021 [US2] Run T017 and T019 green

**Checkpoint**: P8b's wrong-Mapping effect is impossible through the Validator.

---

## Phase 5: User Story 3 — Unsupported, unconfident or identity-ambiguous Proposals go to review (P1)

**Goal**: steps 7, 9, 10, 11.

**Independent Test**: quickstart §1 (TestEvidenceConfidenceIdentity).

- [ ] T022 [P] [US3] Write failing tests/SignalNoir/Tests/Core/Validator/TestEvidenceConfidenceIdentity.cls covering spec US3 AS1–AS7 and the edge cases: obsolete, suspicious and other-Case Evidence do not count; several failures at once → `blocked` over `review` with every fail code in step order; `REQUEST_REVIEW` with ambiguous identity → `accepted` with `[REVIEW_ALWAYS_ACCEPTED, IDENTITY_AMBIGUOUS_NO_AUTOMATIC_ACTION]`
- [ ] T023 [US3] Add steps 7 (retry budget from `reference.policies.attempt.maxAttempts` and `input.attemptCount`), 9 (identity), 10 (minimum Evidence by the source/facts convention of contracts/validation-input.md, via `Catalog.RequiredEvidence`) and 11 (confidence `BAIXA`) to src/SignalNoir/Core/Validator.cls until T022 passes
- [ ] T024 [US3] Run T022 green

**Checkpoint**: the Dossier path (009) has its trigger reasons.

---

## Phase 6: User Story 4 — The approval policy decides who must approve (P1)

**Goal**: `requiresApproval` from policy and `Admit`.

**Independent Test**: quickstart §1 (TestApprovalPolicy).

- [ ] T025 [P] [US4] Write failing tests/SignalNoir/Tests/Core/Validator/TestApprovalPolicy.cls covering spec US4 AS1–AS5 plus: `prior_receipt_confirmed` never requires approval; `Admit` refuses `agent`, `rules`, `system`, `sweeper`, `replay` with `ACTOR_NOT_ALLOWED_TO_APPROVE`
- [ ] T026 [US4] Implement `requiresApproval` from `reference.policies.approval` in the composition and `Admit(actor, run)` in src/SignalNoir/Core/Validator.cls until T025 passes
- [ ] T027 [US4] Run T025 green

**Checkpoint**: 007 can decide whether to wait for a human and which approver is admissible.
**MVP (G1-ready)**: Phases 1–6.

---

## Phase 7: User Story 5 — Preconditions are re-checked from a closed vocabulary (P2)

**Goal**: step 5 (declared preconditions known) and step 8 (`Revalidate`).

**Independent Test**: quickstart §1 (TestPreconditions).

- [ ] T028 [P] [US5] Write failing tests/SignalNoir/Tests/Core/Validator/TestPreconditions.cls covering spec US5 AS1–AS8 and SC-007 (each observed value changed alone fails exactly its check); every `PreconditionResult` has `expected`, `observed`, `passed` and the `evidenceId` from `observed` when present
- [ ] T029 [US5] Add step 5 to `Validate` and implement `Revalidate(input)` with step 8 in src/SignalNoir/Core/Validator.cls per research D12 and FR-021 (health `UP`, `errorRate ≤ policies.partnerHealth.maxErrorRate`, no maintenance from Partner or `policies.maintenanceWindows` at `now`; origin `active`; approval for this `proposalId`, `now < deadline`, `proposalCurrent`; versions equal; mapping exists) until T028 passes
- [ ] T030 [US5] Write failing assertions in tests/SignalNoir/Tests/Application/TestValidationRecorded.cls for `RevalidateAndRecord` (actor `system`, payload includes `preconditionResults`), then implement it in src/SignalNoir/Application/ValidationService.cls
- [ ] T031 [US5] Run T028 and T030 green

**Checkpoint**: 008's Revalidation has its rule.

---

## Phase 8: User Story 6 — Reference data is versioned, pinnable and readable (P2)

**Goal**: fixtures, store, pinning, reference endpoints.

**Independent Test**: quickstart §3 and §5.

- [ ] T032 [P] [US6] Write failing tests/SignalNoir/Tests/Application/Reference/TestStore.cls covering spec US6 AS1, AS2, AS5 and FR-027: discovery of fixture classes from a package argument (tests pass `SignalNoir.Tests.Application.Reference.Fixtures`), test-only fixtures under tests/SignalNoir/Tests/Application/Reference/Fixtures/ (version `B` without `map_glicj_soro`; malformed ones: unknown Action, unknown condition field, duplicate `mappingId`, approval-free `RETRY`); refused load leaves `^SignalNoir.Reference("inForce",…)` unchanged; pinned run uses its versions; with nothing loadable every `Validate` is `blocked` `REFERENCE_DATA_UNAVAILABLE`; snapshots are immutable
- [ ] T033 [P] [US6] Write failing tests/SignalNoir/Tests/Application/Reference/TestMappingsMatchContractFixture.cls: items of `Mappings.V2026101` equal the `items` of contracts/fixtures/reference.mappings.json (read in the test, never at runtime)
- [ ] T034 [P] [US6] Create src/SignalNoir/Application/Reference/Policies/V2026101.cls and src/SignalNoir/Application/Reference/Mappings/V2026101.cls (XData JSON + `Parameter VERSION = "2026.10.1"`) with the content of data-model "Reference data"
- [ ] T035 [US6] Implement src/SignalNoir/Application/Reference/Store.cls (`Load(package)`, `Validate(fixture)`, `InForce()`, `For(run)`, `SetInForce(policyVersion, mappingVersion)`, lazy highest-version default) until T032 and T033 pass
- [ ] T036 [P] [US6] Write failing tests/SignalNoir/Tests/Api/TestReference.cls: payload methods return the contract shapes (`items`, `serverTime`; `mappingVersion`, `items`, `serverTime`; `sourceCode` filter); over HTTP through a test-only web application `/signalnoir/test/reference` (created in `OnBeforeAllTests`, removed in `OnAfterAllTests`), capture both responses into tests/reference-contract/captures/
- [ ] T037 [US6] Implement src/SignalNoir/Api/Reference.cls (`%CSP.REST`, routes `/action-catalog` and `/mappings`; `requiresApproval` per Action from the policy in force; errors with the product envelope `VALIDATION_FAILED`) until T036 passes
- [ ] T038 [US6] Run T032, T033, T036 green and the capture validator (T002)

**Checkpoint**: 005 can build the resolution form; 010 can pin versions.

---

## Phase 9: User Story 7 — Prior-receipt confirmation (P3)

**Goal**: step 12.

**Independent Test**: quickstart §1 (TestPriorReceipt).

- [ ] T039 [P] [US7] Write failing tests/SignalNoir/Tests/Core/Validator/TestPriorReceipt.cls covering spec US7 AS1–AS3, with keys computed by `SignalNoir.Core.Canon.EquivalenceKey` on `input.order` and `input.priorReceiptOrder` (mixed-case, unordered codes and a non-UTC `collectedAt` still match)
- [ ] T040 [US7] Add step 12 to src/SignalNoir/Core/Validator.cls (`prior_receipt_confirmed` with `[EQUIVALENCE_KEY_MATCH]`, `requiresApproval = 0`) until T039 passes
- [ ] T041 [US7] Run T039 green

---

## Phase 10: Polish & Cross-Cutting Concerns

- [ ] T042 Write tests/SignalNoir/Tests/Core/Validator/TestFixtureVerdicts.cls: for each verdict in contracts/fixtures/*.json, rebuild its `ValidationInput` from the fixture's Case (Proposal, Evidence, Order) and assert reasons and `requiresApproval`; 13 must match; `resolution.201.action.json` is asserted as the known divergence (research D3) so the test fails once the fixture is regenerated and the expectation must flip
- [ ] T043 Write tests/SignalNoir/Tests/Core/Validator/TestDeterminismNoIo.cls: static scan of the compiled methods of `SignalNoir.Core.Validator`, `Reasons`, `Conditions`, `Catalog` and the six DTOs (research D13); every input of `Inputs.cls` validated twice and across a fresh process (`JOB`) gives identical JSON; 1000 validations mean ≤ 50 ms (SC-005)
- [ ] T044 Walk specs/004-validation-and-reference-data/quickstart.md end to end and record results in research.md "Verification log"
- [ ] T045 Update specs/004-validation-and-reference-data/plan.md: iris-agentic-dev gate to pass citing V1–V3, or list what failed
- [ ] T046 [P] Write specs/004-validation-and-reference-data/contracts/g1-integration.md for the integrator: (1) add `<Map Prefix="/reference" Forward="SignalNoir.Api.Reference"/>` to `SignalNoir.Api.Dispatch`; (2) fix the prototype mock for `resolution.201.action.json` and regenerate fixtures, then flip T042's expectation; (3) Evidence `source`/`facts` convention confirmed with 006 (Henry)
- [ ] T047 [P] Review the diff against the Constitution, spec, plan and tests: no file outside the write zone; `contracts/` untouched; Core classes pass the no-I/O scan; `origin` read by no rule

---

## Dependencies & Execution Order

```text
Setup → Foundational → US1 → US2 ─┐
                          ├─> US3 ─┼─> US4 → (MVP / G1) → US5 → US6 → US7 → Polish
                          └────────┘
```

- **Foundational** blocks everything (seam v2 must compile first, T003–T006).
- **US1** creates the pipeline frame in `Core/Validator.cls`; **US2, US3, US4, US5, US7** each add
  steps to that same file → sequential, never in parallel.
- **US6** touches only `Application/Reference/**` and `Api/Reference.cls`; it can run in parallel with
  US2–US5 by a second pair of hands (T032–T037), because the Core tests use the in-memory snapshot of
  `Inputs.cls`.
- **Cross-feature**: 006 can start against the fake now (seam v2 on master); 007 needs US4; 008 needs
  US5; 005 needs US6; 011 needs US7.

## Parallel Examples

```text
# Foundational tests together:
T004 TestDtos · T007 TestReasons · T009 TestCatalog

# While US2–US5 extend Core/Validator.cls, US6 can proceed:
T032 TestStore · T033 TestMappingsMatchContractFixture · T034 fixtures · T036 TestReference
```

## Implementation Strategy

1. **MVP = Phases 1–6** (US1–US4): every Proposal gets a recorded, deterministic verdict with the
   approval decision — what G1 needs ("Pedido vira Caso com Proposta validada").
2. Then US5 (needed by 008 in wave 4), US6 (needed by 005 in wave 3 — schedule it right after the
   MVP if 005 starts first), US7 (conditional consumer).

## Notes

- A divergence from `contracts/openapi-signalnoir.yaml` or the fixtures stops the task and becomes a
  contract-change; never edit the contract or a fixture by hand.
- Commit after each task or logical group.
