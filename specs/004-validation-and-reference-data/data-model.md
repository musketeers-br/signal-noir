# Data Model: Validator and Versioned Reference Data

The Validator itself is stateless. It reads immutable DTOs and returns DTOs. The only persisted
state of this feature is the reference-data pointer and the `ValidatorVerdict` timeline events
(through the existing Case command path).

## Core DTOs (no persistence)

| DTO | Fields | Rules |
|-----|--------|-------|
| `Proposal` (extended) | `proposalId`, `caseId`, `origin`, `action`, `params`, `scope`, `confidence`, `preconditions[] {check, expected}`, `versions {policy, mapping}`, `priorReceiptCandidate?` | shapes as in the product contract `Proposal`; `origin` never read by rules |
| `ValidationInput` | see [contracts/validation-input.md](./contracts/validation-input.md) | immutable; all inputs, including `now` and `reference` |
| `ValidatorVerdict` | `verdict`, `reasons[]`, `requiresApproval`, `versions {policy, mapping}`, `at` | `verdict ∈ {accepted, blocked, review, prior_receipt_confirmed}`; reasons from [reason-codes.md](./contracts/reason-codes.md) in pipeline order; `at = input.now` |
| `PreconditionResult` | `check`, `expected`, `observed`, `passed`, `evidenceId?` | `check` ∈ the five `PreconditionCheck` values |
| `Admission` | `admissible`, `label?` (`human`/`automatic`), `reason?` | |
| `ReferenceData` | `policyVersion`, `mappingVersion`, `policies`, `mappings[]`, `synonyms` | immutable snapshot of one policy version + one mapping version |

## Reference data (versioned fixtures)

### Policy Set — `SignalNoir.Application.Reference.Policies.V<version>`

| Field | Example (2026.10.1) | Rule |
|-------|---------------------|------|
| `version` | `2026.10.1` | unique across policy fixtures |
| `attempt.maxAttempts` | 3 | integer ≥ 1 |
| `substitution.enabled` | true | |
| `maintenanceWindows[]` | `[]` | `{partnerId, startsAt, endsAt}` UTC |
| `partnerHealth.windowSeconds` | 300 | > 0 |
| `partnerHealth.maxErrorRate` | 0.2 | 0 ≤ x ≤ 1 |
| `approval.<ACTION>` | `RETRY: true`, `APPLY_APPROVED_MAPPING: true`, `HOLD: false`, `REQUEST_REVIEW: false` | exactly the four Actions; `RETRY` and `APPLY_APPROVED_MAPPING` MUST be true (load refused otherwise) |
| `approval.deadlineSeconds` | 900 | > 0 |

### Mapping Set — `SignalNoir.Application.Reference.Mappings.V<version>`

| Field | Rule |
|-------|------|
| `mappingVersion` | unique across mapping fixtures |
| `items[] {mappingId, mappingVersion, sourceCode, targetCode, conditions}` | `ApprovedMapping` of the contract; `mappingId` unique within the version; `conditions` keys ∈ {`specimenType`, `specimenUnit`} |
| `synonyms {field: {canonical: [variants]}}` | variants compared upper-case and trimmed |

Version `2026.10.1` items are exactly those of `contracts/fixtures/reference.mappings.json`.

### Store state

| Key | Meaning |
|-----|---------|
| `^SignalNoir.Reference("inForce","policy")` | policy version in force |
| `^SignalNoir.Reference("inForce","mapping")` | mapping version in force |

Unset → the highest valid version of each is loaded on first use. A refused load (FR-024) leaves the
keys unchanged.

## Action catalog (compiled in the Core)

| Action | externalEffect | requiresApproval (policy) | params | requiredEvidence |
|--------|----------------|---------------------------|--------|------------------|
| `RETRY` | true | true | none | `tool.policies:attempt`, `tool.partner_failure_history`, `tool.partner_health` |
| `APPLY_APPROVED_MAPPING` | true | true | `mappingId`, `mappingVersion` | `tool.policies:substitution`, `tool.mapping_catalog`, `tool.order_timeline:<condition field>` |
| `HOLD` | false | false | `reason?` | `tool.partner_health` or `tool.policies:maintenance` |
| `REQUEST_REVIEW` | false | false | `reason?` | none |

Served by `GET /reference/action-catalog` as `ActionCatalogEntry` (`paramsSchema` is the JSON Schema of
the params above).

## Timeline event (via `CaseCommands.Append`)

| Field | Value |
|-------|-------|
| `type` | `ValidatorVerdict` |
| `actor` | the Proposal's origin actor (`agent`, `rules`, `operator:<name>`, `benchmark`) or `system` for Revalidation |
| `refId` | `proposalId` |
| `payload` | `{proposalId, verdict, reasons, requiresApproval, versions, preconditionResults?}` — facts only |

## Verdict decision (state)

```text
pipeline steps 1–4 fail  → blocked (stop)
any block code (5–8)     → blocked
else any review code     → review
else step 12 passed      → prior_receipt_confirmed
else                     → accepted
```
