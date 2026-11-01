---
description: "Task list for feature 017 — Agent Prompt v2"
---

# Tasks: Agent Prompt v2

**Input**: [plan.md](./plan.md), [spec.md](./spec.md), [research.md](./research.md),
[data-model.md](./data-model.md), [contracts/agent-v2-instructions.md](./contracts/agent-v2-instructions.md),
[quickstart.md](./quickstart.md)

**Tests**: MANDATORY (Constitution IX, FR-015). Tests run on the dev container (`signalnoir-iris`,
`IRISAPP`), no live provider.

**Note on slicing**: every story changes the same text (the `SystemPrompt` XData of
`src/SignalNoir/Proposers/Agent.cls`), so the stories are sequential, not parallel. Each story adds its
section of the contract text and the assertions that pin it.

## Format: `[ID] [P?] [Story] Description`

---

## Phase 1: Setup

- [x] T001 Confirm the baseline: compile `src` and `tests` on the dev container and run the whole suite
  (`RunTest("SignalNoir","/noload/nodelete/recursive")`); record the pass/fail counts in
  specs/017-agent-prompt-v2/research.md (R5)

## Phase 2: Foundational

- [x] T002 Create the failing test class tests/SignalNoir/Tests/Proposers/TestAgentPromptV2.cls with a
  helper that returns `##class(SignalNoir.Proposers.Agent).Prompt()`, and a test that the instructions
  name no scenario family or variant (`P1`…`P9` as words, `tune`, `clean-`, `injection-`) (FR-012)

---

## Phase 3: User Story 5 — recorded, frozen version (P1) 🎯 MVP

**Goal**: every Agent Proposal records `agent-v2`.
**Independent Test**: a Proposal through `SignalNoir.Tests.Fakes.AgentWithFakeRuntime` has
`versions.prompt = "agent-v2"`.

- [x] T003 [US5] In tests/SignalNoir/Tests/Proposers/TestAgentPromptV2.cls add a test that
  `##class(SignalNoir.Proposers.Agent).#PROMPTVERSION` is `agent-v2` and that `Propose` over the fake
  runtime returns `details.promptVersion = "agent-v2"`; in
  tests/SignalNoir/Tests/Application/TestProposerModes.cls expect `versions.prompt = "agent-v2"`
- [x] T004 [US5] Set `Parameter PROMPTVERSION = "agent-v2"` in src/SignalNoir/Proposers/Agent.cls until T003
  passes

---

## Phase 4: User Story 3 — one decision order (P1)

**Goal**: the instructions carry the five steps, first applicable step wins.

- [x] T005 [US3] In TestAgentPromptV2.cls assert that `1. Identity`, `2. Partner instability`,
  `3. Approved mapping`, `4. Transient failure`, `5. Otherwise` appear in this order, with the sentence
  "The first step that applies decides the Action", and that the HOLD and REQUEST_REVIEW definitions are
  present (FR-001, FR-006b)
- [x] T006 [US3] Replace the `SystemPrompt` XData in src/SignalNoir/Proposers/Agent.cls with the text of
  contracts/agent-v2-instructions.md (verbatim) until T005 passes

---

## Phase 5: User Story 1 — the one approved Mapping (P1)

- [x] T007 [US1] In TestAgentPromptV2.cls assert the Mapping step names `sourceCode`, "every one of its
  conditions", `synonyms`, "letter case", "exactly one", "discarded hypothesis" (FR-003–FR-005); passes
  with the text of T006

---

## Phase 6: User Story 2 — hold vs retry (P1)

- [x] T008 [US2] In TestAgentPromptV2.cls assert the instability step names `DOWN`, `maintenance`,
  `timeouts are half or more`, "Answered errors", "Do not use errorRate", and the retry step names
  `maxAttempts` and "Without the attempt policy" (FR-006, FR-006a, FR-007); passes with the text of T006

---

## Phase 7: User Story 4 — confidence (P2)

- [x] T009 [US4] In TestAgentPromptV2.cls assert the three confidence lines (HIGH "stated directly by fact
  Evidence", MEDIUM "one inference", LOW "whenever you propose REQUEST_REVIEW") (FR-008); passes with
  the text of T006

---

## Phase 8: Polish & cross-cutting

- [x] T010 In TestAgentPromptV2.cls assert the unchanged parts are still present: the anti-injection
  sentence, the closed precondition list, the JSON answer shape (FR-009)
- [x] T011 Compile and run the whole suite; it stays green apart from failures already present in T001
- [x] T012 Record in specs/017-agent-prompt-v2/quickstart.md that the tuning rehearsal (FR-016) is pending
  a run with a provider key, and leave it to the team member who runs it

## Dependencies

T001 → T002 → T003 → T004 → T005 → T006 → T007/T008/T009/T010 (same test file, run in sequence) → T011 →
T012. No task depends on another feature; the Hybrid proposer (016) inherits the prompt without change.

## Implementation strategy

MVP is US5 (the version), then the full text in one replacement (T006), then the assertions that pin
each part. The rehearsal with the real model is the acceptance of SC-001–SC-006 and is not part of this
task list's automated checks.
