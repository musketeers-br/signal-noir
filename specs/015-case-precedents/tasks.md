---
description: "Tasks for feature 015 — Case Precedents (Vector Search)"
---

# Tasks: Case Precedents (Vector Search)

**Input**: `specs/015-case-precedents/` (plan, spec, research, data-model,
contracts/contract-change-015-precedents.md, quickstart)

**Tests**: MANDATORY (TDD), written and run failing before each implementation task, on the live
instance through iris-agentic-dev; console tests with vitest.

## Phase 1: Setup

- [X] T001 Baseline: compile `src/` and run the full ObjectScript suite and `cd ui && npm test` on the branch start; record counts in research.md (R11)

## Phase 2: Foundational

- [X] T002 [P] `tests/SignalNoir/Tests/Core/TestPrecedentText.cls` then `src/SignalNoir/Core/PrecedentText.cls`: allow-listed fields in fixed order, code pattern drops free text (counted in `dropped`), examCodes sorted, close bucket, 512-char cap with `…[cut]`, query form omits finalState/action/closeBucket
- [X] T003 [P] `tests/SignalNoir/Tests/Core/TestLexicalVector.cls` then `src/SignalNoir/Core/LexicalVector.cls`: 1536 dims, deterministic, L2-normalized, same-family texts more similar than cross-family, empty text → zero vector, cosine helper
- [X] T004 [P] `tests/SignalNoir/Tests/Core/TestPrecedentStatus.cls` then `src/SignalNoir/Core/PrecedentStatus.cls`: status order rebuilding → unavailable → needs_rebuild → no_precedents → nothing_similar → results
- [X] T005 [P] Port `src/SignalNoir/Core/Port/Embedder.cls`; adapters `src/SignalNoir/Precedents/LexicalEmbedder.cls`, `src/SignalNoir/Precedents/ProviderEmbedder.cls` (dynamic `%Embedding.OpenAI`, key at call time, errors as values, length check 1536), embedder choice and the `SN_PRECEDENTS_*` / `SN_EMBED_*` variables in `PrecedentService.Default()`; TLS config created by the provider adapter
- [X] T006 Models `src/SignalNoir/Application/Model/PrecedentRecord.cls` (IdKey caseId+embeddingModel, `%Library.Vector(DOUBLE,1536)`, HNSW cosine index) and `src/SignalNoir/Application/Model/PrecedentIndexState.cls`; compile and confirm the HNSW index builds live

## Phase 3: User Story 2 — Closed Cases become precedents by themselves (P1)

- [X] T007 [P] [US2] `tests/SignalNoir/Tests/Application/TestPrecedentIndex.cls`: one record per terminal Case (4 states), none for non-terminal, Benchmark (`runId`) or Replay; `IndexPending()` twice → still one; Order note with an injected instruction absent from `rawText`/`factsJson`; failing embedder → Case still terminal, no record, `lastError` set, next run indexes it
- [X] T008 [US2] `src/SignalNoir/Application/PrecedentService.cls`: `Facts(caseId)`, `IndexPending(max)`, `IndexCase(caseId)` (duplicate insert = already indexed)
- [X] T009 [US2] Pass 5 in `src/SignalNoir/Tasks/Sweeper.cls` (`precedentsIndexed` in the result)

## Phase 4: User Stories 1, 3, 5 — Search, honest statuses, trace (P1)

- [X] T010 [P] [US1] `tests/SignalNoir/Tests/Application/TestPrecedentSearch.cls`: same-family first, self excluded, k default/max, ties by recency, below minimum → nothing_similar, empty → no_precedents, rebuilding flag → rebuilding, only other-model rows → needs_rebuild, failing embedder → unavailable with reason; reference families lexical top-1 ≥ 90% and stable (SC-001); 1,000 records < 1 s (SC-006)
- [X] T011 [P] [US5] Same file: one `Annotation` `precedent_search` per search with fields, no description text; second search within the window → `recorded: false`, no event; works on a terminal Case
- [X] T012 [US1] `Search(caseId, k, requester)` in `src/SignalNoir/Application/PrecedentService.cls`; `PrecedentMatch` as a JSON object built by the service
- [X] T013 [P] [US1] `tests/SignalNoir/Tests/Api/TestPrecedentsApi.cls`: 200 body shape, 400 for k out of range, 404 unknown Case, 200 `unavailable` on embedder failure
- [X] T014 [US1] `GET /cases/:caseid/precedents` in `src/SignalNoir/Api/Dispatch.cls`
- [X] T015 [US1] Contract change: `contracts/openapi-signalnoir.yaml` (operation + schemas), fixtures `contracts/fixtures/precedents.*.json` + `manifest.json`, `docs/seams.md` v5; run `contracts/tools/validate_fixtures.py`

## Phase 5: Console (US1, US3)

- [X] T016 [P] [US1] `ui/tests/precedents-panel.test.ts`: six statuses with distinct copy, lexical label, notice text, links to Cases, Failed/Cancelled not styled as success, SYNTHETIC/REPLAY labels, fetched once (polls do not refetch), axe clean
- [X] T017 [US1] `ui/src/lib/api/types.ts`, `ui/src/lib/api/client.ts` (`getPrecedents`), `ui/src/lib/api/fixtures.ts` (mock), `ui/src/lib/copy.ts`, `ui/src/lib/components/PrecedentsPanel.svelte`; mount in `Dossier.svelte` (next-step area) and `CaseDetail.svelte`
- [X] T018 [US4] `ui/tests/precedents-panel.test.ts`: with precedents, the resolution form has nothing pre-selected

## Phase 6: User Story 4 — Precedents never decide (P2)

- [X] T019 [US4] `tests/SignalNoir/Tests/Application/TestPrecedentNeutrality.cls`: Case detail Evidence holds no precedent; Validator still blocks on minimum Evidence with many precedents; Proposal built with and without precedents in context identical; Timeline differs only by `precedent_search` Annotations

## Phase 7: User Story 7 — Rebuild (P3)

- [X] T020 [US7] `TestRebuild` in `tests/SignalNoir/Tests/Application/TestPrecedentNeutrality.cls` then `Rebuild()` in `PrecedentService.cls`: model switch → count = eligible, no old-model rows; interrupted (flag left set) → second Rebuild completes without duplicates; search during rebuild → rebuilding

## Phase 8: User Story 6 — Agent precedents block (P3, optional)

- [X] T021 [US6] Tests in `tests/SignalNoir/Tests/Application/TestPrecedentNeutrality.cls`: default `AgentEnabled()` = 0; with the flag, `InvestigationContext.precedents` filled for a non-Benchmark Case, never for a Benchmark Case, no `EvidenceRecord` created; prompt input has the labelled PRECEDENTS block
- [X] T022 [US6] `src/SignalNoir/Core/Dto/InvestigationContext.cls` (+ `precedents`), `src/SignalNoir/Application/InvestigationService.cls`, `src/SignalNoir/Proposers/Agent.cls`

## Phase 9: Polish

- [X] T023 README section "Case precedents (IRIS Vector Search)" citing DPI-I-689 (what is covered, what is not) and the `SN_EMBED_*` / `SN_PRECEDENTS_*` variables; `.env.example` if present
- [X] T024 Full ObjectScript suite + `npm test` + `npm run check` green; record results in research.md (R11); provider live call recorded as not verified unless a key was available

## Dependencies

T002–T006 → US2 (T007–T009) → search (T010–T015) → console (T016–T018) → T019; T020 after T012;
T021–T022 after T012 (cut first if time is short); T023–T024 last.

## Parallel examples

T002, T003, T004, T005 touch different files and run in parallel. T010/T011/T013 tests can be
written together; T016 in parallel with T013–T015.

## Implementation strategy

MVP = Phases 1–4 (index + search API + trace). Then console, neutrality, rebuild, Agent block.
