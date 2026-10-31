# Data Model: Case Precedents

**Feature**: 015-case-precedents | **Date**: 2026-10-31 | Decisions: [research.md](./research.md)

## PrecedentRecord (persistent, `SignalNoir.Application.Model.PrecedentRecord`)

One closed Case seen as a lesson, for one embedding model.

| Field | Type | Rule |
|---|---|---|
| `caseId` | string(64) | unique with `embeddingModel`; a terminal Case |
| `embeddingModel` | string(64) | unique with `caseId`; e.g. `lexical-hash-v1`, `text-embedding-3-small` |
| `orderId`, `partnerId` | string | copied from the Case |
| `factsJson` | string(4096) | the structured facts used (R4), codes only |
| `description` | string(600) | short display text built from the facts |
| `rawText` | string(600) | exact text that was embedded (DPI-I-557: raw text kept beside the vector) |
| `mode` | `lexical` \| `provider` | |
| `dimension` | integer | always 1536 (R1) |
| `embedding` | `%Library.Vector(DOUBLE, 1536)` | HNSW cosine index; never leaves the server |
| `finalState` | terminal state | |
| `action` | catalog Action or empty (cancelled) | |
| `closedAt` | ISO-8601 UTC | Case `updatedAt` at the terminal transition |
| `durationSeconds` | integer | `closedAt - createdAt` |
| `synthetic`, `replay` | boolean | copied from the Case |
| `indexedAt` | ISO-8601 UTC | |

Indexes: unique `precedentKey` (`caseId`, `embeddingModel`); `modelIdx` on `embeddingModel`;
`embeddingHnsw` on `embedding` AS HNSW(Distance='Cosine'). The row id is the default integer: build
154 refuses an HNSW index on a class whose IdKey is not a single positive integer (ERROR #7222).

Validation: one row per (Case, model) by the unique key, so a redelivered or concurrent index of the same Case
fails the second insert and is treated as "already indexed" (FR-001). `rawText` and `factsJson`
contain only allow-listed fields (R4); a unit test feeds an Order note with an embedded instruction
and asserts it is absent.

Eligibility (computed, not stored): `state` terminal; `runId` empty (Benchmark never, FR-004);
`replay = 0` unless `SN_PRECEDENTS_INCLUDE_REPLAY=1`.

## IndexState (persistent singleton, `SignalNoir.Application.Model.PrecedentIndexState`)

| Field | Type | Rule |
|---|---|---|
| `rebuilding` | boolean | set by `Rebuild()`, cleared at its end |
| `rebuildStartedAt` | ISO-8601 | |
| `lastIndexedAt` | ISO-8601 | |
| `lastError` | string(256) | reason of the last failed embed, no key, no text |

Model, mode and dimension are **not** stored here: they come from the configured embedder at call
time, and the counts come from `PrecedentRecord` (`COUNT(*) WHERE embeddingModel = ?` and total).

States as seen by a search:

```text
                 Rebuild() start                      Rebuild() end
   (normal) ───────────────────────▶ rebuilding ─────────────────────▶ (normal)
       │                                  ▲ interrupted: flag stays, next Rebuild()/sweep resumes
       │ configured model has 0 rows, other model has rows
       └──────────────▶ needs_rebuild (derived, not stored)
```

## PrecedentMatch (contract DTO, `SignalNoir.Core.Dto.PrecedentMatch`)

Public fields of one result: `caseId`, `orderId`, `partnerId`, `description`, `action`
(nullable), `finalState`, `closedAt`, `durationSeconds`, `similarity` (0..1, 4 decimals),
`synthetic`, `replay`. Never the vector, never `rawText` (FR-008).

## PrecedentSearch (contract DTO, response of `getCasePrecedents`)

| Field | Rule |
|---|---|
| `caseId` | the Case asked about |
| `status` | `results` \| `no_precedents` \| `nothing_similar` \| `rebuilding` \| `needs_rebuild` \| `unavailable` |
| `mode` | `lexical` \| `provider` |
| `model`, `dimension` | of the configured embedder |
| `k`, `minSimilarity` | as applied |
| `items` | `PrecedentMatch[]`, empty unless `status = results` |
| `reason` | set when `unavailable` or `needs_rebuild` (`provider_unavailable`, `unsupported_dimension`, `index_error`, `model_changed`) |
| `recorded` | whether this search wrote its Timeline record (false when rate-limited or the Case was busy) |
| `notice` | fixed text: "Similarity search over earlier Cases. Not Evidence about this Case." |

## PrecedentSearchRecord (Timeline `Annotation`, no new table)

`actor`: `system` (console) or `agent`; `refId`: the caseId; payload:

```json
{"kind": "precedent_search", "requester": "console", "status": "results", "mode": "lexical",
 "model": "lexical-hash-v1", "count": 3, "precedentCaseIds": ["case_…"], "durationMs": 12,
 "reason": ""}
```

No description, no raw text, no key (FR-015, SC-005). At most one per (Case, requester) per 60 s.

## InvestigationContext.precedents (seam v5, optional)

`PrecedentMatch[]` or absent. Present only when `SN_PRECEDENTS_AGENT=1` and the Case has no `runId`
of a frozen run (R8). Never converted to Evidence.

## Configuration (runtime environment, no secrets in code or DB)

| Variable | Default | Meaning |
|---|---|---|
| `SN_EMBED_PROVIDER` | empty | `openai`; empty → lexical |
| `SN_EMBED_MODEL` | empty | must return 1536 dimensions |
| `SN_EMBED_API_KEY` | empty | read at call time only |
| `SN_PRECEDENTS_MIN_SIMILARITY` | `0.6` | FR-007 |
| `SN_PRECEDENTS_DEFAULT_K` / `_MAX_K` | `5` / `10` | FR-006 |
| `SN_PRECEDENTS_RECORD_SECONDS` | `60` | FR-016 rate limit |
| `SN_PRECEDENTS_INCLUDE_REPLAY` | `0` | FR-004 |
| `SN_PRECEDENTS_AGENT` | `0` | FR-020; MUST be `0` in the frozen run |
