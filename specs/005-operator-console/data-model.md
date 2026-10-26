# Data Model: Operator Console

The console owns no domain data. It renders contract payloads and keeps a small client state.

## Server data (contract `openapi-signalnoir.yaml`)

| Payload | Used by |
|---|---|
| `CaseListPage` / `CaseSummary` | list rows, filters, cursors (`nextCursor`, `headCursor`) |
| `CaseDetail` (+ `Evidence`, `Diagnosis`, `Proposal`, `Approval`, `Execution`, `ReceiptCopy`, `Dossier`, `CaseMetrics`) | detail layers, banner, dossier |
| `TimelinePage` | timeline (`sinceSeq`, `nextSinceSeq`, `hasMore`) |
| `ProposalDecisionResult` | approval outcome (`idempotentReplay`) |
| `ReviewResolutionResult` | resolution outcome |
| `ErrorEnvelope` | every refusal (`code`, `details`) |
| action catalog, `ApprovedMapping` list | resolution form options |

## Client state

| State | Where | Lifetime |
|---|---|---|
| operator name | `localStorage["signalnoir.operator"]` | browser |
| list filter | URL hash query (`#/cases?f=needs-you`) | navigation |
| list rows, cursors, `stale` | `cases` store | session |
| open Case detail, timeline events, `lastEventSeq`, `stale` | `caseDetail` store | while open |
| dialog: frozen `proposalId`, `caseVersion`, decision, reason, in-flight, outcome | `ApprovalDialog` local | while open |
| resolution form values, outcome | `ResolutionForm` local | while mounted |
| expanded sections | component local, keyed by id | while mounted |
| toasts | `toasts` store | ~6 s each |

## Outcome (closed union, `outcome.ts`)

`created` (201) · `replay` (200 + `idempotentReplay`) · `stale` (409 `STALE_VERSION`) ·
`invalidTransition` (409 `INVALID_TRANSITION`) · `invalidActor` (403) · `badRequest` (400) ·
`blocked` (422, `details.verdict.reasons`) · `notFound` (404) · `network` (no answer) ·
`server` (5xx or unknown).
