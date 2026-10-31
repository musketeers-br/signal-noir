# Seam Contract — Signal Noir internal ports (feature 001)

**Status**: agreed draft for this feature. The published copy is `docs/seams.md`; this file is the
spec-side source and the two MUST NOT diverge (a divergence is a contract change).

**Version**: v5 (2026-10-31) — optional `InvestigationContext.precedents` and the new `Embedder`
port added by contract change 015
(`specs/015-case-precedents/contracts/contract-change-015-precedents.md`).
v4 (2026-10-25) — Proposer port, Evidence and Proposal DTOs, the new
`InvestigationContext` DTO and Order `scenarioInstanceId` changed by contract change 006
(`specs/006-investigation-and-proposal/contracts/contract-change-006-investigation-seam.md`).
v3 (2026-10-25) — CaseCommands, CaseQueries, DTOs, Result, id prefixes and Timeline
event types changed by contract change 003
(`specs/003-order-case-lifecycle/contracts/contract-change-003-case-lifecycle-seam.md`).
v2 (2026-10-24) changed the Validator section by contract change 004
(`specs/004-validation-and-reference-data/contracts/contract-change-004-validator-seam.md`).

**Scope**: the internal boundary that lets the next features compile and test without editing this
feature. It is an internal contract, not the product HTTP API. The product HTTP API stays
`contracts/openapi-signalnoir.yaml`.

## Conventions

- Terms in English as in the PRD glossary: `Order`, `Case`, `Evidence`, `Proposal`, `Approval`,
  `Execution`, `Receipt`, `Exception`, `BenchmarkRun`.
- IDs are opaque strings with a prefix: `case_`, `prop_`, `appr_`, `exec_`, `evid_`, `cmd_`,
  `run_`, `corr_` (correlation id), `exc_` (exception id). `orderId` is partner-issued; `receiptId`
  is partner-issued.
- Actors: `system`, `agent`, `rules`, `replay`, `benchmark`, `sweeper`, `operator:<name>` (the
  HTTP contract's `Actor`).
- Timestamps are ISO-8601 UTC with `Z`.
- Failures are returned as values, never raised across the seam: a method returns a
  `%Status`-like result object carrying either the value or an error from the closed vocabulary.

## Error envelope

```json
{ "error": { "code": "<closed code>", "message": "<human text>", "details": {} } }
```

`code` MUST come from the closed vocabulary of `contracts/openapi-signalnoir.yaml`. The seam MUST
NOT invent new codes.

## Timeline event

```json
{ "seq": 12, "at": "2026-10-22T18:00:00Z", "type": "CaseOpened",
  "actor": "system", "refId": "case_000123", "payload": {} }
```

`seq` is monotonic per Case, never reused and without gaps; a reader never sees an event before every
lower `seq` of the same Case is committed. `type` is one of the HTTP contract's closed
`TimelineEventType`. Transitions write `StateChanged` with `{from, to, reason, caseVersionAfter}`;
opening writes `CaseOpened` (`previousCaseId` for a new episode); an Exception writes
`ExceptionRecorded`. `payload` carries facts only, never secrets.

## DTOs

| DTO | Required fields in this slice |
|-----|-------------------------------|
| `Order` | `orderId`, `snapshot`, `equivalenceKey`, `receivedAt`, `synthetic`, `correlationId`, `transactionId` (input) / `transactionIds` (output), `partnerId`, `runId`, `scenarioInstanceId` |
| `CaseException` | `exceptionId`, `kind` (`timeout` / `http_error` / `invalid_receipt` / `business_rejection` / `processing_error`), `httpStatus?`, `body?`, `responseClass?`, `observedAt`, `attemptId?`, `duringExecution` |
| `Case` | `caseId`, `orderId`, `state`, `caseVersion`, `lastEventSeq`, `lastEventAt`, `synthetic`, `replay`, `reviewReason?`, `denialCount`, `previousCaseId?`, `currentProposalId?`, `currentApprovalId?`, `currentExecutionId?`, `executionOutcome?`, `updatedAt` |
| `CaseSummary` | `caseId`, `orderId`, `partnerId`, `state`, `caseVersion`, `lastEventSeq`, `lastEventAt`, `createdAt`, `synthetic`, `replay`, `exceptionCount`, `lastExceptionSummary?`, `executionOutcome?` |
| `TimelineEvent` | `seq`, `at`, `type`, `actor`, `refId`, `payload` |
| `Evidence` | `evidenceId`, `caseId`, `investigationId`, `kind` (`fact` / `absence`), `source` (contract enum), `calledBy`, `params`, `result` (raw, by value; `payload` is a v3 alias), `observedAt`, `durationMs`, `suspicious`, `suspiciousExcerpts[]`, `obsoletedBy?` |
| `Proposal` | `proposalId`, `caseId`, `origin` (= contract `author`), `createdAt`, `current`, `supersededBy?`, `diagnosis` (`summary`, `claims[]` with `evidenceIds[]`, `hypotheses[]`, `conflicts[]`), `action`, `params`, `scope`, `confidence` (`HIGH`/`MEDIUM`/`LOW`), `preconditions[]` (`check`, `expected`), `versions` (`policy`, `mapping`, `prompt`, `model`, `provider`), `metrics`, `priorReceiptCandidate?` |
| `InvestigationContext` | `investigationId`, `case`, `order`, `evidence[]`, `tools` (the read-only gateway), `maxToolCalls`, `budgetMs`, `startedAt`, `precedents` (v5, optional: similar closed Cases as `PrecedentMatch` objects; absent unless `SN_PRECEDENTS_AGENT=1`; never Evidence, never citable) |
| `ValidatorVerdict` | `verdict` (`accepted` / `blocked` / `review` / `prior_receipt_confirmed`), `reasons` (ordered closed codes), `requiresApproval`, `versions` (`policy`, `mapping`), `at` |
| `ValidationInput` | `proposal`, `evidence[]`, `order` (snapshot), `priorReceiptOrder?`, `attemptCount`, `run` (`inRun`, `runId`, `policyVersion`, `mappingVersion`), `reference` (snapshot), `observed?` (Revalidation only), `now` |
| `PreconditionResult` | `check`, `expected`, `observed`, `passed`, `evidenceId?` |
| `Admission` | `admissible`, `label` (`human` / `automatic`), `reason?` |
| `Approval` | `approvalId`, `proposalId`, `decidedBy`, `decidedAt`, `deadline`, `immutableProposalRef` |
| `Execution` | `executionId`, `caseId`, `proposalId`, `idempotencyKey`, `leaseOwner`, `leaseGeneration`, `state` |
| `Receipt` | `receiptId`, `orderId`, `outcome`, `receivedAt`, `raw` |
| `Dossier` | `caseId`, `facts`, `diagnosis`, `missingInformation`, `options` |

`Order`, `CaseException`, `Case`, `CaseSummary` and `TimelineEvent` are produced by 001/003;
`Evidence`, `Proposal` and `InvestigationContext` by 006; the rest are declared so the seam does not
change shape when later slices fill them in.

`Result` carries `ok`, `code`, `message`, `ref`, `obj`, `list` and `details`. A `STALE_VERSION` or
`INVALID_TRANSITION` result carries `details` with `caseVersion`, `lastEventSeq`, `state`,
`currentProposalId`, `serverTime` (and `expectedCaseVersion` for a stale version); a refused Order
carries `details.reasons`.

## Ports

Each port is an abstract class in `SignalNoir.Core.Port`. Signatures are shown in a
language-neutral form; the ObjectScript realization is the Plan's.

### CaseCommands (mutation — the only write path)

```
AcceptOrder(order: Order) -> Result<OrderRef>          # stores/correlates; opens no Case
RecordException(orderId, exception: CaseException) -> Result<CaseRef>
OpenCase(orderId) -> Result<CaseRef>                    # the non-terminal Case; never creates one
Transition(caseId, expectedVersion, toState, actor, event,
           expectedState = "", expectedTarget = "") -> Result<CaseRef>
MarkReviewRequired(caseId, expectedVersion, actor, reason) -> Result<CaseRef>
ResolveRejection(caseId, expectedVersion, reason) -> Result<CaseRef>
Append(caseId, event) -> Result<TimelineEvent>          # attachment; does not bump caseVersion
```

Rules: a malformed Order is refused with `VALIDATION_FAILED` and recorded, and opens nothing. The
first Exception of an Order opens its Case; a later one joins the non-terminal Case (and moves it
to `Investigating` from `Open`, `DecisionProposed`, `PendingApproval`, `Rejected`, `Held`,
`ReviewRequired`); after a terminal Case it opens a related Case. Transitions follow the core table
(`SignalNoir.Core.CaseMachine`, spec 003 FR-015) and use compare-and-swap on `caseVersion` and,
when given, on the expected state and target (`currentProposalId` or `currentExecutionId`); a
losing writer gets `STALE_VERSION` and nothing is written. State, event and outbox entry commit
together. `caseVersion` changes only on transitions.

### CaseQueries (read)

```
GetCase(caseId) -> Result<Case>                          # with order and exceptions
GetTimeline(caseId, sinceSeq = 0, limit = 200) -> Result<[TimelineEvent]>   # details: hasMore, nextSinceSeq
ListCases(cursor = "", direction = "older", limit = 50, filters = {}) -> Result<[CaseSummary]>
                                                         # details: nextCursor, headCursor
```

`filters`: `state[]`, `status` (`open` / `terminal` / `all`), `pendingApproval`, `runId`,
`includeBenchmark`. The cursor is opaque over `(lastEventAt, caseId)`.

### Validator

```
Validate(input: ValidationInput) -> ValidatorVerdict
Revalidate(input: ValidationInput) -> ValidatorVerdict + [PreconditionResult]
Admit(actor, run) -> Admission
```

Deterministic, origin-blind, no I/O: every input arrives in `ValidationInput`, including `now` and
the reference-data snapshot. Ambiguous identity is not an input: the Validator derives it from
`evidence` and `order` with `SignalNoir.Core.Identity` (contract change 004, revision 2026-10-26).
Reason codes come from the closed list in
`specs/004-validation-and-reference-data/contracts/reason-codes.md`; the input shape and the Evidence
convention are in `specs/004-validation-and-reference-data/contracts/validation-input.md`.

### Proposer

```
Propose(context: InvestigationContext) -> Result<ProposerAnswer>
```

`Result.obj` is the proposer's raw answer (data, the contract Proposal shape without ids);
`SignalNoir.Core.ProposalShape` converts it into the `Proposal` DTO the same way for every origin.
`Result.details` carries `provider`, `model`, `promptVersion`, `tokensIn`, `tokensOut`,
`estCostUsd` when known. Failures are values (`provider_unavailable`, `invalid_response`,
`refused`, `budget_exceeded`) that end in `ReviewRequired`. Only `SignalNoir.Proposers.Factory`
reads the proposer mode, before the port. `SignalNoir.Proposers.Unavailable` returns
"provider unavailable" instead of raising.

### Tools

```
Invoke(toolName, args) -> Result<Evidence>
```

Read-only by contract. No write-capable tool may implement this port. The runtime implementation
(`SignalNoir.Application.ToolGateway`, feature 006) accepts only the reading Tools of the contract's
Evidence `source` enum, charges the server-side budget (6 calls / 20 s), and returns Evidence that
is already recorded on the Case.

### Embedder (v5, feature 015)

```
Embed(text) -> Result<vector>
Model() -> String
Mode() -> lexical | provider
```

`Result.ref` is the vector as a comma list of 1536 numbers; `Result.details`: `model`, `mode`,
`dimension`. Failures are values: `provider_unavailable`, `unsupported_dimension`. The lexical
adapter (`SignalNoir.Precedents.LexicalEmbedder`) needs no key and is never presented as semantic;
the provider adapter reads its key from the runtime environment at call time.

### PartnerClient

```
Send(orderId, action, params, idempotencyKey) -> Result<Receipt>
FetchReceipts(orderId) -> Result<[Receipt]>
```

Not called in this slice.

### Clock

```
NowUtc() -> Timestamp
```

### IdGenerator

```
New(prefix) -> Id
```

`prefix` MUST be one of the agreed prefixes; the adapter rejects any other.

## Test doubles

A fake MUST exist for every port, under `tests/SignalNoir/Tests/Fakes`, and MUST be usable without
a live provider:

| Fake | Behaviour |
|------|-----------|
| `FakeCaseCommands` | in-memory command handling with version checks; acceptance opens no Case, `RecordException` does |
| `FakeCaseQueries` | in-memory reads |
| `FakeValidator` | configurable `ValidatorVerdict` (default `accepted`, `requiresApproval = true`, reasons `[ACTION_IN_CATALOG]`), `PreconditionResult[]` and `Admission` |
| `FakeProposer` | configurable answer or provider-unavailable result |
| `FakeTools` | returns a canned Evidence (contract fields) |
| `FakePartnerClient` | returns a canned Receipt |
| `FixedClock` | a fixed, settable time |
| `SeqIdGenerator` | deterministic prefixed ids |

The fakes are test-only and MUST NOT be part of the runtime resource
(`module.xml` runtime `Resource` excludes `tests/`).

## Consumer guarantee

A consumer that imports only this seam and the fakes can compile and run its tests with **no
edits** to this feature's files. Breaking that guarantee requires a contract change.
