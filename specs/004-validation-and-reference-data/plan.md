# Implementation Plan: Validator and Versioned Reference Data

**Branch**: `004-validation-and-reference-data` | **Date**: 2026-10-24 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/004-validation-and-reference-data/spec.md`

## Summary

Turn the minimal Validator of 001 into the single, deterministic, origin-blind gate of every
Proposal: a fixed 12-step pipeline in the Core that checks catalog, scope, parameters, Mappings,
retry budget, declared and observed preconditions, identity, minimum Evidence, confidence and prior
receipt, and returns the contract's verdict (`accepted` / `blocked` / `review` /
`prior_receipt_confirmed`, ordered closed reason codes, `requiresApproval`, versions used). Every
input — including reference data and the current time — arrives as an immutable `ValidationInput`;
the Core does no I/O. Policies and approved Mappings become versioned XData fixtures loaded by an
application-layer store that refuses invalid versions and supports run pinning. A thin application
service records each verdict on the Case timeline, and a separate REST class serves the action
catalog and Mappings. The seam (`docs/seams.md`) moves to v2 for the Validator through an explicit
contract change.

## Technical Context

**Language/Version**: ObjectScript on InterSystems IRIS 2026.3.0AI build 154 (001-V1).

**Primary Dependencies**: `%RegisteredObject` DTOs, `%DynamicObject`/`%DynamicArray`, `%CSP.REST`
(001-V10), `%Dictionary.*` for fixture discovery and the no-I/O scan (V1), `%UnitTest`. Existing 001
code: `SignalNoir.Core.Vocab`, `SignalNoir.Core.Canon` (equivalence key), `SignalNoir.Application.
CaseService.Append`. No new runtime dependency.

**Storage**: none in the Core. Reference fixtures compiled into classes (XData); versions in force in
`^SignalNoir.Reference`; verdict events through the existing Case timeline.

**Testing**: `%UnitTest` through iris-agentic-dev on the live instance; Core suites need no HTTP or
persistence; one capture validator for the two reference endpoints, mirroring
`contracts/tools/validate_fixtures.py`. TDD.

**Target Platform**: the single `iris` container.

**Project Type**: single IRIS/IPM project; this feature extends `SignalNoir.Core` and adds to
`SignalNoir.Application` and `SignalNoir.Api`.

**Performance Goals**: ≤ 50 ms mean per validation over 1000 runs (SC-005, research D14).

**Constraints**: Core has no I/O (FR-016, static scan D13); one Validator for every origin
(Principle III); no new Action, precondition or error code (contract frozen); `RETRY` and
`APPLY_APPROVED_MAPPING` always need Approval outside a run (Principle IV, enforced at fixture load);
calendar gate — no code before 2026-10-26; integration files and 001's `Api/Dispatch.cls` untouched
until G1.

**Scale/Scope**: 4 Actions, 5 preconditions, 32 reason codes, 1 policy version + 1 mapping version
(4 Mappings) at start; ~7 Core test classes.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- [x] **I. Pure Core** — validation rules, reason vocabulary and condition matching live only in
  `SignalNoir.Core`, with no I/O (static scan, D13); the store and the recording service are
  application-layer adapters that call the Core and contain no rule; nothing references the Simulator.
- [x] **II. Closed Action Catalog / Read-Only Agent** — the catalog is compiled in the Core; a fixture
  naming another Action is refused (FR-024); suspicious Evidence never counts (FR-007).
- [x] **III. One Validator** — one pipeline for Agent, Rules, Operator and Benchmark; `origin` is not
  read by any rule; the fixture that shows a lighter Operator verdict is recorded as a fixture
  divergence to regenerate, not followed (research D3).
- [x] **IV. Human Authority** — `requiresApproval` from a versioned policy whose load is refused if it
  frees `RETRY`/`APPLY_APPROVED_MAPPING`; `Admit` refuses `benchmark` outside a run; `APPROVAL_VALID`
  checks exact Proposal, deadline and currency; new Evidence alone cannot fail a precondition.
- [x] **V. Case as Source of Truth** — verdicts are recorded through the single command path
  (`CaseCommands.Append`), append-only.
- [x] **VI. Effects at Most Once** — N/A for effects; the Validator gives 008 the precondition results
  that stop a stale send.
- [x] **VII. Honest Outcomes** — verdicts are values; `blocked` and `review` stay distinct; missing
  Evidence is `review`, not a negative conclusion; malformed input yields `blocked`, never an
  exception.
- [x] **VIII. Honest Measurement** — Rules and Agent face the same Validator; a BenchmarkRun pins the
  reference versions (FR-025) so its verdicts are reproducible.
- [x] **IX. Verifiable Increments** — sliced by the 7 stories, each with its failing tests first;
  dependencies explicit.
- [x] **Platform Constraints** — build 154, synthetic data, no secrets, no image published.
- [ ] **iris-agentic-dev** — **blocking before /speckit-implement**. Reused claims are 001-verified;
  V1–V3 (research.md) MUST be verified with throwaway probes and logged before any task runs.
  The runtime does not depend on iris-agentic-dev.

### Post-design re-check (after Phase 1)

Re-evaluated after research.md, data-model.md, contracts/ and quickstart.md: I–IX and Platform pass.
Two explicit contract changes are produced instead of silent adjustments: the Validator seam v2 and
the fixture divergence in `resolution.201.action.json`
([contracts/contract-change-004-validator-seam.md](./contracts/contract-change-004-validator-seam.md)).
The iris-agentic-dev gate stays blocking until V1–V3 are logged.

## Project Structure

### Documentation (this feature)

```text
specs/004-validation-and-reference-data/
├── plan.md
├── research.md            # D1–D14, verification backlog V1–V3
├── data-model.md          # DTOs, reference fixtures, catalog, timeline event, decision
├── quickstart.md
├── contracts/
│   ├── contract-change-004-validator-seam.md   # seams.md v2 + fixture divergence
│   ├── validation-input.md                      # what callers pass; Evidence convention
│   └── reason-codes.md                          # closed codes, texts, Dossier mapping
├── checklists/requirements.md
└── tasks.md               # /speckit-tasks
```

### Source Code (repository root)

```text
src/SignalNoir/
├── Core/
│   ├── Validator.cls              # rewritten: Validate, Revalidate, Admit — 12-step pipeline
│   ├── Reasons.cls                # closed reason codes + English texts + order
│   ├── Conditions.cls             # canonical matching of Mapping conditions, synonyms
│   ├── Catalog.cls                # compiled action catalog (params schema, required evidence)
│   ├── Port/Validator.cls         # v2 port (seam change)
│   └── Dto/
│       ├── Proposal.cls           # extended (seam change)
│       ├── ValidatorVerdict.cls   # v2 (seam change)
│       ├── ValidationInput.cls  PreconditionResult.cls  Admission.cls  ReferenceData.cls
├── Application/
│   ├── ValidationService.cls      # ValidateAndRecord / RevalidateAndRecord → CaseService.Append
│   └── Reference/
│       ├── Store.cls              # discover, validate, load, pin, in-force pointer
│       ├── Policies/V2026101.cls  # XData policy fixture 2026.10.1
│       └── Mappings/V2026101.cls  # XData mapping fixture 2026.10.1 (= contract fixture items)
└── Api/
    └── Reference.cls              # %CSP.REST: /action-catalog, /mappings (forwarded at G1)
tests/
├── SignalNoir/Tests/Core/Validator/        # Stories 1–5, 7, determinism/no-I/O, fixture verdicts
├── SignalNoir/Tests/Application/Reference/ # Story 6, store, fixture equality
├── SignalNoir/Tests/Application/TestValidationRecorded.cls
├── SignalNoir/Tests/Api/TestReference.cls
├── SignalNoir/Tests/Fakes/FakeValidator.cls          # v2 (seam change)
├── SignalNoir/Consumer/Consumer.cls                  # v2 (seam change)
├── SignalNoir/Tests/Seam/TestConsumerUsesSeam.cls    # v2 (seam change)
└── reference-contract/            # captures + validate_reference_captures.py
docs/seams.md                      # v2 Validator section (contract change, applied on master first)
```

**Structure Decision**: extend the existing `SignalNoir` tree from 001. The write zone of this feature
is `src/SignalNoir/Core/{Validator,Reasons,Conditions,Catalog}.cls`, `Core/Port/Validator.cls`,
`Core/Dto/{Proposal,ValidatorVerdict,ValidationInput,PreconditionResult,Admission,ReferenceData}.cls`,
`src/SignalNoir/Application/ValidationService.cls`, `src/SignalNoir/Application/Reference/**`,
`src/SignalNoir/Api/Reference.cls`, the test paths above, `docs/seams.md` (Validator section only, via
the contract change) and `specs/004-validation-and-reference-data/**`. `Core/Vocab.cls` and
`Core/Canon.cls` are read, not edited.

## Dependencies and integration

- **Before 006 plans**: apply the seam v2 document change to `docs/seams.md` on master and confirm
  the Evidence convention with Henry ([validation-input.md](./contracts/validation-input.md)).
- **Consumed by**: 005 (reference endpoints), 006/009 (`ValidateAndRecord`), 007 (`requiresApproval`,
  `Admit`, deadline policy), 008 (`RevalidateAndRecord`, observed values), 010 (run pinning), 011
  (`prior_receipt_confirmed`).
- **Gate G1 integration changes** (integrator, not this branch):
  1. `SignalNoir.Api.Dispatch` UrlMap: `<Map Prefix="/reference" Forward="SignalNoir.Api.Reference"/>`.
  2. Fixture regeneration for `resolution.201.action.json` (prototype mock fix).

## Complexity Tracking

> No Constitution principle is violated. Deviations that need a note:

| Deviation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|--------------------------------------|
| Seam contract change (Validator v2) | v1 cannot carry the contract's verdict nor FR-016's inputs | An adapter keeps two shapes for one rule and loses `review` and reasons |
| Separate `SignalNoir.Api.Reference` reached by forward | Keeps 001/003's `Dispatch.cls` untouched until G1 | Adding routes to `Dispatch.cls` collides with 003's write zone |
| Evidence `facts` convention owned by 004 | The contract fixes `Evidence.source` but not its payload; the Validator must recognise minimum Evidence deterministically | Inferring from free text breaks determinism and Principle II |
| Test-only web application for the reference endpoints | The forward lands only at G1 | Waiting for G1 leaves FR-026 untested in this branch |
| iris-agentic-dev gate blocking until V1–V3 are logged | The planning session had no iris-agentic-dev access | Verifying through `docker exec` is not an accepted path |
