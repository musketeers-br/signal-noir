---
description: "Tasks for feature 006 — Investigation and Proposal Production"
---

# Tasks: Investigation and Proposal Production

**Input**: `specs/006-investigation-and-proposal/` (plan, spec, research, data-model,
contracts/contract-change-006-investigation-seam.md, quickstart)

**Tests**: MANDATORY (TDD). Compile and run on the live instance through iris-agentic-dev.

**Calendar gate**: waived for this feature by Henry on 2026-10-25 (research.md).

**Depends on**: feature 003 (branch `003-order-case-lifecycle`, committed).

## Format: `[ID] [P?] [Story] Description`

---

## Phase 1: Setup

- [X] T001 Run the full suite on the branch start and record the count in `specs/006-investigation-and-proposal/research.md` (baseline: 003's suite)

---

## Phase 2: Foundational (blocking all stories)

- [X] T002 [P] Rewrite `src/SignalNoir/Core/Dto/Evidence.cls` with the contract fields (evidenceId, caseId, investigationId, kind fact|absence, source, calledBy, params, result As %DynamicAbstractObject, payload alias, observedAt, durationMs, suspicious, suspiciousExcerpts list, obsoletedBy)
- [X] T003 [P] Rewrite `src/SignalNoir/Core/Dto/Proposal.cls` per contract change 006 (proposalId, caseId, origin, createdAt, current, supersededBy, diagnosis, action, params, scope, confidence, preconditions, versions, metrics, priorReceiptCandidate)
- [X] T004 [P] Create `src/SignalNoir/Core/Dto/InvestigationContext.cls` (investigationId, case, order, evidence list, tools As Port.Tools, maxToolCalls, budgetMs, startedAt)
- [X] T005 [P] Create internal ports `src/SignalNoir/Core/Port/EvidenceSource.cls` (`Read(toolName, args)`) and `src/SignalNoir/Core/Port/AgentRuntime.cls` (`Complete(systemPrompt, input)`)
- [X] T006 Change `src/SignalNoir/Core/Port/Proposer.cls` to `Propose(context As InvestigationContext)`; update `src/SignalNoir/Proposers/Unavailable.cls`, `tests/SignalNoir/Tests/Fakes/FakeProposer.cls` (configurable answer), `tests/SignalNoir/Tests/Fakes/FakeTools.cls`, `tests/SignalNoir/Consumer/Consumer.cls`, `src/SignalNoir/Application/CaseService.cls` (`ProcessException` availability probe) and `tests/SignalNoir/Tests/Seam/TestConsumerUsesSeam.cls`
- [X] T007 Create models `src/SignalNoir/Application/Model/EvidenceRecord.cls`, `ProposalRecord.cls` (content hash guard in `%OnBeforeSave`), `InvestigationRecord.cls`; add `scenarioInstanceId` to `src/SignalNoir/Application/Model/OrderRecord.cls`, `Core/Dto/Order.cls` and `OrderIn.Accept` in `src/SignalNoir/Interop/Service/OrderIn.cls`
- [X] T008 [P] Test doubles: `tests/SignalNoir/Tests/Fakes/ScriptedSource.cls` (EvidenceSource with per-tool canned results from `^SignalNoir.TestScript(caseId,"source",tool)`, absence by default), `ScriptedProposer.cls` (answer/sleep/extra tools from `^SignalNoir.TestScript(caseId,…)`), `FakeAgentRuntime.cls`, `AgentWithFakeRuntime.cls`; helpers in `tests/SignalNoir/Tests/Support.cls` (`InvestigatingCase`, `Script`, `RunInvestigation`)

**Checkpoint**: everything compiles; 003 suites still pass.

---

## Phase 3: User Story 1 — An Investigation produces an evidence-linked Proposal (P1) 🎯 MVP

**Independent Test**: `Core.TestProposalShape`, `Application.TestInvestigation`.

- [X] T009 [P] [US1] `tests/SignalNoir/Tests/Core/TestToolCatalog.cls`: the 7 read tools exactly; base package = health, history, origin status, mapping catalog, policies; `IsReadTool("partner.send")` = 0
- [X] T010 [P] [US1] `tests/SignalNoir/Tests/Core/TestProposalShape.cls`: well-formed answer → Proposal DTO with scope `single_case`, author, versions, metrics; claims without evidenceIds, unknown evidence id, Action outside the catalog, APPLY_APPROVED_MAPPING without mapping fields, unknown param key, unknown confidence, unknown precondition, discarded hypothesis without reason, non-object answer → ordered reasons and no Proposal
- [X] T011 [P] [US1] `tests/SignalNoir/Tests/Application/TestInvestigation.cls`: P5 Case → `DecisionProposed` by actor of the mode; Exceptions recorded as `system.exception` Evidence; 5 `ToolCalled` events before `ProposalCreated`; Proposal claims cite Case Evidence; P8b answer keeps mappingId/mappingVersion; ProposalRecord content cannot be updated (save refused); second Investigation supersedes the first Proposal (current/supersededBy); Investigation record shows mode, versions, duration, toolCalls, tokens; stale request (Case moved) and duplicate request are discarded with `CommandDiscarded`, no second Investigation
- [X] T012 [P] [US1] Create `src/SignalNoir/Core/ToolCatalog.cls`
- [X] T013 [P] [US1] Create `src/SignalNoir/Core/ProposalShape.cls` (`Convert(answer, evidenceIds, author, versions, metrics)` → Result with Dto.Proposal or `invalid_response` + details.reasons)
- [X] T014 [US1] Add investigation commands to `src/SignalNoir/Application/CaseService.cls`: `StartInvestigation`, `RecordEvidence`, `ChargeToolCall` (budget part in US2), `CompleteInvestigation`, `CloseInvestigation`, `DiscardAnswer`, per data-model.md
- [X] T015 [US1] Create `src/SignalNoir/Application/ToolGateway.cls` (Port.Tools: allowlist → charge → source read outside transaction → record Evidence → return)
- [X] T016 [US1] Create `src/SignalNoir/Tools/Sources.cls`, `src/SignalNoir/Tools/SimulatorSource.cls` (HTTP GET, 5 s timeout, `SN_SIM_BASE_URL`, scenarioInstanceId), `src/SignalNoir/Tools/LocalSource.cls` (order timeline; policies/mappings = absence until 004)
- [X] T017 [US1] Create `src/SignalNoir/Application/InvestigationService.cls`: `Run(commandId)` coordinator (start, base package, JOB worker, wait/close), `Work(investigationId)` worker (rebuild proposer, propose, convert, complete or close/discard), `RunPending(max)`
- [X] T018 [US1] Create `src/SignalNoir/Proposers/Factory.cls` (only reader of the mode)
- [X] T019 [US1] Compile and run US1 suites green

---

## Phase 4: User Story 2 — The budget is enforced by the server (P1)

- [X] T020 [P] [US2] `tests/SignalNoir/Tests/Core/TestBudget.cls`: limits 6 / 20000 ms; `Breach(calls, elapsed)` → "", "tool calls", "time"
- [X] T021 [P] [US2] `tests/SignalNoir/Tests/Application/TestInvestigationBudget.cls`: proposer asks 2 extra Tools → 6th recorded, 7th refused without reaching the source, `ReviewRequired` "investigation budget exceeded: tool calls", 6 Evidence kept; proposer sleeping past a short budget → `ReviewRequired` "…: time", Evidence kept, the late answer creates no Proposal and leaves `CommandDiscarded`
- [X] T022 [US2] Create `src/SignalNoir/Core/Budget.cls`; complete `ChargeToolCall` and the coordinator deadline in `CaseService`/`InvestigationService`
- [X] T023 [US2] Compile and run US2 green

---

## Phase 5: User Story 3 — Read-only Tools, recorded first, untrusted content cannot steer (P1)

- [X] T024 [P] [US3] `tests/SignalNoir/Tests/Core/TestSuspicion.cls`: EN/PT phrases found with excerpts; nested arrays/objects scanned; clean text → none; case-insensitive
- [X] T025 [P] [US3] `tests/SignalNoir/Tests/Application/TestToolGateway.cls`: write-like names refused, nothing charged, `write_attempt_blocked` recorded; Evidence exists before `Invoke` returns (source double asserts the Case has no Evidence for its own call yet, gateway result id exists in the store); absence result → `kind=absence`; suspicious Partner log → Evidence suspicious + `embedded_instruction_blocked`; twin Cases with/without injection in Order notes and Partner log → same Action and params with the deterministic proposer; with the live agent (when configured) the poisoned twin never reaches the instructed Action (SC-004 as revised after T060)
- [X] T026 [P] [US3] Add to `TestInvestigation.cls`: answer with Action outside catalog / claims citing unknown Evidence → `ReviewRequired` "invalid proposer response"
- [X] T027 [US3] Create `src/SignalNoir/Core/Suspicion.cls`; wire the scan into `ToolGateway` and into the Order snapshot Evidence
- [X] T028 [US3] Compile and run US3 green

---

## Phase 6: User Story 4 — One Proposer port for Agent, Rules and Replay (P2)

- [X] T029 [P] [US4] `tests/SignalNoir/Tests/Application/TestProposerModes.cls`: same Case in rules, replay (recorded answer) and agent-with-fake-runtime modes → same Proposal structure, same base Evidence sources, authors differ; the agent runtime is called once with the Evidence ids in its input and a fresh session tag per Investigation; Rules goes through the gateway (its extra Tool call is a recorded Evidence); Replay with no recording → `ReviewRequired`
- [X] T030 [US4] Create `src/SignalNoir/Proposers/Rules.cls` (minimal deterministic: unhealthy partner/timeouts → HOLD; one applicable mapping in the catalog Evidence → APPLY_APPROVED_MAPPING; else REQUEST_REVIEW; claims cite Evidence)
- [X] T031 [US4] Create `src/SignalNoir/Proposers/Replay.cls` (`Record(key, answerJson)`, `Propose` reads by orderId)
- [X] T032 [US4] Create `src/SignalNoir/Proposers/Agent.cls` (prompt XData, PROMPTVERSION, input = Case + Order + Evidence as data, parse JSON answer, strip code fence) and `src/SignalNoir/Proposers/AiHubRuntime.cls` (dynamic `%AI.*`, key from environment at call time, never stored)
- [X] T033 [US4] Compile and run US4 green

---

## Phase 7: User Story 5 — Provider problems end in review, with the reason (P2)

- [X] T034 [P] [US5] `tests/SignalNoir/Tests/Application/TestProviderFailures.cls`: agent mode with the real `AiHubRuntime` on this instance → `ReviewRequired` naming the unavailable provider, base Evidence kept; fake runtime refusal / prose answer / exception → `ReviewRequired` "invalid proposer response" or "provider unavailable: …"; Investigation record shows outcome, duration, toolCalls; no Evidence/Proposal/Timeline/Investigation field contains the configured key
- [X] T035 [US5] Map proposer failure codes to reasons in `InvestigationService.Work`; ensure `AiHubRuntime` never echoes the key in messages
- [X] T036 [US5] Compile and run US5 green

---

## Phase 8: Read views

- [X] T037 [P] `tests/SignalNoir/Tests/Api/TestCaseDetailLayers.cls`: CaseDetail carries `evidence[]` (Evidence schema fields), `proposals[]` (Proposal schema fields), `diagnosis` of the current Proposal, `currentProposalId`, `metrics` (provider, model, promptVersion, policyVersion, investigationDurationMs, toolCalls, tokens); CaseSummary `currentProposal {proposalId, action, confidence}`
- [X] T038 Extend `GetCase`/`ToSummaryDto` in `src/SignalNoir/Application/CaseService.cls` and payloads in `src/SignalNoir/Api/Dispatch.cls`
- [X] T039 Run `tests/contract/validate_live.py` against a Case with a Proposal and record the result

---

## Phase 9: Polish

- [X] T040 Publish `docs/seams.md` v4 from the contract change (and keep `specs/001-runtime-skeleton-and-seams/contracts/seams.md` identical)
- [X] T041 [P] Secret audit: grep `src/SignalNoir` for the key variable; confirm it is read only inside `AiHubRuntime` at call time
- [X] T042 Full run: all suites, `validate_live.py`, `contracts/tools/validate_fixtures.py`; record in research.md
- [X] T043 Update `docs/specify-prompts/PARALELISMO.md` board row 006
- [X] T060 **(done 2026-10-26, build 154 ARM64 Community + OpenAI gpt-4o-mini; see research T060)** On build 154 with a real key: run the Agent proposer through `AiHubRuntime` on a P5 Case, confirm the `%AI.*` calls, token fields and timeout behavior, and record them in research.md

---

## Dependencies & Execution Order

Setup → Foundational → US1 → US2 → US3 → US4 → US5 → Read views → Polish. US2/US3 reuse US1's
service and gateway (same files), so they run after it. T060 needs build 154 and is not blocking
for this branch.

## Parallel Opportunities

T002–T005, T008 in parallel; within each story the test tasks marked [P] in parallel;
`CaseService.cls`, `InvestigationService.cls` and `ToolGateway.cls` tasks are sequential.

## Implementation Strategy

MVP = Foundational + US1 + US2 + US3 (bounded, read-only, evidence-linked Proposal); then modes and
provider failures; then the detail projection the console (005) needs.
