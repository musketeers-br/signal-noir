# Implementation Plan: Normative Case state machine

**Branch**: none (spec directory `001-case-state-machine`) | **Date**: 2026-10-22 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `/specs/001-case-state-machine/spec.md`

## Summary

Freeze the Case state machine (T01–T29, attachments, refusals and decisions D1–D5) as the single normative source, before 10/26 and without submission code. The approach (research R1–R6):
1. Publish the table as data in `contracts/case-state-machine.yaml`.
2. Check it in CI with `contracts/tools/validate_state_machine.py` against the OpenAPI `CaseState`, `Actor` and `TimelineEventType` and against the spec's table.
3. Mark `addendum.md` §D and AD-24 as replaced and point PRD FR-5 to the new table.
4. Hand story 2.5 the list of contract changes.

The Core (Phase B) belongs to the epic-caso-e-decisao story from 10/26 on; its implementation language is decided in that story's Plan, after the 10/25 spike (research R4). This story leaves its pure port and the parity test defined.

## Technical Context

**Language/Version**: Phase A: YAML 1.2 (data) and Python 3.12 via `uv` (validator, same pattern as `contracts/tools/validate_fixtures.py`). Phase B (outside this story): language of the Core not decided yet. Candidates are ObjectScript, Embedded Python methods (`[Language = python]`) inside ObjectScript classes, or Embedded Python modules; the Phase B Plan chooses after the spike answers Q-F on IRIS AI Hub EAP build 154 (research R4). The Agent itself stays on `%AI.Agent`/`%AI.ToolSet`/`%AI.Provider` regardless (Constitution, Platform Constraints).

**Primary Dependencies**: `pyyaml` (already used by the contracts CI). No new runtime dependency.

**Storage**: files versioned in the repository (`contracts/`). N/A at runtime.

**Testing**: the validator has its own negative cases in `contracts/tools/tests/state_machine/` (invalid YAMLs with the expected failure of each), written before the validator (TDD). CI runs the negative cases and the real table. Phase B: a parity test on the live instance through iris-agentic-dev, in the test framework that Plan chooses (`%UnitTest` under the current Constitution; Python tests would need an amendment).

**Target Platform**: GitHub Actions (`.github/workflows/contracts.yml`) and the developer machine.

**Project Type**: versioned specification artifact (internal domain contract) with a verification tool.

**Performance Goals**: validator under 5 s in CI.

**Constraints**: the Constitution's calendar gate in force at the time (1.1.0; lifted in 1.2.0): no submission code before 10/26, so only contract, specification, fixture and contract tooling. The OpenAPI is not edited (scope of 2.5). The prototype is neither source nor destination. Everything committed is in English (Constitution 1.1.0, Language).

**Scale/Scope**: 13 states, 29 transitions, about 9 attachments, 4 refusal rules, 5 decisions and about 14 trace steps.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- [x] **I. Pure Core**: the table is the data of the rule the Core will own. Phase B compiles it into a class with no I/O, and the YAML serves only as a test oracle (R4). No outer layer gets a copy of the rule.
- [x] **II. Closed Action Catalog / Read-Only Agent**: no new Action. The Operator resolution accepts only `RETRY`, `APPLY_APPROVED_MAPPING` and `HOLD`. No code is generated from data at runtime (R4).
- [x] **III. One Validator**: T04/T28 → T07–T10. Every Proposal and every closure (T09) goes through the Validator. A refused Operator resolution records only the verdict.
- [x] **IV. Human Authority**: Approval with `expiresAt` (T11). Validity is checked at the authorization CAS (T17), and only the sweeper expires (T18). The authorization is voided when Revalidation fails (T19, T21, T22). `benchmark` only in T12.
- [x] **V. Case as Source of Truth**: every transition is a CAS with state, events and outbox recorded atomically (FR-005). Terminal never reopens and a new episode creates a related Case (T02, D2, D5).
- [x] **VI. Effects at Most Once**: authorization before the effect (T17). Uncertainty blocks sends until a conclusive Reconciliation (D4, FR-016), and a new Attempt uses the same effect key. The key derivation belongs to story 2.3.
- [x] **VII. Honest Outcomes**: `decide` returns `Accepted`/`Refused`/`Attach` as values. Refusals are recorded (`CommandDiscarded`). `outcome_unknown` is distinct from `Failed` and from `Held`.
- [x] **VIII. Honest Measurement**: the Benchmark appears only in T12 and in the expiration note. Scoring belongs to 2.4. N/A beyond that.
- [x] **IX. Verifiable Increments**: this story's delivery is observable and testable on its own (green validator plus José's proof, SC-002). It is not "layer X" of a feature: it is the domain contract the 10/26 slices consume, with the dependency declared in the ticket (entries 3, 4 and 5 are `after = [2]`).
- [x] **Platform Constraints**: no real data; no secrets; no images.
- [x] **Language**: this plan and every artifact it produces are in English; the Portuguese drafts of this feature were translated when Constitution 1.1.0 was adopted.
- [x] **iris-agentic-dev**: this phase depends on no platform claim. R4 records what Phase B must verify on build 154 (Embedded Python version, and the parity test reading the fixture in the container) and the check already made on the current dev container. Nothing at runtime depends on the tool.

**Post-design re-check (Phase 1)**: still passes. Point of attention without a violation: the Constitution says "contract-first HTTP, code-first internals", and the YAML is an *internal* contract. The justification is in R1/R4. The YAML freezes the specification (allowed before 10/26) and, from 10/26 on, the Core code owns the rule, with parity tested. There is no second owner.

## Project Structure

### Documentation (this feature)

```text
specs/001-case-state-machine/
├── spec.md
├── plan.md                          # this file
├── research.md                      # R1–R6
├── data-model.md                    # table format + aggregate fields
├── quickstart.md                    # how to validate
├── contracts/
│   ├── case-state-machine.format.md # syntax of the normative YAML
│   ├── core-transition-port.md      # pure port of the Core (Phase B)
│   └── openapi-delta.md             # C1–C8 for story 2.5
├── checklists/requirements.md
└── tasks.md                         # /speckit-tasks
```

### Source Code (repository root)

```text
contracts/
├── case-state-machine.yaml               # NEW: normative table (data)
├── openapi-signalnoir.yaml               # read, not edited
└── tools/
    ├── validate_fixtures.py              # existing
    ├── validate_state_machine.py         # NEW: validator
    ├── test_validate_state_machine.py    # NEW: runs the negative cases and the real table
    └── tests/state_machine/              # NEW: invalid YAMLs + expected failure, generated by generate_cases.py
.github/workflows/contracts.yml           # + "State machine validates" step
_bmad-output/initiative-signal-noir/
├── prd-signal-noir/addendum.md           # §D marked as replaced
├── prd-signal-noir/prd-signal-noir.md    # FR-5 points to the new table
└── architecture-signal-noir/architecture-signal-noir.md  # AD-24 "Pontos fixados" replaced
```

**Structure Decision**: everything fits in the existing `contracts/` folder and the contracts workflow (PR #5). `src/` (the `dc.sample` template) is not touched. The `SignalNoir.Core` package is born in Phase B.

## Delivery phases of this story

1. **Validator negative tests** (red): one invalid YAML per R2 rule, with the expected message.
2. **Validator** (green): `validate_state_machine.py` with the six R2 rules and the list of `pendingContractChange`.
3. **Normative table**: `contracts/case-state-machine.yaml` transcribing the spec (T01–T29, attachments, refusals, D1–D5, trace). The validator passes.
4. **CI**: new step in `contracts.yml` and the path `specs/001-case-state-machine/spec.md` in the workflow triggers (because of parity).
5. **Replacement**: notes in §D, AD-24 and FR-5.
6. **Hand-off to 2.5**: link to `contracts/openapi-delta.md` in the notes of ticket entry 5.
7. **Human proof**: José does the blind trace (SC-002) and Henrique reviews (SC-006).

## Complexity Tracking

No violation to justify.
