# Implementation Plan: Agent Prompt v2

**Branch**: `017-agent-prompt-v2` | **Date**: 2026-11-01 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `specs/017-agent-prompt-v2/spec.md`

## Summary

Replace the Agent's instructions (`agent-v1`) with `agent-v2`: one explicit decision order aligned with
`rules-v2` (identity → instability → one applicable Mapping → isolated transient failure → review), how to
match a Mapping through the catalog's synonyms, what counts as Partner instability (timeouts, DOWN,
maintenance; never answered errors, never `errorRate`), definitions of HOLD and REQUEST_REVIEW, and a
confidence criterion. The change is the `SystemPrompt` XData and `PROMPTVERSION` of
`SignalNoir.Proposers.Agent`, plus one test of the prompt and the version, plus the existing test that
pins the version. Input building, parsing, the runtime, the Validator, Rules, Core and Tools do not change.

## Technical Context

**Language/Version**: InterSystems ObjectScript on IRIS AI Hub build 154 (Community)

**Primary Dependencies**: `%AI` Agent through `SignalNoir.Proposers.AiHubRuntime` (unchanged)

**Storage**: N/A (the prompt is class XData; the version is a class parameter)

**Testing**: `%UnitTest` through iris-agentic-dev / `iris session` on the dev container; scripted
runtime (`SignalNoir.Tests.Fakes.AgentWithFakeRuntime`), no live provider

**Target Platform**: IRIS AI Hub build 154 container (`signalnoir-iris`, namespace `IRISAPP`)

**Project Type**: server application (IRIS), proposer adapter

**Performance Goals**: rehearsal of 12 tuning Cases within 10 minutes per repetition (SC-006); the prompt
grows from ~25 to ~60 lines, well inside the model's context

**Constraints**: freeze on 2026-11-05 (FR-014); no scenario family or variant names in the prompt
(FR-012); tuning variants only (FR-013)

**Scale/Scope**: one class changed, two tests

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- [x] **I. Pure Core** — no Core change; the prompt is adapter text.
- [x] **II. Closed Action Catalog / Read-Only Agent** — same four Actions, same read-only pre-collected
  Evidence, Evidence still delimited as data; the prompt keeps the anti-injection rule.
- [x] **III. One Validator** — every Agent Proposal still passes the same Validator; nothing bypasses it.
- [x] **IV. Human Authority** — untouched.
- [x] **V. Case as Source of Truth** — untouched.
- [x] **VI. Effects at Most Once** — untouched.
- [x] **VII. Honest Outcomes** — `invalid_response` path unchanged; LOW confidence for review makes
  absence of data explicit.
- [x] **VIII. Honest Measurement** — the decision order mirrors `rules-v2` (same Tools, same Evidence, no
  weaker baseline); tuning only on tuning variants; the reserved test set is not read (the Simulator
  catalog is not opened while writing the prompt); the prompt version is recorded for the freeze.
- [x] **IX. Verifiable Increments** — one slice: the Agent proposes under `agent-v2`, observable on every
  Proposal (`versions.prompt`), with its automated test and a rehearsal.
- [x] **Platform Constraints** — build 154, synthetic data, keys only at runtime.
- [x] **iris-agentic-dev** — tests run on the live dev container (research R5).

## Project Structure

### Documentation (this feature)

```text
specs/017-agent-prompt-v2/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   └── agent-v2-instructions.md   # the reviewed text of the instructions
└── tasks.md
```

### Source Code (repository root)

```text
src/SignalNoir/Proposers/
└── Agent.cls                      # EDIT: SystemPrompt XData, PROMPTVERSION = "agent-v2"

tests/SignalNoir/Tests/
├── Proposers/
│   └── TestAgentPromptV2.cls      # NEW: version, decision order, criteria, no family names
└── Application/
    └── TestProposerModes.cls      # EDIT: expects versions.prompt = "agent-v2"
```

**Structure Decision**: single IRIS project; the edit stays inside the proposer adapter.

## Complexity Tracking

No violations.
