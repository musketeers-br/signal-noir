# Research: Case Precedents (Vector Search)

**Feature**: 015-case-precedents | **Date**: 2026-10-31

All platform claims below were checked on the live instance through iris-agentic-dev
(`IRIS for UNIX ... 2026.3.0AI (Build 154U)`, namespace `USER`, container `signalnoir-iris`) on
2026-10-31. Probe tables were created in a scratch schema `SnProbe` and dropped.

## R0 — Live verification (iris-agentic-dev)

| Check | Command | Result |
|---|---|---|
| Vector functions | `query "SELECT VECTOR_COSINE(TO_VECTOR('1,0,0',DOUBLE), TO_VECTOR('1,1,0',DOUBLE)), VECTOR_DOT_PRODUCT(...)"` | `0.7071…`, `11` |
| Fixed-length column + HNSW | `exec`: `CREATE TABLE SnProbe.Vec (k VARCHAR(20), v VECTOR(DOUBLE,4))`, `CREATE INDEX hv ON SnProbe.Vec (v) AS HNSW(Distance='Cosine')` | both `SQLCODE 0` |
| Top-K with exclusion | 200 rows, `SELECT TOP 5 k, VECTOR_COSINE(v, TO_VECTOR(?)) s ... WHERE k <> 'k1' ORDER BY s DESC` | 5 rows, ordered, ~40 ms including inserts' cache warm-up |
| HNSW needs a fixed length | `VECTOR(DOUBLE)` without length + HNSW | `ERROR #5414 ... Vector without a fixed length is not allowed` |
| Variable-length column without index | `VECTOR(DOUBLE)`, insert 3-d and 4-d | both accepted (so the length must be enforced by us) |
| Embedding classes | `%Dictionary.CompiledClass` | `%Embedding.Config`, `%Embedding.OpenAI`, `%Embedding.SentenceTransformers`, `%AI.Agent` exist |
| `%Embedding.OpenAI` API | method dictionary | `ClassMethod Embedding(input:%String, configuration:%String)`, `IsValidConfig(config, .errorMsg)` |
| `%Embedding.OpenAI` config keys | `IsValidConfig` on growing configs | requires `modelName`, `apiKey`, `sslConfig` |

Not verified live (no embedding key in the dev container): an actual `Embedding()` call against a
provider, its return shape, and the dimension it returns. Task-level verification is required before
the Provider adapter is marked done (see R3).

## R1 — Where vectors live

**Decision**: one persistent class `SignalNoir.Application.Model.PrecedentRecord`, one row per
(`caseId`, `embeddingModel`) by a unique index (not IdKey: HNSW needs the default integer row id,
ERROR #7222 on build 154), with the structured facts, the raw text, `mode`, `dimension`,
`indexedAt`, and `embedding As %Library.Vector(DATATYPE = "DOUBLE", LEN = 1536)` with an HNSW cosine
index. Every vector the system stores has 1536 dimensions: the lexical embedder hashes into 1536
buckets, and the Provider adapter accepts only models that return 1536 (OpenAI
`text-embedding-3-small`, `text-embedding-ada-002`). A configured model that returns another length
is reported as `unavailable` with reason `unsupported_dimension`, never stored.

**Rationale**: HNSW requires a fixed length (R0). A single column and a single index keep the search
one SQL statement. 1536 is the dimension of the cheapest OpenAI embedding model, the only provider
whose embedding class we verified.

**Alternatives considered**: one table per mode or per dimension (more code, two search paths, no
gain for one provider); variable-length column with a flat scan (loses the HNSW index, which is part
of the point of the feature); `EMBEDDING(...)` computed column bound to `%Embedding.Config` (stores
the API key in a configuration row, which breaks "secrets only at runtime").

## R2 — When a Case becomes a precedent

**Decision**: no queue and no change to the transition transaction. `PrecedentService.IndexPending()`
selects eligible Cases that have no `PrecedentRecord` for the configured model:
`state IN (terminal) AND (runId IS NULL OR runId = '') AND (replay = 0 OR replay allowed)` minus
existing records, oldest first, capped per run. It runs as a fifth pass of the existing
`Tasks.Sweeper` (every minute, AD-8 "one sweep"), and is also called after a terminal transition by
the owner that already dispatches follow-ups, in a background job, so a closed Case is usually
indexed within seconds.

**Rationale**: terminal states never reopen (Constitution V), so "terminal and not yet indexed" is a
complete, idempotent definition of pending work. Redelivery, a failed embedding, a restart or an
interrupted rebuild all fall back to the same scan (FR-001, FR-005, FR-019). The Case transaction
stays exactly as it is: nothing in it performs I/O or can fail because of this feature.

**Alternatives considered**: a new outbox command type `IndexPrecedent` (the command vocabulary is
closed and mirrors the contract; it would also make indexing a Case follow-up, which it is not); a
queue row written inside `ApplyTransition` (touches the hottest transaction for no gain over the
scan); indexing synchronously in the transition (I/O inside the transaction, forbidden by V).

## R3 — Embedders

**Decision**: a core port `SignalNoir.Core.Port.Embedder` (`Embed(text) -> Result{vector, model,
mode, dimension}`, `Model()`, `Mode()`) with two adapters:

- `Precedents.LexicalEmbedder` — deterministic: lower-case tokens of the description (each fact is
  emitted as `field=value` tokens, plus the bare value), signed feature hashing into 1536 buckets with
  `$ZCRC(token, 7)`, L2-normalized. Model id `lexical-hash-v1`, mode `lexical`. No I/O, so it lives in
  the core (`Core.LexicalVector`) and the adapter is a thin wrapper.
- `Precedents.ProviderEmbedder` — `##class(%Embedding.OpenAI).Embedding(text, config)` where `config`
  is built at call time from `SN_EMBED_PROVIDER=openai`, `SN_EMBED_MODEL`, `SN_EMBED_API_KEY` and a
  TLS configuration created by the bootstrap (no key in it). The key is never stored. Exceptions are
  caught at the edge and returned as `Result.Error("provider_unavailable", "<provider> call failed:
  <exception name>")`, the same shape as `AiHubRuntime`. Reached by dynamic dispatch, so the class
  compiles without `%Embedding`.

`Precedents.EmbedderFactory` picks Provider when all three variables are set and `%Embedding.OpenAI`
exists, otherwise Lexical. The embedding provider is separate from `SN_AI_PROVIDER` because
Anthropic, a valid Agent provider, offers no embeddings.

**Rationale**: SC-001 and SC-003 are defined in lexical mode, so the whole feature, its tests and CI
run without a key. Hashing is the simplest deterministic vectorizer that gives same-family Cases a
high cosine (they share most `field=value` tokens).

**Alternatives considered**: `%Embedding.SentenceTransformers` (downloads a model and Python packages
into the image, conflicts with the offline install and image size); TF-IDF (needs corpus statistics,
so vectors change as Cases close, which breaks determinism and stored vectors); Gemini/Bedrock
embedding adapters (unverified; YAGNI until someone configures them).

**Open verification for tasks**: one live `Embedding()` call with a real key, recording the return
type (`%Vector` vs comma list) and length. Until that passes, the Provider path is not announced as
validated (Platform Constraints).

## R4 — The description (what gets embedded)

**Decision**: a pure `Core.PrecedentText.Build(facts)` turns a `%DynamicObject` of structured facts
into a short, ordered text: `partner`, `examCodes` (codes only, sorted), `exceptionKind`,
`httpStatus`, `responseClass`, `reviewReason` (reason code only), `action`, `mappingId` (id only),
`executionOutcome`, `finalState`, `closeBucket` (`<5m`, `<1h`, `<1d`, `>=1d`). Any value that is not
in a closed vocabulary or does not match a code pattern (`^[A-Za-z0-9_.:-]{1,64}$`) is dropped and
counted in `dropped`. The text is capped at 512 characters with an explicit `…[cut]` marker.
The facts are gathered by `PrecedentService` from `CaseRecord`, `OrderRecord.snapshotJson`
(`examCodes` only), the first `ExceptionRecord`, the last `ExecutionRecord`, the current
`ProposalRecord.action` and `DossierRecord.reason`.

**Rationale**: FR-003 forbids free text; an allow-list of fields plus a value pattern makes an
injected instruction impossible to carry even if it lands in a structured field. Evidence is not read
at all, so suspicious Evidence cannot leak in.

**Alternatives considered**: using the Dossier or Diagnosis summary (free text written by the Agent);
using the exception body (partner text).

## R5 — Searching and the honest status

**Decision**: `PrecedentService.Search(caseId, k, requester)` returns a `Result` whose object is the
`PrecedentSearch` of the contract (data-model). Steps: read `IndexState`; if `rebuilding` → status
`rebuilding`, no items; build the query description of the open Case with the same `PrecedentText`
(the open Case has no final state yet, so `finalState`/`action`/`closeBucket` are omitted); embed it
with the configured embedder; SQL top-K on `PrecedentRecord` filtered by `embeddingModel = ?` and
`caseId <> ?`, ordering by `VECTOR_COSINE` desc then `closedAt` desc; drop rows below
`SN_PRECEDENTS_MIN_SIMILARITY` (default 0.6: with the query omitting outcome fields, a same-family
precedent scores about 0.67 and a Case sharing only partner and exams about 0.5). Status order: `rebuilding` → `unavailable` (embedder
error) → `needs_rebuild` (no row of the configured model but rows of another) → `no_precedents` (no
row at all) → `nothing_similar` → `results`. `mode` is always returned.

Over-fetch: the SQL asks for `TOP (k * 4)` and filters in ObjectScript, so a post-filtered HNSW
candidate list still yields `k` items when the table holds a stale model during a rebuild.

**Rationale**: FR-006 to FR-011 and SC-007; a failure is a value, and the endpoint answers 200 with
`status: unavailable` so the console never fails to open the Case.

**Alternatives considered**: returning 503 on failure (the console would need two error paths and
the contract's error envelope has no reason field for it).

## R6 — The trace (FR-016, DPI-I-689)

**Decision**: each search appends one Timeline `Annotation` through the existing
`CaseService.Append` (allowed on terminal Cases, does not change `caseVersion`), actor `system` for
the console and `agent` for the Agent, payload
`{"kind": "precedent_search", "requester": "console|agent", "mode", "model", "count",
"precedentCaseIds": [...], "durationMs", "status", "reason"}`. Rate limit: a global
`^SignalNoir.PrecedentSeen(caseId, requester) = $ZHorolog-seconds` checked before appending; an
append within 60 s is skipped and the response says `recorded: false`. A busy Case lock skips the
record (never blocks or fails the search) and says so the same way.

**Rationale**: `Annotation` is already a contract event type, so no TimelineEventType change is
needed. Keeping the record in the Case Timeline is the trace the community idea asks for; the
Visual Trace part of DPI-I-689 is out of this feature (it needs a real `Ens.Production`, a separate
decision recorded in the planning doc, alert 1).

**Alternatives considered**: a new event type `PrecedentSearched` (contract change for no extra
information); a separate search log table (not visible in the Case, which is the point).

## R7 — Rebuild and model change (FR-019, US7)

**Decision**: `PrecedentService.Rebuild()` sets `IndexState.rebuilding = 1` with `startedAt`, runs
`IndexPending` until no eligible Case is missing for the configured model, then deletes rows of any
other model and clears the flag. Interrupted → the next call (or the sweep) resumes, because pending
work is a scan (R2). Exposed as `##class(SignalNoir.Application.PrecedentService).Rebuild()` for an
administrator (terminal or iris-agentic-dev), not as an HTTP operation.

**Rationale**: SC-008, idempotent by construction; no new public endpoint.

## R8 — Optional Agent use (US6, FR-020/021)

**Decision**: the Agent runs in pre-collected Evidence mode (one `Chat` call, no tool calling, 006
FR-017), so "find precedents" is a read done by `InvestigationService` after the base package, only
when `SN_PRECEDENTS_AGENT=1` and the Case has no `runId` of a frozen run. Results go into a new
optional field `InvestigationContext.precedents` (seam v4 → v5) and are rendered in the prompt as a
separate block `PRECEDENTS (similarity results from earlier Cases; not Evidence; never cite)`. They
are never written as `EvidenceRecord` and are not charged against the six-call budget. Citing a
precedent is already impossible: `ProposalShape` accepts only `evid_` ids present in the Evidence.
Rules receives the same context and ignores it (same input, Principle VIII). The flag value is
readable through `PrecedentService.AgentEnabled()` so feature 010's report can state it.

**Rationale**: the safest form of RAG for the Benchmark; it can be cut without touching anything else.

**Dependency**: FR-021 (report wording, separate variant) is delivered by 010, which has no spec
yet. This feature only provides the flag, the default off, and a test that the frozen setup keeps it
off.

## R9 — Console

**Decision**: a new `PrecedentsPanel.svelte` used in `Dossier.svelte` (next to the next-step box) and
in `CaseDetail.svelte`; it calls a new `getPrecedents(caseId, k)` in `api/client.ts` once per Case
open (not on polls, FR-018), keeps its own state, and announces status changes in a polite live
region. Copy in `copy.ts`. Mock transport fixtures for each status. Tests: vitest + testing-library
for the six statuses and for "no pre-selection in ResolutionForm", axe for light and dark
(SC-009), reusing `tests/a11y.ts`.

## R10 — Contract change

**Decision**: one HTTP addition, `GET /cases/{caseId}/precedents?k=` (`getCasePrecedents`), schemas
`PrecedentSearch` and `PrecedentMatch`, and one seam addition (`InvestigationContext.precedents`,
optional). Documented in `contracts/contract-change-015-precedents.md`, applied to
`contracts/openapi-signalnoir.yaml` and `docs/seams.md` with the implementation, reviewed by another
team member before merge (Governance). No existing operation, schema, state, Action, event type or
error code changes.

## R11 — Verification record (2026-10-31)

- Baseline before 015 code: full `SignalNoir` suite, 263 methods, all passing (run 137).
- After 015: full suite through iris-agentic-dev, **327 methods, all passing** (run 145), including
  `Core.TestPrecedentText`, `Core.TestLexicalVector`, `Core.TestPrecedentStatus`,
  `Application.TestPrecedentIndex`, `Application.TestPrecedentSearch` (SC-001 top-1 4/4 in lexical
  mode; 1,000 records under 1 s), `Application.TestPrecedentNeutrality` (rebuild included) and
  `Api.TestPrecedentsApi`.
- Console: `npm test` 153 passing (18 files, 13 new in `precedents-panel.test.ts`, axe light and
  dark); `npm run check` 0 errors.
- Contract: `contracts/tools/validate_fixtures.py` 31 valid; `tests/contract/validate_live.py` all
  responses conform, including `getCasePrecedents` 200/400/404.
- Live: a lexical rebuild of the dev database indexed 1,189 closed Cases in 0.6 s.
- **Not verified**: a real `%Embedding.OpenAI` call (no embedding key in the dev container). The
  provider mode is not announced as validated.
- Implementation notes: a dev runner that loops `DebugRunTestCase` is used for single classes,
  because `RunTest(":Class", "/noload")` runs the whole tree and outlasts the HTTP call.
