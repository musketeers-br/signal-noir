# Data Model: Validator and Versioned Reference Data

The Validator itself is stateless. It reads immutable DTOs and returns DTOs. The only persisted
state of this feature is the reference-data pointer and the `ValidatorVerdict` timeline events
(through the existing Case command path).

## Core DTOs (no persistence)

| DTO | Fields | Rules |
|-----|--------|-------|
| `Proposal` (already on `master`, 006) | `proposalId`, `caseId`, `origin`, `action`, `params`, `scope`, `confidence` (`HIGH`/`MEDIUM`/`LOW`), `preconditions[] {check, expected}`, `versions {policy, mapping, …}`, `priorReceiptCandidate?` | used as is; `origin` never read by rules |
| `Evidence` (already on `master`, 006) | `evidenceId`, `caseId`, `kind` (`fact`/`absence`), `source`, `result`, `suspicious`, `obsoletedBy` | read only; recognition rules in [contracts/validation-input.md](./contracts/validation-input.md) |
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
| `approval.deadlineSeconds` | 900 | > 0 (which Actions need Approval is not policy data: it is the catalog's external-effect rule) |

A fixture with an unknown key or an out-of-range value is refused at load (FR-024).

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

## Action catalog (`SignalNoir.Core.ActionCatalog`, already on `master`; 004 fills `requiredEvidence`)

| Action | externalEffect | requiresApproval (= externalEffect) | params | requiredEvidence (entries of `ActionCatalogEntry.requiredEvidence`) |
|--------|----------------|-------------------------------------|--------|------------------|
| `RETRY` | true | true | none | `tool.policies#attempt`, `tool.partner_failure_history`, `tool.partner_health` |
| `APPLY_APPROVED_MAPPING` | true | true | `mappingId`, `mappingVersion` | `tool.policies#substitution`, `tool.mapping_catalog`, `order#<condition field>` |
| `HOLD` | false | false | `reason?` | `tool.partner_health` or `tool.policies#maintenanceWindows` |
| `REQUEST_REVIEW` | false | false | `reason?` | none |

`#key` names the key of `Evidence.result` that must be defined; `order#field` names an Order path.
On `master`, `RequiresApproval("REQUEST_REVIEW")` is true; it becomes false (coordination item 3).
Served by `GET /reference/action-catalog` as `ActionCatalogEntry`.

## Timeline event (written today by `CaseService`; 004 adds `versions`)

| Field | Value |
|-------|-------|
| `type` | `ValidatorVerdict` |
| `actor` | `system` (investigation path) or the operator actor (resolution path), as `CaseService` writes it today |
| `refId` | `proposalId` (investigation path) or `caseId` (resolution path), as today |
| `payload` | `{proposalId` (investigation path) or `proposalAuthor` (resolution path)`, action, verdict, reasons, requiresApproval, versions}` — facts only; `versions` is the 004 addition |

The verdict is also stored on the Proposal (`ProposalRecord.verdictJson`). Revalidation is recorded by
008 as `RevalidationPerformed` with the `PreconditionResult[]`, not here.

## Verdict decision (state)

```text
pipeline steps 1–4 fail  → blocked (stop)
any block code (5–8)     → blocked
else any review code     → review
else step 12 passed      → prior_receipt_confirmed
else                     → accepted
```
