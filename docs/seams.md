# Seam Contract — Signal Noir internal ports (feature 001)

**Status**: agreed draft for this feature. The published copy is `docs/seams.md`; this file is the
spec-side source and the two MUST NOT diverge (a divergence is a contract change).

**Version**: v2 (2026-10-24) — Validator section changed by contract change 004
(`specs/004-validation-and-reference-data/contracts/contract-change-004-validator-seam.md`). Every
other section is unchanged from v1.

**Scope**: the internal boundary that lets the next features compile and test without editing this
feature. It is an internal contract, not the product HTTP API. The product HTTP API stays
`contracts/openapi-signalnoir.yaml`.

## Conventions

- Terms in English as in the PRD glossary: `Order`, `Case`, `Evidence`, `Proposal`, `Approval`,
  `Execution`, `Receipt`, `Exception`, `BenchmarkRun`.
- IDs are opaque strings with a prefix: `case_`, `prop_`, `appr_`, `exec_`, `evid_`, `cmd_`,
  `run_`. `orderId` is partner-issued; `receiptId` is partner-issued.
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

`seq` is monotonic per Case and never reused. `payload` carries facts only, never secrets.

## DTOs

| DTO | Required fields in this slice |
|-----|-------------------------------|
| `Order` | `orderId`, `snapshot`, `equivalenceKey`, `receivedAt`, `synthetic` |
| `Case` | `caseId`, `orderId`, `state`, `caseVersion`, `lastEventSeq`, `lastEventAt`, `synthetic`, `replay`, `reviewReason?` |
| `CaseSummary` | `caseId`, `state`, `caseVersion`, `lastEventAt`, `synthetic` |
| `TimelineEvent` | `seq`, `at`, `type`, `actor`, `refId`, `payload` |
| `Evidence` | `evidenceId`, `caseId`, `kind`, `source`, `observedAt`, `payload` |
| `Proposal` | `proposalId`, `caseId`, `action`, `params`, `scope`, `confidence`, `preconditions[]` (`check`, `expected`), `versions` (`policy`, `mapping`), `priorReceiptCandidate?`, `origin` |
| `ValidatorVerdict` | `verdict` (`accepted` / `blocked` / `review` / `prior_receipt_confirmed`), `reasons` (ordered closed codes), `requiresApproval`, `versions` (`policy`, `mapping`), `at` |
| `ValidationInput` | `proposal`, `evidence[]`, `order` (snapshot), `priorReceiptOrder?`, `identity` (`clear` / `ambiguous`), `attemptCount`, `run` (`inRun`, `runId`, `policyVersion`, `mappingVersion`), `reference` (snapshot), `observed?` (Revalidation only), `now` |
| `PreconditionResult` | `check`, `expected`, `observed`, `passed`, `evidenceId?` |
| `Admission` | `admissible`, `label` (`human` / `automatic`), `reason?` |
| `Approval` | `approvalId`, `proposalId`, `decidedBy`, `decidedAt`, `deadline`, `immutableProposalRef` |
| `Execution` | `executionId`, `caseId`, `proposalId`, `idempotencyKey`, `leaseOwner`, `leaseGeneration`, `state` |
| `Receipt` | `receiptId`, `orderId`, `outcome`, `receivedAt`, `raw` |
| `Dossier` | `caseId`, `facts`, `diagnosis`, `missingInformation`, `options` |

Only `Order`, `Case`, `CaseSummary` and `TimelineEvent` are produced in this slice; the rest are
declared so the seam does not change shape when later slices fill them in.

## Ports

Each port is an abstract class in `SignalNoir.Core.Port`. Signatures are shown in a
language-neutral form; the ObjectScript realization is the Plan's.

### CaseCommands (mutation — the only write path)

```
AcceptOrder(order: Order) -> Result<CaseRef>
OpenCase(orderId) -> Result<CaseRef>
Transition(caseId, expectedVersion, toState, actor, event) -> Result<CaseRef>
Append(caseId, event) -> Result<TimelineEvent>          # attachment; does not bump caseVersion
```

Rules: transitions use compare-and-swap on `caseVersion`; a losing writer gets a visible conflict
result. State, event and outbox entry commit together.

### CaseQueries (read)

```
GetCase(caseId) -> Result<Case>
GetTimeline(caseId, sinceSeq?) -> Result<[TimelineEvent]>
ListCases(cursor?) -> Result<[CaseSummary]>
```

### Validator

```
Validate(input: ValidationInput) -> ValidatorVerdict
Revalidate(input: ValidationInput) -> ValidatorVerdict + [PreconditionResult]
Admit(actor, run) -> Admission
```

Deterministic, origin-blind, no I/O: every input arrives in `ValidationInput`, including `now` and
the reference-data snapshot. Reason codes come from the closed list in
`specs/004-validation-and-reference-data/contracts/reason-codes.md`; the input shape and the Evidence
convention are in `specs/004-validation-and-reference-data/contracts/validation-input.md`.

### Proposer

```
Propose(case: Case) -> Result<Proposal>
```

`SignalNoir.Proposers.Unavailable` returns a result value meaning "provider unavailable" instead
of raising; that value is what drives `ReviewRequired`.

### Tools

```
Invoke(toolName, args) -> Result<Evidence>
```

Read-only by contract. No write-capable tool may implement this port. Implementation arrives in
later slices.

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
| `FakeCaseCommands` | in-memory command handling with version checks |
| `FakeCaseQueries` | in-memory reads |
| `FakeValidator` | configurable `ValidatorVerdict` (default `accepted`, `requiresApproval = true`, reasons `[ACTION_IN_CATALOG]`), `PreconditionResult[]` and `Admission` |
| `FakeProposer` | configurable proposal or provider-unavailable result |
| `FakeTools` | returns a canned Evidence |
| `FakePartnerClient` | returns a canned Receipt |
| `FixedClock` | a fixed, settable time |
| `SeqIdGenerator` | deterministic prefixed ids |

The fakes are test-only and MUST NOT be part of the runtime resource
(`module.xml` runtime `Resource` excludes `tests/`).

## Consumer guarantee

A consumer that imports only this seam and the fakes can compile and run its tests with **no
edits** to this feature's files. Breaking that guarantee requires a contract change.
