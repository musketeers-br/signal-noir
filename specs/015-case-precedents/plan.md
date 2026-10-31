# Implementation Plan: Case Precedents (Vector Search)

**Branch**: `015-case-precedents` | **Date**: 2026-10-31 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `specs/015-case-precedents/spec.md`

## Summary

Closed Cases become precedents in an IRIS vector table, and the Operator sees "Similar resolved
Cases" in the Dossier and the Case detail. A pure core builds a short description of a Case from
allow-listed structured facts (`Core.PrecedentText`) and, without any key, a deterministic hashed
vector (`Core.LexicalVector`, 1536 dimensions). An `Embedder` port has a lexical adapter and an
OpenAI adapter over `%Embedding.OpenAI` with the key read at call time. `PrecedentRecord` stores
facts, raw text and a `VECTOR(DOUBLE,1536)` with an HNSW cosine index, one row per (Case, model).

Indexing is a scan, not a queue: "terminal, not Benchmark, not Replay, and no row for the configured
model" is pending work, picked up by a fifth Sweeper pass and by a background job after a terminal
transition. The Case transaction does not change. A search returns one of six honest statuses with
HTTP 200, never Evidence, and appends one rate-limited `Annotation` (`kind: precedent_search`) to the
Case Timeline: the GenAI trace that supports DPI-I-689. Optional (P3): `SN_PRECEDENTS_AGENT=1` adds a
labelled precedents block to the Agent's input, off by default and in the frozen run. One additive
contract change: `GET /cases/{caseId}/precedents`.

## Technical Context

**Language/Version**: ObjectScript on IRIS 2026.3.0AI build 154 (verified, research R0); console
Svelte 5 + SvelteKit static (005/014).

**Primary Dependencies**: IRIS SQL vector search (`VECTOR`, `TO_VECTOR`, `VECTOR_COSINE`, HNSW
index); `%Embedding.OpenAI` (optional, dynamic dispatch); existing `CaseService.Append`,
`Tasks.Sweeper`, `InvestigationService`, `Api.Dispatch`.

**Storage**: new `PrecedentRecord` (HNSW on `embedding`) and `PrecedentIndexState` in
`SignalNoir.Application.Model`; one global for the record rate limit.

**Testing**: `%UnitTest` through iris-agentic-dev; `tests/contract/validate_live.py` and
`contracts/tools/validate_fixtures.py`; vitest + testing-library + axe-core for the console.

**Target Platform**: the `signalnoir-iris` container (single IRIS project + static console).

**Project Type**: single IRIS application with a static web console.

**Performance Goals**: search over 1,000 precedents under 1 s (SC-006); indexing within one sweep
(≤ 1 min) of the terminal transition.

**Constraints**: no key required (lexical mode is complete); no free text in vectors, records or
logs; no I/O inside the Case transaction; HNSW needs a fixed vector length (R0), so every stored
vector has 1536 dimensions.

**Scale/Scope**: hundreds to low thousands of closed synthetic Cases; one new endpoint, one console
panel, one optional Agent input.

## Constitution Check

*Initial and post-design: all pass.*

- [x] **I. Pure Core** — description building, value allow-list, lexical vectorization and the
  status decision (`Core.PrecedentStatus`) are pure core classes; `PrecedentService` only reads rows,
  calls the `Embedder` port and runs SQL. The Simulator is not touched.
- [x] **II. Closed Catalog / Read-Only Agent** — no Action added; the precedents read is read-only;
  Order/partner/Agent text never enters the description (R4), so it cannot carry instructions.
- [x] **III. One Validator** — precedents are not Validator input and not Evidence; `ProposalShape`
  still accepts only Evidence ids; neutrality suite proves identical verdicts (SC-002).
- [x] **IV. Human Authority** — Approval and resolution untouched; the panel pre-selects nothing.
- [x] **V. Case as Source of Truth** — no change to the transition transaction; the only Case write
  is an `Annotation` through `CaseService.Append` (the single command path, no version bump);
  precedents are a derived projection rebuilt from Cases.
- [x] **VI. Effects at Most Once** — no effect on any Partner; indexing is idempotent by IdKey.
- [x] **VII. Honest Outcomes** — six distinct statuses, lexical never shown as semantic, failures as
  `Result` values, HTTP 200 with `status: unavailable` so the Case always opens.
- [x] **VIII. Honest Measurement** — Benchmark Cases never indexed; Agent use off by default and in
  the frozen run; the flag is exposed for 010's report (FR-021 delivered by 010, declared dependency).
- [x] **IX. Verifiable Increments** — sliced by story (index → search API + trace → panel →
  neutrality → rebuild → Agent), each with its test.
- [x] **Platform Constraints** — build 154; synthetic; key only at runtime (not in `%Embedding.Config`,
  R1); provider mode not announced until verified live (R3).
- [x] **iris-agentic-dev** — vector, HNSW and `%Embedding` claims verified live (research R0); a real
  provider call is an explicit open verification for tasks; not a runtime dependency.

Engineering standards: SRP (text, vector, status, service, adapter, panel each one reason to change);
DIP through the `Embedder` port; YAGNI (one provider adapter, one vector length, no queue).

## Project Structure

### Documentation (this feature)

```text
specs/015-case-precedents/
├── spec.md  plan.md  research.md  data-model.md  quickstart.md
├── contracts/contract-change-015-precedents.md
├── checklists/requirements.md
└── tasks.md            # /speckit-tasks
```

### Source Code (repository root)

```text
src/SignalNoir/Core/  PrecedentText.cls  LexicalVector.cls  PrecedentStatus.cls
src/SignalNoir/Core/Port/Embedder.cls
src/SignalNoir/Core/Dto/InvestigationContext.cls (+ precedents; PrecedentMatch is a JSON object)
src/SignalNoir/Precedents/  LexicalEmbedder.cls  ProviderEmbedder.cls   # chosen in PrecedentService.Default()
src/SignalNoir/Application/PrecedentService.cls          # IndexPending, Search, Rebuild, AgentEnabled
src/SignalNoir/Application/Model/  PrecedentRecord.cls  PrecedentIndexState.cls
src/SignalNoir/Application/InvestigationService.cls      # optional precedents read (US6)
src/SignalNoir/Proposers/Agent.cls                       # PRECEDENTS block when present
src/SignalNoir/Tasks/Sweeper.cls                         # pass 5: IndexPending
src/SignalNoir/Api/Dispatch.cls                          # GET /cases/:caseid/precedents
contracts/openapi-signalnoir.yaml  contracts/fixtures/precedents.*.json  docs/seams.md (v5)
tests/SignalNoir/Tests/Core/  TestPrecedentText  TestLexicalVector  TestPrecedentStatus
tests/SignalNoir/Tests/Application/  TestPrecedentIndex  TestPrecedentSearch  TestPrecedentNeutrality (+ rebuild)  PrecedentSupport
tests/SignalNoir/Tests/Fakes/FakeEmbedder.cls
tests/SignalNoir/Tests/Api/TestPrecedentsApi
ui/src/lib/api/  client.ts (getPrecedents)  types.ts  fixtures.ts
ui/src/lib/components/PrecedentsPanel.svelte  Dossier.svelte  CaseDetail.svelte
ui/src/lib/copy.ts
ui/tests/precedents-panel.test.ts  (axe light and dark)
tests/contract/validate_live.py                         # getCasePrecedents
README.md                                               # Precedents section, cites DPI-I-689
```

**Structure Decision**: existing single IRIS project layout; a new `SignalNoir.Precedents` package
holds the embedder adapters, like `Proposers` holds the proposer adapters.

## Delivery order and cut line

1. US2 index (core text + lexical vector + record + Sweeper pass) — P1
2. US1/US3/US5 search API, statuses, trace + contract change — P1
3. Console panel (Dossier + detail) — P1
4. US4 neutrality suite — P2
5. US7 rebuild — P3
6. US6 Agent precedents block — P3, **first to cut**
7. Provider adapter live check — only if a key is available; otherwise ship lexical and say so

README: a "Case precedents (IRIS Vector Search)" section and the declared Community Opportunity idea
DPI-I-689 with a link, stating what this feature covers (per-search trace in the Case Timeline) and
what it does not (Visual Trace, which needs a real `Ens.Production`).

## Complexity Tracking

| Deviation | Why Needed | Simpler Alternative Rejected Because |
|---|---|---|
| Fixed 1536 dimensions, lexical vectors included | HNSW refuses a vector without fixed length (R0) | Per-dimension tables double the search path; no index loses the vector-search point |
| A global for the record rate limit | FR-016 needs "last recorded at" per (Case, requester) outside the Case transaction | Scanning the Timeline on every open is slower; a table row per pair adds a class for one timestamp |
| Agent precedents outside the six-call budget | The base package already spends the whole budget (009) | Charging it would drop a base Evidence read and change investigations even when off |
