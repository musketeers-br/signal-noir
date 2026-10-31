# Validation Input (internal contract of the Validator port v2)

What a caller passes to `Validate`, `Revalidate` and `Admit`. Field names follow
`contracts/openapi-signalnoir.yaml` and the seam DTOs (`docs/seams.md` v4: `Proposal`, `Evidence`,
`Order`). Revised on 2026-10-26 against `master` (features 003, 006 and 009 merged).

```json
{
  "proposal": {
    "proposalId": "prop_000045",
    "caseId": "case_000123",
    "origin": "agent",
    "action": "APPLY_APPROVED_MAPPING",
    "params": { "mappingId": "map_glicj_plasma", "mappingVersion": "2026.10.1" },
    "scope": "single_case",
    "confidence": "HIGH",
    "preconditions": [
      { "check": "ORDER_ACTIVE_AT_ORIGIN", "expected": true },
      { "check": "MAPPING_VERSION_UNCHANGED", "expected": "2026.10.1" }
    ],
    "versions": { "policy": "2026.10.1", "mapping": "2026.10.1" },
    "priorReceiptCandidate": null
  },
  "evidence": [ "<Evidence DTO as recorded by the Tools gateway>" ],
  "order": { "...": "raw SyntheticOrder snapshot of the Case" },
  "priorReceiptOrder": null,
  "attemptCount": 1,
  "run": { "inRun": false, "runId": null, "policyVersion": null, "mappingVersion": null },
  "reference": "<ReferenceData snapshot for the run, or the one in force>",
  "observed": null,
  "now": "2026-10-29T13:02:11Z"
}
```

`identity` is **not** an input (it was in the first draft of seam v2): the Validator derives it from
`evidence` and `order` with the Core identity rule (`SignalNoir.Core.Identity.Collisions`), the same
rule the Rules proposer and the Dossier use. A caller that could set it could also clear it, which
would give that origin a shortcut (Principle III).

## Who builds it

`SignalNoir.Application.ResolutionValidator` is the single place a Proposal reaches the Validator
(feature 009). It assembles the input from the Case record: `ListEvidence(caseId)`, the Order
snapshot, `runId`, the attempt count (0 until 008 records Attempts), the reference snapshot from the
Store (`Store.For(run)`) and `now`. The two call sites are `CaseService.CompleteInvestigation` and
`CaseService.ResolveReview`.

## Evidence

Evidence is the DTO recorded by the Tools gateway (006): `evidenceId`, `caseId`, `kind`
(`fact` | `absence`), `source`, `result` (raw, by value), `suspicious`, `obsoletedBy`.

Evidence counts toward the minimum only if **all** hold: `caseId` equals the Proposal's; `kind =
fact`; `obsoletedBy` is empty; `suspicious` is false. An `absence` never counts (Principle VII:
absence of information is not a finding).

| Required item | `source` | The `result` must have |
|---|---|---|
| attempt policy | `tool.policies` | `attempt` defined |
| substitution policy | `tool.policies` | `substitution` defined |
| maintenance window | `tool.policies` | `maintenanceWindows` defined |
| attempt history | `tool.partner_failure_history` | (the Simulator's `PartnerHistory`: `window`, `items`) |
| recent partner health | `tool.partner_health` | (the Simulator's `PartnerHealth`: `status`) |
| approved Mapping | `tool.mapping_catalog` | `items[]` containing `mappingId` + `mappingVersion` equal to the Proposal's `params` |
| Order field | — (the Order the Case holds) | the Mapping condition's Order path is present in `order` |

### Results the 004 serves for its two Tools

Served by `SignalNoir.Tools.LocalSource` from the Store (today it answers "reference data not
loaded"); the gateway wraps them as Evidence `result`.

`tool.policies`:

```json
{ "policyVersion": "2026.10.1",
  "attempt": { "maxAttempts": 3 },
  "substitution": { "enabled": true },
  "maintenanceWindows": [],
  "partnerHealth": { "windowSeconds": 300, "maxErrorRate": 0.2 },
  "approval": { "deadlineSeconds": 900 } }
```

`tool.mapping_catalog` (same `items` as `GET /reference/mappings`, plus the synonyms):

```json
{ "mappingVersion": "2026.10.1",
  "items": [ { "mappingId": "map_glicj_plasma", "mappingVersion": "2026.10.1", "sourceCode": "GLIC-J",
               "targetCode": "GLIC-P", "conditions": { "specimenType": "PLASMA" } } ],
  "synonyms": { "specimenType": { "PLASMA": ["PLASMA"], "SERUM": ["SERUM", "SORO"] } } }
```

The Rules proposer (`SignalNoir.Proposers.Rules`) reads `result.items` and compares
`conditions.specimenType` to the Order's `specimen.type` with a plain upper-case equality. With raw
Orders that use the contract's own example values (`soro`, `plasma`) it would miss a Mapping the
Validator accepts. It should
call `Core.Conditions.Matches` with `result.synonyms` instead (see
[coordination-004-006-009.md](./coordination-004-006-009.md)).

## Observed values (Revalidate only)

```json
{
  "partnerHealth": { "status": "UP", "errorRate": 0.0, "evidenceId": "evid_9" },
  "partnerMaintenanceActive": false,
  "originStatus": "active",
  "approval": { "approvalId": "appr_1", "proposalId": "prop_000045", "deadline": "2026-10-29T13:17:11Z" },
  "proposalCurrent": true,
  "policyVersionInForce": "2026.10.1",
  "mappingVersionInForce": "2026.10.1",
  "mappingExists": true
}
```

Producer: 008 (Revalidation), gathering them right before the send. Only these values feed the
precondition step (spec FR-022). Recording a Revalidation (`RevalidationPerformed`) is 008's.

## Admit

`Admit(actor, run)` with `actor` matching the contract's `Actor` pattern; returns
`{ "admissible": true, "label": "automatic" }` for `benchmark` inside a run, `{ "admissible": false,
"reason": "ACTOR_BENCHMARK_OUTSIDE_RUN" }` outside, `{ "admissible": true, "label": "human" }` for
`operator:<name>`, and `{ "admissible": false, "reason": "ACTOR_NOT_ALLOWED_TO_APPROVE" }` for any
other actor.
