---

description: "Task list for feature 004 — Validator and Versioned Reference Data (revised 2026-10-26)"
---

# Tasks: Validator and Versioned Reference Data

**Input**: Design documents from `specs/004-validation-and-reference-data/`

**Prerequisites**: [plan.md](./plan.md), [spec.md](./spec.md), [research.md](./research.md),
[data-model.md](./data-model.md), [contracts/](./contracts/), [quickstart.md](./quickstart.md)

**Revision 2026-10-26**: rewritten against `master` (003, 005, 006, 009 merged). Dropped:
`Core.Catalog`, `ValidationService`, `Api.Reference`, the test web application, the reference capture
validator. Added: edits to the files that already exist (marked **[edit]**), the adapter task, the
Tools task. The reference-data Store moved to the foundation because the adapter and pipeline step 1
need a snapshot.

**Tests**: MANDATORY (Constitution, TDD; Principle IX). Every implementation task is preceded by a
task that writes the failing test; ObjectScript tests run on the live instance through
iris-agentic-dev (`dev/aihub/README.md`).

**Calendar gate**: satisfied (code allowed from 2026-10-26).

**Write zone**: new files — `src/SignalNoir/Core/{Reasons,Conditions}.cls`,
`Core/Dto/{ValidationInput,PreconditionResult,Admission,ReferenceData}.cls`,
`src/SignalNoir/Application/Reference/**`, `tests/SignalNoir/Tests/Core/Validator/**`,
`tests/SignalNoir/Tests/Application/Reference/**`,
`tests/SignalNoir/Tests/Application/TestResolutionValidator.cls`, `specs/004-validation-and-reference-data/**`.
Edits to existing files (**[edit]**, each in [contracts/coordination-004-006-009.md](./contracts/coordination-004-006-009.md)
and agreed with Henry at T002): `Core/Validator.cls`, `Core/Port/Validator.cls`,
`Core/Dto/ValidatorVerdict.cls`, `Core/ActionCatalog.cls`, `Application/ResolutionValidator.cls`,
`Application/CaseService.cls`, `Tools/LocalSource.cls`, `Api/Dispatch.cls`,
`tests/.../Fakes/FakeValidator.cls`, `tests/.../Consumer/Consumer.cls`,
`tests/.../Seam/TestConsumerUsesSeam.cls`, `tests/.../Application/{TestResolution,TestDossier}.cls`,
`tests/.../Core/TestActionCatalog.cls`.

**Conventions used by every task**

- Core classes do no I/O: no globals, no `%Persistent`, `%Net`, `%File`, SQL, `$ZF`, `$HOROLOG`,
  `$ZTIMESTAMP`, `$NOW`, `$RANDOM`, device commands (research D13). Time comes from `input.now`.
- Verdict composition and the reasons rule follow research D3 exactly; reason codes come only from
  [contracts/reason-codes.md](./contracts/reason-codes.md); confidence is `HIGH`/`MEDIUM`/`LOW`.
- Input and Evidence recognition follow [contracts/validation-input.md](./contracts/validation-input.md):
  only `kind = fact`, same `caseId`, empty `obsoletedBy`, `suspicious = false` counts.
- Every Core test validates each input twice and asserts identical serialized verdicts.
- Test style follows `tests/SignalNoir/Tests/Core/TestCaseMachine.cls` and
  `tests/SignalNoir/Tests/Core/TestActionCatalog.cls`.
- After each **[edit]** task the whole suite already on `master` stays green
  (`RunTest("SignalNoir","/noload/nodelete/recursive")`).

## Format: `[ID] [P?] [Story] Description`

---

## Phase 1: Setup

- [x] T001 Confirm specs/004-validation-and-reference-data/research.md "Verification log" has V1 recorded as passing, and record in the same log that the suites already on `master` pass on the dev container (baseline, compiled twice on a fresh container); if either is missing, stop
- [x] T002 Walk specs/004-validation-and-reference-data/contracts/coordination-004-006-009.md with Henry (edits 1–6 and the two baseline requests) and record his decision at the end of that file; do not start a task marked **[edit]** on a file he has not agreed to

---

## Phase 2: Foundational (seam v2, vocabularies, reference data)

**⚠️ CRITICAL**: blocks every story.

### Seam v2 and vocabularies

- [x] T003 **[edit]** Write failing v2 tests: tests/SignalNoir/Consumer/Consumer.cls builds a `ValidationInput` and calls `Validate`, `Revalidate` and `Admit` on the port; tests/SignalNoir/Tests/Seam/TestConsumerUsesSeam.cls asserts `verdict = "accepted"`, `requiresApproval = 1`, `reasons` = `[ACTION_IN_CATALOG]` from the fake; tests/SignalNoir/Tests/Application/TestResolution.cls and TestDossier.cls set `FakeValidator.Verdict = "blocked"` instead of `"invalid"`
- [x] T004 [P] Write failing tests/SignalNoir/Tests/Core/Validator/TestDtos.cls: `ValidationInput.FromJson` accepts the example of contracts/validation-input.md (no `identity` field) and exposes every field; `ValidatorVerdict.ToJson()` has `verdict`, `reasons`, `requiresApproval`, `at`, `versions` with the contract types; `PreconditionResult.ToJson()` matches the contract `PreconditionResult`
- [x] T005 **[edit]** Rewrite src/SignalNoir/Core/Dto/ValidatorVerdict.cls (v2) and create src/SignalNoir/Core/Dto/ValidationInput.cls, PreconditionResult.cls, Admission.cls, ReferenceData.cls with `FromJson`/`ToJson`, until T004 passes (`Proposal` and `Evidence` are used as they are on `master`)
- [x] T006 **[edit]** Implement the v2 port in src/SignalNoir/Core/Port/Validator.cls (abstract `Validate(input)`, `Revalidate(input)` returning the verdict plus `PreconditionResult[]`, `Admit(actor, run)`) and tests/SignalNoir/Tests/Fakes/FakeValidator.cls v2 (configurable verdict, results, admission; defaults per docs/seams.md), until T003 passes; src/SignalNoir/Application/ResolutionValidator.cls keeps accepting `valid` and `accepted` so the suites stay green until T019
- [x] T007 [P] Write failing tests/SignalNoir/Tests/Core/Validator/TestReasons.cls: the list equals contracts/reason-codes.md (32 codes, in table order), every code has a non-empty English text, `IsReason` rejects anything else, the 9 fixture codes are present
- [x] T008 Implement src/SignalNoir/Core/Reasons.cls (`Parameter CODES`, `Text(code)`, `IsReason(code)`, `Order(code)`, `Kind(code)`) until T007 passes
- [x] T009 [P] **[edit]** Extend tests/SignalNoir/Tests/Core/TestActionCatalog.cls with failing assertions: `RequiresApproval` equals `ExternalEffect` for all four Actions (`REQUEST_REVIEW` false); `Entries()` fills `requiredEvidence` per data-model "Action catalog"; `Entries()` reports `requiresApproval: false` for `HOLD` and `REQUEST_REVIEW`
- [x] T010 **[edit]** In src/SignalNoir/Core/ActionCatalog.cls make `RequiresApproval` return `ExternalEffect(action)` and fill `requiredEvidence` in `Entries()` (coordination item 3), until T009 and the existing catalog tests pass

### Reference data

- [x] T011 Create the test-only builder tests/SignalNoir/Tests/Core/Validator/Inputs.cls: an in-memory `ReferenceData` literal equal to policy and mappings 2026.10.1 (data-model), Orders `plasmaOrder`/`serumOrder`/`legacyTshOrder` (raw, lower-case `plasma`/`soro`), Evidence sets complete per Action (real Evidence DTO: `source`, `kind = fact`, `result` with the keys of contracts/validation-input.md), a colliding-patient Evidence, and `Proposal(action, params, confidence)` helpers; no persistence
- [x] T012 [P] Write failing tests/SignalNoir/Tests/Application/Reference/TestStore.cls: discovery of fixture classes from a package argument (tests pass `SignalNoir.Tests.Application.Reference.Fixtures`); test-only fixtures under tests/SignalNoir/Tests/Application/Reference/Fixtures/ (version `B` without `map_glicj_soro`; malformed: unknown condition field, duplicate `mappingId`, unknown policy key, out-of-range value); a refused load leaves `^SignalNoir.Reference("inForce",…)` unchanged; a pinned run uses its versions; nothing loadable → `For(run)` fails; snapshots are immutable; the 2026.10.1 snapshot equals `Inputs.Reference()`
- [x] T013 [P] Write failing tests/SignalNoir/Tests/Application/Reference/TestMappingsMatchContractFixture.cls: items of `Mappings.V2026101` equal the `items` of contracts/fixtures/reference.mappings.json (read in the test, never at runtime)
- [x] T014 [P] Create src/SignalNoir/Application/Reference/Policies/V2026101.cls and src/SignalNoir/Application/Reference/Mappings/V2026101.cls (XData JSON + `Parameter VERSION = "2026.10.1"`) with the content of data-model "Reference data"
- [x] T015 Implement src/SignalNoir/Application/Reference/Store.cls (`Load(package)`, `Validate(fixture)`, `InForce()`, `For(run)`, `SetInForce(policyVersion, mappingVersion)`, lazy highest-version default, snapshot as `Core.Dto.ReferenceData`) until T012 and T013 pass

**Checkpoint**: seam v2 compiles, its consumer test passes, vocabularies and a reference snapshot exist.

---

## Phase 3: User Story 1 — Only catalog Actions with valid parameters pass (P1) 🎯 MVP

**Goal**: pipeline steps 1–4 and the composition; every Proposal reaches the v2 Validator through the adapter.

**Independent Test**: quickstart §1 (TestCatalogParams) and §4 (adapter and recording).

- [x] T016 [P] [US1] Write failing tests/SignalNoir/Tests/Core/Validator/TestCatalogParams.cls covering spec US1 AS1–AS6 and the edge cases "missing Action / confidence / versions → blocked, never an exception" and "same Proposal from agent, rules, operator, benchmark origins → identical verdict" (FR-017)
- [x] T017 [US1] **[edit]** In src/SignalNoir/Core/Validator.cls implement the pipeline frame (research D3): steps 1–4, the `REQUEST_REVIEW` short-circuit, block/review/accepted composition, reasons rule, `requiresApproval` from `ActionCatalog.RequiresApproval`, `at = input.now`, versions from the snapshot; until T016 passes
- [x] T018 [P] [US1] Write failing tests/SignalNoir/Tests/Application/TestResolutionValidator.cls: `InputFor(rec, proposal, now)` builds the input from a Case (Evidence from `ListEvidence`, Order snapshot, `runId`, attempt count 0, snapshot from `Store.For(run)`); through `CompleteInvestigation` and through `ResolveReview` the verdict stored on the Proposal and the `ValidatorVerdict` event carry `verdict`, `reasons`, `requiresApproval` and `versions`; blocked → `ReviewRequired`, accepted with effect → `PendingApproval`, `HOLD` accepted → `Executing`, as before
- [x] T019 [US1] **[edit]** Change src/SignalNoir/Application/ResolutionValidator.cls: add `InputFor(rec, proposal, now)` and make `Verdict(validator, input)` return the contract verdict with `versions` from the v2 result; change the two call sites in src/SignalNoir/Application/CaseService.cls (`CompleteInvestigation`, `ResolveReview`) to call `InputFor`, and add `versions` to the `ValidatorVerdict` event payload (coordination items 1–2), until T018 passes; drop the `valid` compatibility branch
- [x] T020 [US1] Run T016 and T018 green together with the whole suite already on `master` (TestResolution, TestDossier, TestResolutionApi, the seam tests)

**Checkpoint**: unknown Actions never pass; every Proposal gets a recorded v2 verdict. 006/009 are unchanged for their callers.

---

## Phase 4: User Story 2 — A Mapping is applied only when it exists and its conditions match (P1)

**Goal**: step 6 with canonical condition matching.

**Independent Test**: quickstart §1 (TestMappings).

- [x] T021 [P] [US2] Write failing tests/SignalNoir/Tests/Core/Validator/TestConditions.cls: `specimenType` against `specimen.type` matches `plasma`→`PLASMA`, `soro`→`SERUM`, with spaces and mixed case; `specimenUnit` against `specimen.unit`; empty conditions always match; an absent Order field never matches; source code found among `exams[].code` case-insensitively
- [x] T022 [US2] Implement src/SignalNoir/Core/Conditions.cls (`Canonical(field, value, synonyms)`, `Matches(conditions, order, synonyms)`, `HasSourceCode(order, code)`, field→path table per research D7) until T021 passes
- [x] T023 [P] [US2] Write failing tests/SignalNoir/Tests/Core/Validator/TestMappings.cls covering spec US2 AS1–AS5 (plasma accepted with `MAPPING_CONDITION_MATCHES`; serum blocked `MAPPING_CONDITION_MISMATCH`; unknown id or version `MAPPING_NOT_FOUND`; missing source code `MAPPING_SOURCE_CODE_ABSENT`; unconditional `map_tsh_legacy` accepted without `MAPPING_CONDITION_MATCHES`) and SC-006 (exactly one of the two `GLIC-J` Mappings accepted per Order)
- [x] T024 [US2] Add step 6 to src/SignalNoir/Core/Validator.cls using `Conditions` and `input.reference.mappings` until T023 passes
- [x] T025 [US2] Run T021 and T023 green

**Checkpoint**: P8b's wrong-Mapping effect is impossible through the Validator.

---

## Phase 5: User Story 3 — Unsupported, unconfident or identity-ambiguous Proposals go to review (P1)

**Goal**: steps 7, 9, 10, 11.

**Independent Test**: quickstart §1 (TestEvidenceConfidenceIdentity).

- [ ] T026 [P] [US3] Write failing tests/SignalNoir/Tests/Core/Validator/TestEvidenceConfidenceIdentity.cls covering spec US3 AS1–AS7 including AS3a, and the edge cases: obsolete (`obsoletedBy`), suspicious, `absence` and other-Case Evidence do not count; several failures at once → `blocked` over `review` with every fail code in step order; `REQUEST_REVIEW` with a colliding patient record in `tool.receipts_and_orders_by_patient` Evidence → `accepted` with `[REVIEW_ALWAYS_ACCEPTED, IDENTITY_AMBIGUOUS_NO_AUTOMATIC_ACTION]`; no input field can clear the ambiguity
- [ ] T027 [US3] Add steps 7 (retry budget from `reference.policies.attempt.maxAttempts` and `input.attemptCount`), 9 (identity via `SignalNoir.Core.Identity.Collisions(evidence, order)`), 10 (minimum Evidence per contracts/validation-input.md, requirements from `ActionCatalog` entries) and 11 (confidence `LOW`) to src/SignalNoir/Core/Validator.cls until T026 passes
- [ ] T028 [US3] Run T026 green

**Checkpoint**: the Dossier path (009) has its trigger reasons from the Validator.

---

## Phase 6: User Story 4 — The approval policy decides who must approve (P1)

**Goal**: `requiresApproval` and `Admit`.

**Independent Test**: quickstart §1 (TestApprovalPolicy).

- [ ] T029 [P] [US4] Write failing tests/SignalNoir/Tests/Core/Validator/TestApprovalPolicy.cls covering spec US4 AS1–AS5 plus: `prior_receipt_confirmed` never requires approval; `Admit` refuses `agent`, `rules`, `system`, `sweeper`, `replay` with `ACTOR_NOT_ALLOWED_TO_APPROVE`; the verdict's `requiresApproval` equals `ActionCatalog.RequiresApproval` for every Action
- [ ] T030 [US4] Implement `Admit(actor, run)` in src/SignalNoir/Core/Validator.cls and confirm `requiresApproval` composition, until T029 passes
- [ ] T031 [US4] Run T029 green

**Checkpoint**: 007 can decide whether to wait for a human and which approver is admissible.
**MVP (G1-ready)**: Phases 1–6.

---

## Phase 7: User Story 5 — Preconditions are re-checked from a closed vocabulary (P2)

**Goal**: step 5 (declared preconditions known) and step 8 (`Revalidate`). Recording is 008's.

**Independent Test**: quickstart §1 (TestPreconditions).

- [ ] T032 [P] [US5] Write failing tests/SignalNoir/Tests/Core/Validator/TestPreconditions.cls covering spec US5 AS1–AS8 and SC-007 (each observed value changed alone fails exactly its check); every `PreconditionResult` has `expected`, `observed`, `passed`, and `evidenceId` when `observed` carries one
- [ ] T033 [US5] Add step 5 to `Validate` and implement `Revalidate(input)` with step 8 in src/SignalNoir/Core/Validator.cls per research D12 and FR-021 until T032 passes
- [ ] T034 [US5] Run T032 green

**Checkpoint**: 008's Revalidation has its rule; no recording code is added here.

---

## Phase 8: User Story 6 — Reference data is readable and shared with proposers (P2)

**Goal**: the Tools, the Mappings route and the catalog serve the Store (versioning, pinning and refused loads are already covered by T012–T015).

**Independent Test**: quickstart §3 (TestReferenceTools) and §5.

- [ ] T035 [P] [US6] Write failing tests/SignalNoir/Tests/Application/Reference/TestReferenceTools.cls and TestReferenceEndpoints.cls: through `SignalNoir.Tools.LocalSource`, `tool.policies` returns the policy document of contracts/validation-input.md and `tool.mapping_catalog` returns `mappingVersion`, `items` and `synonyms` of the version in force (the run's pinned version for a Case in a run); with nothing loaded both answer `available: false`; through `SignalNoir.Api.Dispatch`, `Mappings()` returns the contract shape with and without `sourceCode` (`mappingVersion` no longer `"unloaded"`) and `ActionCatalog()` lists `requiredEvidence`
- [ ] T036 [US6] **[edit]** Change src/SignalNoir/Tools/LocalSource.cls (`tool.policies`, `tool.mapping_catalog` from `Store`) and src/SignalNoir/Api/Dispatch.cls (`Mappings()` serves the Store) (coordination items 4–5), until T035 passes
- [ ] T037 [US6] Run T035 green with the existing tests/SignalNoir/Tests/Api/TestResolutionApi.cls

**Checkpoint**: 005 renders real Mappings; proposers and the Validator read the same data.

---

## Phase 9: User Story 7 — Prior-receipt confirmation (P3)

**Goal**: step 12.

**Independent Test**: quickstart §1 (TestPriorReceipt).

- [ ] T038 [P] [US7] Write failing tests/SignalNoir/Tests/Core/Validator/TestPriorReceipt.cls covering spec US7 AS1–AS3, with keys computed by `SignalNoir.Core.Canon.EquivalenceKey` on `input.order` and `input.priorReceiptOrder` (mixed-case, unordered codes and a non-UTC `collectedAt` still match)
- [ ] T039 [US7] Add step 12 to src/SignalNoir/Core/Validator.cls (`prior_receipt_confirmed` with `[EQUIVALENCE_KEY_MATCH]`, `requiresApproval = 0`) until T038 passes
- [ ] T040 [US7] Run T038 green

---

## Phase 10: Polish & Cross-Cutting Concerns

- [ ] T041 Write tests/SignalNoir/Tests/Core/Validator/TestFixtureVerdicts.cls: for each of the 13 verdicts in contracts/fixtures/*.json, rebuild its `ValidationInput` from the fixture's Case (Proposal, Evidence, Order) and assert reasons and `requiresApproval`; 12 must match; `resolution.201.action.json` is asserted as the known divergence (research D3), so the test fails once the fixture is regenerated and the expectation must flip
- [ ] T042 Write tests/SignalNoir/Tests/Core/Validator/TestDeterminismNoIo.cls: static scan of the compiled methods of `SignalNoir.Core.Validator`, `Reasons`, `Conditions` and the four new DTOs (research D13); every input of `Inputs.cls` validated twice and across a fresh process (`JOB`) gives identical JSON; 1000 validations mean ≤ 50 ms (SC-005)
- [ ] T043 Walk specs/004-validation-and-reference-data/quickstart.md end to end and record results in research.md "Verification log"
- [ ] T044 Update specs/004-validation-and-reference-data/plan.md: iris-agentic-dev gate to pass citing V1 and the baseline, or list what failed
- [ ] T045 [P] Write specs/004-validation-and-reference-data/contracts/g1-integration.md for the integrator: (1) fix the prototype mock for `resolution.201.action.json`, regenerate fixtures with `tools/export-api-fixtures.js`, re-run `contracts/tools/validate_fixtures.py`, flip T041's expectation; (2) remove `identity` from the `ValidationInput` row of docs/seams.md and its spec-side copy (documentation only); (3) Henry's answer on the Rules specimen synonyms (coordination request 1)
- [ ] T046 [P] Review the diff against the Constitution, spec, plan and tests: only the listed files changed; `contracts/` untouched; Core classes pass the no-I/O scan; `origin` read by no rule; no second recorder of verdicts

---

## Dependencies & Execution Order

```text
Setup → Foundational (seam v2 → vocab → reference data) → US1 → US2 → US3 → US4 (MVP / G1) → US5 → US6 → US7 → Polish
```

- **Foundational** blocks everything; within it the seam block (T003–T006), vocabularies (T007–T010) and
  reference data (T011–T015) can proceed in parallel by different hands except T011, which the Store
  test (T012) reads.
- **US1** creates the pipeline frame in `Core/Validator.cls`; **US2, US3, US4, US5, US7** each add steps
  to that same file → sequential, never in parallel.
- **US6** touches only `LocalSource`, `Dispatch` and tests; it can run in parallel with US2–US5 once T015
  is done.
- **Shared files** (other features'): `CaseService.cls` (T019), `ResolutionValidator.cls` (T019),
  `ActionCatalog.cls` (T010), `LocalSource.cls`/`Dispatch.cls` (T036) — one task each, after T002.
- **Cross-feature**: 007 needs US4; 008 needs US5; 005 already calls the routes and gets real data after
  T036; 010 needs T015; 011 needs US7.

## Parallel Examples

```text
# Foundational tests together:
T004 TestDtos · T007 TestReasons · T009 ActionCatalog test · T012 TestStore · T013 fixture equality

# While US2–US5 extend Core/Validator.cls, US6 can proceed:
T035 TestReferenceTools/TestReferenceEndpoints · T036 LocalSource + Dispatch
```

## Implementation Strategy

1. **MVP = Phases 1–6** (US1–US4): every Proposal gets a recorded, deterministic v2 verdict with the
   approval decision, behind the adapter 009 built — what G1 needs ("Pedido vira Caso com Proposta
   validada").
2. Then US5 (needed by 008), US6 (real Mappings for the console and proposers; schedule it right after
   the MVP if 005 is being demoed), US7 (conditional consumer).

## Notes

- A divergence from `contracts/openapi-signalnoir.yaml` or the fixtures stops the task and becomes a
  contract-change; never edit the contract or a fixture by hand.
- Commit after each task or logical group.
