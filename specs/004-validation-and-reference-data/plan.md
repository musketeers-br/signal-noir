# Implementation Plan: Validator and Versioned Reference Data

**Branch**: `004-validation-and-reference-data` | **Date**: 2026-10-24, revised 2026-10-26 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/004-validation-and-reference-data/spec.md`

**Revision 2026-10-26**: revised against `master` after 003, 005, 006 and 009 merged. The first plan
assumed the Validator's surroundings did not exist; most of them do. See research.md "Revision
summary" and [contracts/coordination-004-006-009.md](./contracts/coordination-004-006-009.md).

## Summary

Turn the minimal Validator of 001 into the single, deterministic, origin-blind gate of every
Proposal: a fixed 12-step pipeline in the Core that checks catalog, scope, parameters, Mappings,
retry budget, declared and observed preconditions, identity, minimum Evidence, confidence and prior
receipt, and returns the contract's verdict (`accepted` / `blocked` / `review` /
`prior_receipt_confirmed`, ordered closed reason codes, `requiresApproval`, versions used). Every
input — including reference data and the current time — arrives as an immutable `ValidationInput`;
the Core does no I/O. Policies and approved Mappings become versioned XData fixtures loaded by an
application-layer store that refuses invalid versions and supports run pinning, and that now feeds
three things that already exist on `master` and wait for it: the `tool.policies` and
`tool.mapping_catalog` read-only Tools, `GET /reference/mappings` and the catalog's minimum-Evidence
list. The Validator plugs in behind the one adapter (`ResolutionValidator`) through which 006 and 009
already send every Proposal, so recording and routing stay where they are.

## Technical Context

**Language/Version**: ObjectScript on InterSystems IRIS 2026.3.0AI build 154 (001-V1).

**Primary Dependencies**: `%RegisteredObject` DTOs, `%DynamicObject`/`%DynamicArray`, `%Dictionary.*`
for fixture discovery and the no-I/O scan (V1), `%UnitTest`. Already on `master` and reused:
`SignalNoir.Core.{Vocab,Canon,Identity,ActionCatalog}`, `Core.Dto.{Proposal,Evidence}`,
`Application.{CaseService,ResolutionValidator}`, `Tools.LocalSource`, `Api.Dispatch`. No new runtime
dependency.

**Storage**: none in the Core. Reference fixtures compiled into classes (XData); versions in force in
`^SignalNoir.Reference`; verdicts stay where `CaseService` writes them (`ProposalRecord.verdictJson`
and the timeline).

**Testing**: `%UnitTest` through iris-agentic-dev on the live instance; Core suites need no HTTP or
persistence; the existing suites (`TestResolution`, `TestDossier`, `TestResolutionApi`, the seam
tests) keep running and are moved to the v2 vocabulary. TDD.

**Target Platform**: the single `iris` container (dev kit: `dev/aihub/`, container `signalnoir-iris`).

**Project Type**: single IRIS/IPM project; extends `SignalNoir.Core` and `SignalNoir.Application`
and makes five small edits in files of earlier features.

**Performance Goals**: ≤ 50 ms mean per validation over 1000 runs (SC-005, research D14).

**Constraints**: Core has no I/O (FR-016, static scan D13); one Validator for every origin
(Principle III); no new Action, precondition or error code (contract frozen); `requiresApproval` is
the catalog's external-effect rule, not data; edits to files of 003/006/009 are listed, small and
agreed with Henry first; integration files untouched; the code of this feature is written from
2026-10-26 on (calendar gate satisfied).

**Scale/Scope**: 4 Actions, 5 preconditions, 32 reason codes, 1 policy version + 1 mapping version
(4 Mappings) at start; ~7 Core test classes.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- [x] **I. Pure Core** — validation rules, reason vocabulary and condition matching live only in
  `SignalNoir.Core`, with no I/O (static scan, D13); the store and the adapter are application-layer
  and contain no rule; nothing references the Simulator.
- [x] **II. Closed Action Catalog / Read-Only Agent** — the catalog stays compiled in the Core
  (`ActionCatalog`); suspicious and `absence` Evidence never count (FR-007); the policy and Mapping
  Tools stay read-only.
- [x] **III. One Validator** — one pipeline for Agent, Rules, Operator and Benchmark, entered through
  one adapter; `origin` is not read by any rule; identity is derived by the Validator, not passed by
  the caller; the fixture that shows a lighter Operator verdict is a divergence to regenerate, not to
  follow (research D3).
- [x] **IV. Human Authority** — `requiresApproval` follows the catalog's external-effect rule, which
  no fixture can edit; `Admit` refuses `benchmark` outside a run; `APPROVAL_VALID` checks the exact
  Proposal, the deadline and currency; new Evidence alone cannot fail a precondition.
- [x] **V. Case as Source of Truth** — verdicts are recorded by the existing Case command path
  (`CaseService`), append-only; this feature adds no second writer.
- [x] **VI. Effects at Most Once** — N/A for effects; the Validator gives 008 the precondition
  results that stop a stale send.
- [x] **VII. Honest Outcomes** — verdicts are values; `blocked` and `review` stay distinct; an
  `absence` is "missing", not a negative finding; malformed input yields `blocked`, never an
  exception.
- [x] **VIII. Honest Measurement** — Rules and Agent face the same Validator and now read the same
  reference data through the same Tools; a BenchmarkRun pins the versions (FR-025). Open: the Rules
  baseline compares specimen types without synonyms (coordination request 1).
- [x] **IX. Verifiable Increments** — sliced by the 7 stories, each with its failing tests first;
  dependencies explicit.
- [x] **Platform Constraints** — build 154, synthetic data, no secrets, no image published.
- [x] **iris-agentic-dev** — passed (2026-10-30, T001, T044). V1 was verified with a throwaway probe and
  logged in research.md "Verification log" (passes on 2026.2 build 221; compiling needs three
  passes). The suites already on `master` were run as the baseline on a second container
  (`signalnoir-004`, the worktree mounted): 272 passing and 3 failing at first, the three being
  environmental (no AI provider configured); after PR #19 the baseline is green (300 passing, 0
  failing). Build 154 was not rerun: the decision is recorded in the same log. The runtime does not
  depend on iris-agentic-dev.

### Post-design re-check (after Phase 1, revised)

I–IX and Platform pass. Two explicit contract changes are produced instead of silent adjustments:
the Validator seam v2 (`identity` removed from the input) and the fixture divergence in
`resolution.201.action.json`
([contracts/contract-change-004-validator-seam.md](./contracts/contract-change-004-validator-seam.md)).
One finding was passed to Henry: `ActionCatalog.RequiresApproval("REQUEST_REVIEW")` was true against
PRD FR-16 and the fixtures; it was already false on `master` (009b), and the edits were agreed with
him on 2026-10-31 ([contracts/coordination-004-006-009.md](./contracts/coordination-004-006-009.md)).
The iris-agentic-dev gate passed (see above).

## Project Structure

### Documentation (this feature)

```text
specs/004-validation-and-reference-data/
├── plan.md
├── research.md            # D1–D16, verification backlog V1
├── data-model.md          # DTOs, reference fixtures, catalog, timeline event, decision
├── quickstart.md
├── contracts/
│   ├── contract-change-004-validator-seam.md   # seams.md v2 + fixture divergence
│   ├── coordination-004-006-009.md              # edits to merged files, requests to Henry
│   ├── validation-input.md                      # what callers pass; Evidence recognition; Tool results
│   └── reason-codes.md                          # closed codes, texts, Dossier mapping
├── checklists/requirements.md
└── tasks.md               # /speckit-tasks
```

### Source Code (repository root)

```text
src/SignalNoir/
├── Core/
│   ├── Validator.cls              # rewritten: Validate, Revalidate, Admit — 12-step pipeline
│   ├── Reasons.cls                # NEW: closed reason codes + English texts + order
│   ├── Conditions.cls             # NEW: canonical matching of Mapping conditions, synonyms
│   ├── ActionCatalog.cls          # EXISTS (009): fill requiredEvidence; RequiresApproval = ExternalEffect
│   ├── Identity.cls               # EXISTS (009): read, not edited
│   ├── Port/Validator.cls         # v2 port (seam change)
│   └── Dto/
│       ├── ValidatorVerdict.cls   # v2 (seam change)
│       └── ValidationInput.cls  PreconditionResult.cls  Admission.cls  ReferenceData.cls   # NEW
├── Application/
│   ├── ResolutionValidator.cls    # EXISTS (009): InputFor + Verdict(validator, input) → v2
│   ├── CaseService.cls            # EXISTS: two call sites + `versions` in the verdict event
│   └── Reference/                 # NEW
│       ├── Store.cls              # discover, validate, load, pin, in-force pointer
│       ├── Policies/V2026101.cls  # XData policy fixture 2026.10.1
│       └── Mappings/V2026101.cls  # XData mapping fixture 2026.10.1 (= contract fixture items)
├── Tools/LocalSource.cls          # EXISTS (006): tool.policies / tool.mapping_catalog from the Store
└── Api/Dispatch.cls               # EXISTS: Mappings() serves the Store
tests/
├── SignalNoir/Tests/Core/Validator/        # Stories 1–5, 7, determinism/no-I/O, fixture verdicts
├── SignalNoir/Tests/Core/TestActionCatalog.cls     # EXISTS: extended
├── SignalNoir/Tests/Application/Reference/         # Story 6: store, fixtures, tools, endpoint
├── SignalNoir/Tests/Application/TestResolutionValidator.cls   # NEW: adapter v2 + recording
├── SignalNoir/Tests/Fakes/FakeValidator.cls                   # v2 (seam change)
├── SignalNoir/Consumer/Consumer.cls, Tests/Seam/TestConsumerUsesSeam.cls   # v2
└── SignalNoir/Tests/Application/TestResolution.cls, TestDossier.cls         # `Verdict = "blocked"`
```

**Structure Decision**: extend the `SignalNoir` tree. New files: `Core/{Reasons,Conditions}.cls`, the
four Core DTOs, `Application/Reference/**` and their tests. Edits to existing files, each listed in
[coordination-004-006-009.md](./contracts/coordination-004-006-009.md) and agreed with Henry before the
task that makes it starts: `ActionCatalog.cls`, `ResolutionValidator.cls`, `CaseService.cls` (two call
sites and one payload field), `LocalSource.cls` (two branches), `Dispatch.cls` (`Mappings()`), and the
v1-vocabulary tests. `Core/Vocab.cls`, `Core/Canon.cls`, `Core/Identity.cls` are read, not edited. The
write zone of this feature is therefore the new files plus those edits, `docs/seams.md` (the
`ValidationInput` row, via the contract change, on `master`) and `specs/004-validation-and-reference-data/**`.

## Dependencies and integration

- **Coordination**: before US1's integration task, walk
  [coordination-004-006-009.md](./contracts/coordination-004-006-009.md) with Henry; the Rules
  synonym request is for his wave 4 and does not block this feature.
- **Consumed by**: 005 (catalog, Mappings — already calling the routes), 006/009 (Proposals, Tools),
  007 (`Admit`, deadline), 008 (`Revalidate`), 010 (pinned versions), 011 (`prior_receipt_confirmed`).
- **Gate G1 integration changes** (integrator): regenerate the fixtures after the prototype mock fix
  for `resolution.201.action.json` and flip the expectation of `TestFixtureVerdicts`. No route or
  Dispatch forward is needed.

## Complexity Tracking

> No Constitution principle is violated. Deviations that need a note:

| Deviation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|--------------------------------------|
| Seam contract change (Validator v2) | v1 cannot carry the contract's verdict nor FR-016's inputs | An adapter keeps two shapes for one rule and loses `review` and reasons |
| Edits to five files of 003/006/009 | The Validator can only replace v1 behind the adapter that 009 built, and the Tools, route and catalog that wait for 004 live in those files | Parallel copies (a second recorder, REST class or catalog) would duplicate events and routes and drift |
| `requiresApproval` by external-effect rule, not by policy data | Principle IV makes it constitutional and `ActionCatalog` already encodes it | A per-Action policy flag lets a fixture free an effectful Action |
| iris-agentic-dev gate blocking until V1 and the baseline are logged | The planning session had no iris-agentic-dev access | Verifying through `docker exec` is not an accepted path |
