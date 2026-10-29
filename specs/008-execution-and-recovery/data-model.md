# Data Model: Safe Execution and Recovery

## ExecutionRecord (new, `Application.Model.ExecutionRecord`)

Contract shape: `Execution` (`openapi-signalnoir.yaml`).

| Field | Notes |
|---|---|
| `executionId` | `exec_…`, IdKey |
| `caseId`, `orderId`, `partnerId` | indexed on `caseId` and `(orderId, outcome)` |
| `proposalId`, `approvalId` | `approvalId` is empty for `HOLD` |
| `action` | from the Proposal |
| `idempotencyKey` | the effect key (`Core.EffectKey`) |
| `payloadJson` | the canonical payload that is sent (snapshot or mapped Order) |
| `mappingRefJson` | `{mappingId, mappingVersion}` for `APPLY_APPROVED_MAPPING`, else empty |
| `scenarioInstanceId`, `runId` | taken from the Order, sent with every attempt |
| `authorizedAt`, `completedAt` | |
| `leaseOwner`, `leaseGeneration`, `stepLeaseUntil` | generation starts at 1 and goes +1 on each take-over |
| `revalidationJson` | `{passed, checks[], at, resultingState}` |
| `attemptsJson` | `[Attempt]` |
| `reconciliationsJson` | `[Reconciliation]` |
| `outcome` | `in_progress`, `reconciling`, `resolved`, `held`, `cancelled`, `failed` |
| `failureReason` | text for `failed` / `held` |

Outcome transitions:
- `in_progress` → `resolved` | `failed` | `reconciling`
- `reconciling` → `resolved` | `in_progress` (not found, resend) | `failed`
- `held` and `cancelled` are set at authorization.

## ReceiptCopyRecord (new, `Application.Model.ReceiptCopyRecord`)

Contract shape: `ReceiptCopy`.

| Field | Notes |
|---|---|
| `receiptId` | from the Partner, IdKey with `caseId` |
| `caseId`, `executionId` | |
| `orderId`, `idempotencyKey`, `receivedAt`, `partnerId` | |
| `source` | `delivery` or `reconciliation` |
| `externalRef` | the Simulator's canonical URL |
| `orderSnapshotMinimalJson` | `{orderId, exams}` from the Receipt record when present |

## CaseRecord (existing)

- `currentExecutionId`: the latest Execution.
- `executionOutcome`: its outcome, shown in the Case header and summary.

## ApprovalRecord (existing)

- `status = consumed` at authorization. This includes held and cancelled authorizations: the
  approval was spent on that execution and can authorize nothing else.

## OutboxRecord (existing)

- **`Execute`**: written by `PendingApproval → Approved`, by `DecisionProposed → Executing`, or by
  009's resolution. Payload `{}`.
- **`Reconcile`**: written in the uncertain-answer commit, by the sweeper's lease pass, or by a
  refused late write. Payload `{executionId, trigger}`. `caseVersionAfter` is the current version,
  since no transition happens.

## Timeline events (contract `TimelineEventType`)

| Event | Payload |
|---|---|
| `RevalidationPerformed` | `{executionId?, passed, checks, resultingState}` |
| `ExecutionAuthorized` | `{executionId, proposalId, approvalId, action, idempotencyKey, leaseGeneration}` |
| `AttemptRecorded` | `{executionId, n, transactionId, httpStatus, responseClass, receiptId}` |
| `ReconciliationPerformed` | `{executionId, trigger, queriedBy, found, receiptId}` |
| `ReceiptRecorded` | `{executionId, receiptId, source}` |
| `ReassessmentPerformed` | `{from: "Held", observed}` |
| `CommandDiscarded` | `{executionId, generation, reason}` |
| `StateChanged` | as usual |
| `Annotation` | sweeper: lease expired, reconciliation requested |

## Ports

- **`Core.Port.PartnerClient`**: the existing `Send` and `FetchReceipts` stay for the seam, and four
  methods are added:
  - `Deliver(partnerId, request)` → `{answered, status, text, json, replayed, error}`;
  - `SearchReceipts(query)` → `Result<obj {items}>`;
  - `Health(partnerId, sci)` → `Result<obj>`;
  - `OriginStatus(orderId)` → `Result<obj>`.
- **`Core.Port.ExecutionPolicy`**:
  - `Revalidate(input)` → `{passed, checks[], destination, reason}`;
  - `MaxAttempts()`;
  - `MinHoldSeconds()`;
  - `LeaseSeconds()`;
  - `CurrentVersions()` → `{policy, mapping}`, empty when not loaded;
  - `EffectPayload(action, params, snapshot)` → `Result<obj>`.
