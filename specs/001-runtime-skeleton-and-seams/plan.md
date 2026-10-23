# Implementation Plan: Runtime Skeleton and Shared Seams

**Branch**: `001-runtime-skeleton-and-seams` | **Date**: 2026-10-22 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/001-runtime-skeleton-and-seams/spec.md`

## Summary

Deliver the smallest walking skeleton of Signal Noir on InterSystems IRIS AI Hub EAP build 154:
a fresh checkout starts and reports readiness honestly (provider configured or unavailable), one
synthetic Order becomes a persisted Case with an append-only timeline that survives a restart,
and a published internal seam contract (`docs/seams.md`) lets the next features compile and test
against it with fakes. The technical approach is a single IPM module with hexagonal packages
(`SignalNoir.Core`, `SignalNoir.Application`, `SignalNoir.Api`, `SignalNoir.Interop`) over a
minimal Interoperability Production, an idempotent `^%ZSTART` bootstrap that materializes the AI
Hub provider configuration from runtime environment, and `%UnitTest` suites run through
iris-agentic-dev.

## Technical Context

**Language/Version**: ObjectScript on InterSystems IRIS 2026.3.0AI build 154 (EAP community
image). Verified live: `$ZVERSION` = `IRIS for UNIX (Ubuntu Server LTS for x86-64 Containers)
2026.3.0AI (Build 154U)`.

**Primary Dependencies**: IRIS AI Hub EAP 154 classes (`%AI.Agent`, `%AI.ToolSet`, `%AI.Provider`,
`%AI.Agent.Session`, `%ConfigStore.Configuration`, `%ConfigStore.DescriptorManager`); IRIS
Interoperability (`Ens.BusinessService`, `Ens.BusinessProcess`, `Ens.Production`, `Ens.Director`);
IPM pinned by the build; `%UnitTest` for tests; `%CSP.REST` for HTTP. All verified present on the
live instance (see research.md).

**Storage**: IRIS globals through `%Persistent` classes in namespace `IRISAPP` (databases
`IRISAPP_DATA` and `IRISAPP_CODE`). Optimistic concurrency by `VERSIONPROPERTY`. No external
database.

**Testing**: `%UnitTest` suites (`SignalNoir.Tests.*`) executed against the live build 154
container through iris-agentic-dev, plus one REST smoke test. The quick validation is out of scope
for this slice.

**Target Platform**: Single InterSystems IRIS AI Hub EAP 154 container (`1972` superserver,
`52773` private web server). No extra container in the runtime path.

**Project Type**: Single IRIS/IPM project (backend, HTTP API and Production). No separate
frontend in this slice (the SPA is later, spec 005/012).

**Performance Goals**: Startup must not block on the provider; health must answer while the
provider is unavailable. Readiness observable in seconds after container start. No throughput
target in this slice.

**Constraints**: No submission code before 2026-10-26 (Constitution calendar gate). Build 162 is
forbidden. No EAP image or derived image published to any registry. Secrets enter only at runtime
and never in code, timeline, logs, exports or images. The runtime must not depend on
iris-agentic-dev. All data synthetic and labelled.

**Scale/Scope**: One synthetic Order, one Case, one timeline, one health surface, one published
seam contract. No agent calls, no simulator scenarios, no console, no benchmark, no execution.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- [x] **I. Pure Core** — `SignalNoir.Core` holds the state machine, closed vocabularies and the
  minimal Validator with no I/O; `Application` and outer layers call it and do not reimplement it;
  nothing references `SignalNoir.Sim` (absent in this slice).
- [x] **II. Closed Action Catalog / Read-Only Agent** — the skeleton defines no Action beyond
  `RETRY`, `APPLY_APPROVED_MAPPING`, `HOLD`, `REQUEST_REVIEW`; no Tool writes; no runtime code
  execution. The provider-unavailable path never calls a model.
- [x] **III. One Validator** — a single deterministic `Validator` port is used by every path that
  reaches a verdict; the skeleton includes the seam and a minimal rule set, expanded in spec 004.
- [x] **IV. Human Authority** — not exercised in this slice; the seam reserves the Approval DTO and
  port shape so the rule is not bypassed later.
- [x] **V. Case as Source of Truth** — the Case and its timeline are persisted; the single command
  path of `SignalNoir.Application` writes them; transitions carry a version.
- [x] **VI. Effects at Most Once** — out of scope for effects; the Outbox entry shape is defined in
  the data model and the idempotency prefix convention is fixed for later slices.
- [x] **VII. Honest Outcomes** — the seam carries result values (error envelope and verdict), the
  provider-unavailable condition is a reported value, and fact/diagnosis/absence are separate
  fields.
- [x] **VIII. Honest Measurement** — N/A: the Benchmark is not touched by this slice.
- [x] **IX. Verifiable Increments** — the slice is end-to-end observable (start → accept → read →
  restart) and each increment carries its `%UnitTest`.
- [x] **Platform Constraints** — build 154 only (verified live), synthetic data, secrets at
  runtime only, no image published.
- [x] **iris-agentic-dev** — every platform dependency this plan relies on was verified on the live
  build 154 container with iris-agentic-dev (see research.md "Verification log"); the tests run
  through it; the runtime does not depend on it.

### Post-design re-check (after Phase 1)

Re-evaluated after `research.md`, `data-model.md`, `contracts/` and `quickstart.md`: all gates
remain pass. The one deliberate change to a frozen input (a health endpoint) is recorded as an
explicit contract change in `contracts/contract-change-001-health.md`, not a silent adjustment.

## Project Structure

### Documentation (this feature)

```text
specs/001-runtime-skeleton-and-seams/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/
│   ├── seams.md                       # Ports, DTOs, error envelope, timeline event
│   └── contract-change-001-health.md  # Proposed /health addition to the frozen API
├── checklists/
│   └── requirements.md
└── tasks.md             # Phase 2 output (/speckit-tasks - NOT created here)
```

### Source Code (repository root)

```text
src/
├── SignalNoir/
│   ├── Core/                     # Pure, no I/O
│   │   ├── Vocab.cls             # States, Actors, Actions, Commands, error codes
│   │   ├── CaseMachine.cls       # State machine + actor table
│   │   ├── Validator.cls         # Minimal deterministic validator
│   │   ├── Canon.cls             # Equivalence-key canonization (seam only in this slice)
│   │   ├── Dto/                  # Explicit DTOs (Order, Case, CaseSummary, Evidence,
│   │   │                         #   Proposal, ValidatorVerdict, Approval, Execution,
│   │   │                         #   Receipt, Dossier, TimelineEvent)
│   │   └── Port/                 # CaseCommands, CaseQueries, Validator, Proposer, Tools,
│   │                             #   PartnerClient, Clock, IdGenerator
│   ├── Application/
│   │   ├── CaseService.cls       # Implements CaseCommands + CaseQueries
│   │   ├── Model/                # Persistent records: OrderRecord, CaseRecord,
│   │   │                         #   CaseEventRecord, OutboxRecord
│   │   ├── SystemClock.cls       # Clock adapter
│   │   └── IdFactory.cls         # IdGenerator adapter (prefixes: case_, evid_, cmd_ ...)
│   ├── Api/
│   │   ├── Dispatch.cls          # %CSP.REST, /signalnoir/api/v1
│   │   └── Health.cls            # %CSP.REST, /signalnoir/api/v1/health (see contract change)
│   ├── Interop/
│   │   ├── Production.cls        # Minimal Ens.Production
│   │   ├── Bootstrap.cls         # Idempotent startup: provider, timeouts, Production, task
│   │   └── Service/OrderIn.cls   # Business Service: synthetic Order -> Case
│   └── Proposers/
│       └── Unavailable.cls       # Provider-unavailable Proposer stub (result value)
├── SignalNoir/... (as above; only packages listed exist in this slice)
boot/
└── %ZSTART.mac                   # %SYS routine, SYSTEM label -> Bootstrap.OnStart()
tests/
└── SignalNoir/
    └── Tests/
        ├── Core/                 # State machine, validator, vocab tests
        ├── Application/          # Persistence + restart + concurrency tests
        ├── Api/                  # REST read + health tests
        ├── Interop/              # Bootstrap + production tests
        └── Fakes/                # Test doubles for every port (test-only resource)
docs/
└── seams.md                      # Published seam contract (deliverable of this feature)
```

**Structure Decision**: Single IRIS/IPM project. Domain/application/adapters live in the
`SignalNoir` package tree under `src/`, following the architecture packages (`Core`,
`Application`, `Api`, `Interop`, plus `Proposers`/`Tools`/`Tasks` as they arrive). Test doubles
live only under `tests/` so they are not in the runtime resource. `boot/%ZSTART.mac` sits outside
the module SourcesRoot because `^%ZSTART` must be created in the `%SYS` namespace. The module file
is renamed from the template's `dc-sample` to a `signalnoir` IPM module.

## Complexity Tracking

> Deviations that need justification beyond the default. No Constitution principle is violated.

| Deviation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|--------------------------------------|
| Health endpoint added to the product API (frozen `openapi-signalnoir.yaml`) | The spec requires a health surface that distinguishes liveness, readiness and provider availability, which the frozen contract does not expose | Reusing `GET /cases` as readiness conflates a product endpoint with an operational signal and cannot separate provider availability; a contract change is recorded instead |
| `boot/%ZSTART.mac` outside the IPM SourcesRoot | `^%ZSTART` must live in the `%SYS` namespace, not the application package | Shipping the routine inside the app package would require a namespace map and hides the startup seam; an explicit `%SYS` load preserves the two-step bootstrap of AD-27 |
| A `docs/seams.md` deliverable alongside `specs/001.../contracts/seams.md` | `docs/seams.md` is the contract the *other* feature teams consume, independent of the spec directory | Pointing consumers at a `specs/` path couples them to a numbered feature directory and invites drift; the spec contract is the agreed draft and `docs/seams.md` is the published artifact |
