---
description: "Tasks for feature 016 — Hybrid Proposer"
---

# Tasks: Hybrid Proposer

**Tests**: MANDATORY (TDD), on the live instance through iris-agentic-dev, with the fake Decisions and
AI Hub runtimes.

## Phase 1: Foundational

- [X] T001 Contract change 016: `ProposerMode` + `hybrid` in `contracts/openapi-signalnoir.yaml`; seams v7 in `docs/seams.md` and `specs/001-runtime-skeleton-and-seams/contracts/seams.md`
- [X] T002 `tests/SignalNoir/Tests/Fakes/HybridWithFakes.cls` (Hybrid over `DecisionsWithFakeRuntime` and `AgentWithFakeRuntime`)

## Phase 2: User Stories 1–3 (P1) 🎯 MVP

- [X] T003 [US1] [US2] [US3] `tests/SignalNoir/Tests/Application/TestHybridProposer.cls`: decisive → author `decisions`, zero AI Hub calls; each non-decisive outcome (below threshold, tie, other, refusal, invalid, HTTP error) → one Agent call, author `agent`; Agent also fails → `ReviewRequired` with the Agent's reason; one `proposer_cascade` event each time, no provider text
- [X] T004 [US1] [US2] `src/SignalNoir/Proposers/Hybrid.cls` (cascade, budget cap, `details.author`, `details.cascade`)
- [X] T005 [US2] `src/SignalNoir/Application/InvestigationService.cls` (author to `ProposalShape`, `meta.author`, cascade Annotation) and `src/SignalNoir/Application/CaseService.cls` (`CompleteInvestigation` uses the hybrid author)

## Phase 3: User Stories 4–5 (P2)

- [X] T006 [US4] `TestHybridProposer`: Decisions slower than its cap → Agent still proposes; total budget exceeded → "investigation budget exceeded: time"
- [X] T007 [US5] `src/SignalNoir/Proposers/Factory.cls`: `ClassFor`, `Ready`, `ConfiguredMode` accept `hybrid`; test in `TestHybridProposer`

## Phase 4: Polish

- [X] T008 README and `.env.example` (`SN_PROPOSER_MODE=hybrid`)
- [X] T009 Full ObjectScript suite and contract validators green; live smoke of a hybrid Investigation path (labelled live); results in research.md
