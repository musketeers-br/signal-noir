# Implementation Plan: Investigation and Proposal Production

**Branch**: `006-investigation-and-proposal` | **Date**: 2026-10-25 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `specs/006-investigation-and-proposal/spec.md`

## Summary

An `Investigate` follow-up (written by 003) is handled by a new `InvestigationService`. It claims
the request at most once, checks the Case is still `Investigating` at the request's version, opens
an Investigation record, records the Case's Exceptions as Evidence, and collects the base Evidence
package through a **Tools gateway** that is read-only by construction (allowlist from the core),
charges every call against a **server-side budget** (6 calls / 20 s, persisted on the Investigation
under the Case lock), scans results for embedded instructions (core `Suspicion`), and records each
call as Evidence **before** returning it. The proposer of the Case's mode (Agent, Rules or Replay)
runs in a separate worker process behind one `Proposer` port and returns a raw answer; the core
`ProposalShape` converts it into the immutable Proposal DTO (evidence-linked claims, catalog
Action, closed preconditions). `CaseService.CompleteInvestigation` records the Proposal and moves the
Case to `DecisionProposed` in one transaction, only while the Investigation is still open. The
coordinator closes the Investigation on the time limit, so a late answer is discarded and recorded.
The Agent proposer calls the AI Hub through an internal `AgentRuntime` port, in pre-collected
Evidence mode, with a new session per Investigation; when the AI Hub or the key is missing, the
result is a value that ends in `ReviewRequired`.

## Technical Context

**Language/Version**: ObjectScript. Dev instance `congenial-waffle-iris-1` is IRIS 2026.2 build 221
**without AI Hub** (`%AI.*` absent, research R0); target remains build 154.

**Primary Dependencies**: `%Persistent`, `%DynamicObject`, `%Net.HttpRequest` (Simulator reads),
`JOB` (proposer worker), `%UnitTest`. AI Hub `%AI.Agent`/`%AI.Provider` reached only by dynamic
dispatch from one adapter class.

**Storage**: new `EvidenceRecord`, `ProposalRecord`, `InvestigationRecord` in
`SignalNoir.Application.Model`; `OrderRecord` gains `scenarioInstanceId`.

**Testing**: `%UnitTest` through iris-agentic-dev; scripted proposers and evidence sources under
`tests/.../Fakes`; `tests/contract/validate_live.py` extended to the new detail layers.

**Target Platform**: single IRIS container; Simulator over HTTP (`SN_SIM_BASE_URL`).

**Project Type**: single IRIS/IPM project.

**Performance Goals**: Investigation ≤ 20 s wall clock by construction; Tool reads time out at 5 s
each so the base package cannot alone exhaust the budget silently.

**Constraints**: read-only Tools; no runtime code execution; secrets only from the runtime
environment and never persisted; calendar-gate exception granted for this feature (research).

**Scale/Scope**: one Investigation per request; tens of Cases per Benchmark run.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- [x] **I. Pure Core** — budget, read-tool allowlist and base package, suspicious-content scan and
  answer→Proposal conversion live in `SignalNoir.Core` (no I/O). Simulator reached only over HTTP.
- [x] **II. Closed Catalog / Read-Only Agent** — Tools gateway accepts only the 7 reading Tools of
  the contract's Evidence `source` enum; Actions outside the catalog are refused at conversion;
  embedded instructions are marked and change nothing; no code execution.
- [x] **III. One Validator** — every proposer's answer goes through the same conversion; the
  Proposal is handed to the single Validator by its integration (004/007), never by mode.
- [x] **IV. Human Authority** — not exercised; the Proposal is immutable (content hash guard) so an
  Approval can bind it.
- [x] **V. Case as Source of Truth** — Evidence, Proposal and Investigation are child records
  written only by `CaseService`; Proposal + `Investigating → DecisionProposed` commit together under
  the Case lock with the Investigation-open and version check; I/O (HTTP, LLM) is outside every
  transaction.
- [x] **VI. Effects at Most Once** — no effect; the request is claimed with `pending → dispatched`
  CAS so it runs once.
- [x] **VII. Honest Outcomes** — provider/budget/conversion failures are values ending in
  `ReviewRequired` with the cause; absence of information is its own Evidence kind; late answers are
  discarded and recorded.
- [x] **VIII. Honest Measurement** — Agent, Rules and Replay share gateway, budget, conversion and
  path; metrics recorded per Investigation.
- [x] **IX. Verifiable Increments** — five stories, each with failing tests first.
- [x] **Platform Constraints** — the key is read from the environment at call time and never
  stored; synthetic data.
- [ ] **iris-agentic-dev** — generic platform behavior used here (JOB, `%Net.HttpRequest`, locks)
  verified live. **The AI Hub calls could not be verified**: the dev instance has no `%AI.*`. The
  plan does not rely on them for any test or guarantee: the adapter is isolated, dynamically
  dispatched, and its absence is the tested "provider unavailable" path. Verification on build 154
  is task T060, required before G2. See Complexity Tracking.

### Post-design re-check (after Phase 1)

Gates I–IX pass. The one open item is the AI Hub verification above. Seam changes are explicit in
`contracts/contract-change-006-investigation-seam.md`; the HTTP contract is unchanged.

## Project Structure

### Documentation (this feature)

```text
specs/006-investigation-and-proposal/
├── plan.md  research.md  data-model.md  quickstart.md  tasks.md
├── contracts/contract-change-006-investigation-seam.md
└── checklists/requirements.md
```

### Source Code (repository root)

```text
src/SignalNoir/
├── Core/
│   ├── Budget.cls            # NEW 6 calls / 20 s
│   ├── ToolCatalog.cls       # NEW read-tool allowlist, base package
│   ├── Suspicion.cls         # NEW embedded-instruction scan
│   ├── ProposalShape.cls     # NEW answer -> Proposal DTO (or reasons)
│   ├── Dto/Evidence.cls      # contract fields
│   ├── Dto/Proposal.cls      # contract fields
│   ├── Dto/InvestigationContext.cls  # NEW
│   ├── Port/Proposer.cls     # Propose(context)
│   ├── Port/EvidenceSource.cls # NEW internal port: Read(tool, args)
│   └── Port/AgentRuntime.cls # NEW internal port: Complete(system, input)
├── Application/
│   ├── CaseService.cls       # + StartInvestigation, ChargeToolCall, RecordEvidence,
│   │                         #   CompleteInvestigation, CloseInvestigation, DiscardRequest
│   ├── InvestigationService.cls # NEW coordinator + worker entry
│   ├── ToolGateway.cls       # NEW Port.Tools: allowlist, budget, record-first, scan
│   └── Model/ EvidenceRecord, ProposalRecord, InvestigationRecord (NEW); OrderRecord +scenarioInstanceId
├── Tools/
│   ├── Sources.cls           # NEW routes tool -> Simulator or local
│   ├── SimulatorSource.cls   # NEW HTTP GET to openapi-sim read endpoints
│   └── LocalSource.cls       # NEW order timeline; policies/mappings = absence until 004
├── Proposers/
│   ├── Factory.cls           # NEW mode -> proposer (only place that reads mode)
│   ├── Agent.cls             # NEW pre-collected mode, prompt XData, AgentRuntime
│   ├── AiHubRuntime.cls      # NEW dynamic %AI.* adapter (unverified, see R1)
│   ├── Rules.cls             # NEW minimal deterministic proposer
│   ├── Replay.cls            # NEW recorded answers
│   └── Unavailable.cls       # new signature
├── Api/Dispatch.cls          # CaseDetail evidence/proposals/diagnosis/metrics; summary currentProposal
└── Interop/Service/OrderIn.cls # + scenarioInstanceId
tests/SignalNoir/Tests/
├── Core/        TestBudget, TestToolCatalog, TestSuspicion, TestProposalShape
├── Application/ TestInvestigation, TestInvestigationBudget, TestToolGateway, TestProposerModes,
│                TestProviderFailures
├── Api/         TestCaseDetailLayers
└── Fakes/       ScriptedProposer, ScriptedSource, FakeAgentRuntime, AgentWithFakeRuntime,
                 FakeProposer/FakeTools (new signatures)
```

**Structure Decision**: same single IRIS/IPM layout; a new `SignalNoir.Tools` package holds the
evidence-source adapters named in the architecture (`Tools` depends on Application/Core).

## Complexity Tracking

| Deviation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|--------------------------------------|
| AI Hub adapter not verified live (Constitution, iris-agentic-dev gate) | The dev instance has no AI Hub and no build 154 image is available locally | Blocking the whole feature would block G2; writing the adapter against undocumented assumptions without isolation would put unverified behavior on the tested path. Isolation + dynamic dispatch + T060 keeps every guarantee testable and the gap visible |
| Proposer runs in a `JOB` worker | The 20 s limit must hold even when a provider call hangs; a synchronous call cannot be interrupted | In-process deadline checks only fire after the call returns, so a hung call would hold the Case in `Investigating` |
| Budget counters persisted on the Investigation record | The worker and the coordinator are different processes; the count must be server-side and shared | An in-memory counter in the proposer's process would be trusted to the proposer |
| Seam change 006 (Proposer port signature) | The proposer needs the pre-collected Evidence and the gateway; its answer must be raw data converted by the core | Letting proposers build the Proposal DTO themselves gives three conversion paths |
