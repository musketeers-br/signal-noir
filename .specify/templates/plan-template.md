# Implementation Plan: [FEATURE]

**Branch**: `[###-feature-name]` | **Date**: [DATE] | **Spec**: [link]

**Input**: Feature specification from `/specs/[###-feature-name]/spec.md`

**Note**: This template is filled in by the `/speckit-plan` command. See `.specify/templates/plan-template.md` for the execution workflow.

## Summary

[Extract from feature spec: primary requirement + technical approach from research]

## Technical Context

<!--
  ACTION REQUIRED: Replace the content in this section with the technical details
  for the project. The structure here is presented in advisory capacity to guide
  the iteration process.
-->

**Language/Version**: [e.g., Python 3.11, Swift 5.9, Rust 1.75 or NEEDS CLARIFICATION]

**Primary Dependencies**: [e.g., FastAPI, UIKit, LLVM or NEEDS CLARIFICATION]

**Storage**: [if applicable, e.g., PostgreSQL, CoreData, files or N/A]

**Testing**: [e.g., pytest, XCTest, cargo test or NEEDS CLARIFICATION]

**Target Platform**: [e.g., Linux server, iOS 15+, WASM or NEEDS CLARIFICATION]

**Project Type**: [e.g., library/cli/web-service/mobile-app/compiler/desktop-app or NEEDS CLARIFICATION]

**Performance Goals**: [domain-specific, e.g., 1000 req/s, 10k lines/sec, 60 fps or NEEDS CLARIFICATION]

**Constraints**: [domain-specific, e.g., <200ms p95, <100MB memory, offline-capable or NEEDS CLARIFICATION]

**Scale/Scope**: [domain-specific, e.g., 10k users, 1M LOC, 50 screens or NEEDS CLARIFICATION]

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

Each gate MUST be marked pass, or listed under Complexity Tracking with its justification.

- [ ] **I. Pure Core** — domain rules live only in the core, without I/O; outer layers call it and never reimplement it; the Simulator is reached only over HTTP.
- [ ] **II. Closed Action Catalog / Read-Only Agent** — no new Action outside the catalog; Agent Tools are read-only; payloads are treated as data; no runtime code execution.
- [ ] **III. One Validator** — every Proposal and closure, from any origin, passes the same Validator; no free payload editing.
- [ ] **IV. Human Authority** — Approval binds an immutable Proposal, has a deadline and is revalidated right before the send; Automatic Approval only in the Benchmark.
- [ ] **V. Case as Source of Truth** — mutations through the single command path; state + event + outbox in one short transaction without I/O; CAS on transitions.
- [ ] **VI. Effects at Most Once** — separate identities; authorization persisted before the effect; uncertain outcome blocks resends until Reconciliation; recovery cases covered.
- [ ] **VII. Honest Outcomes** — failures cross layers as values; refusals never shown as success; fact, diagnosis and absence of data kept distinct.
- [ ] **VIII. Honest Measurement** — (if the feature touches the Benchmark) shared Tools and protections, frozen setup, Replay not counted, all outcomes published.
- [ ] **IX. Verifiable Increments** — sliced by observable behavior, each slice with its test; dependencies explicit.
- [ ] **Platform Constraints** — AI Hub build 154; synthetic data; secrets only at runtime; no EAP image published.
- [ ] **iris-agentic-dev** — platform claims this plan relies on were verified on the live instance with iris-agentic-dev (cite the check in research.md); ObjectScript tests will run through it; nothing in the runtime depends on it.

## Project Structure

### Documentation (this feature)

```text
specs/[###-feature]/
├── plan.md              # This file (/speckit-plan command output)
├── research.md          # Phase 0 output (/speckit-plan command)
├── data-model.md        # Phase 1 output (/speckit-plan command)
├── quickstart.md        # Phase 1 output (/speckit-plan command)
├── contracts/           # Phase 1 output (/speckit-plan command)
└── tasks.md             # Phase 2 output (/speckit-tasks command - NOT created by /speckit-plan)
```

### Source Code (repository root)
<!--
  ACTION REQUIRED: Replace the placeholder tree below with the concrete layout
  for this feature. Delete unused options and expand the chosen structure with
  real paths (e.g., apps/admin, packages/something). The delivered plan must
  not include Option labels.
-->

```text
# [REMOVE IF UNUSED] Option 1: Single project (DEFAULT)
src/
├── models/
├── services/
├── cli/
└── lib/

tests/
├── contract/
├── integration/
└── unit/

# [REMOVE IF UNUSED] Option 2: Web application (when "frontend" + "backend" detected)
backend/
├── src/
│   ├── models/
│   ├── services/
│   └── api/
└── tests/

frontend/
├── src/
│   ├── components/
│   ├── pages/
│   └── services/
└── tests/

# [REMOVE IF UNUSED] Option 3: Mobile + API (when "iOS/Android" detected)
api/
└── [same as backend above]

ios/ or android/
└── [platform-specific structure: feature modules, UI flows, platform tests]
```

**Structure Decision**: [Document the selected structure and reference the real
directories captured above]

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| [e.g., 4th project] | [current need] | [why 3 projects insufficient] |
| [e.g., Repository pattern] | [specific problem] | [why direct DB access insufficient] |
