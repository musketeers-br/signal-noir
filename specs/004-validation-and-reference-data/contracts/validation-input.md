# Validation Input (internal contract of the Validator port v2)

What a caller (006 proposers, 009 resolution, 007 approval, 008 revalidation, 010 benchmark) passes to
`Validate`, `Revalidate` and `Admit`. Field names follow `contracts/openapi-signalnoir.yaml` where the
concept exists there.

```json
{
  "proposal": {
    "proposalId": "prop_000045",
    "caseId": "case_000123",
    "origin": "agent",
    "action": "APPLY_APPROVED_MAPPING",
    "params": { "mappingId": "map_glicj_plasma", "mappingVersion": "2026.10.1" },
    "scope": "single_case",
    "confidence": "ALTA",
    "preconditions": [
      { "check": "PARTNER_HEALTHY_WINDOW", "expected": true },
      { "check": "ORDER_ACTIVE_AT_ORIGIN", "expected": true },
      { "check": "POLICY_VERSION_UNCHANGED", "expected": "2026.10.1" },
      { "check": "MAPPING_VERSION_UNCHANGED", "expected": "2026.10.1" }
    ],
    "versions": { "policy": "2026.10.1", "mapping": "2026.10.1" },
    "priorReceiptCandidate": null
  },
  "evidence": [ { "evidenceId": "evid_1", "caseId": "case_000123", "source": "tool.policies",
                  "obsolete": false, "suspicious": false, "facts": { "policy": "substitution" } } ],
  "order": { "...": "raw SyntheticOrder snapshot of the Case" },
  "priorReceiptOrder": null,
  "identity": "clear",
  "attemptCount": 1,
  "run": { "inRun": false, "runId": null, "policyVersion": null, "mappingVersion": null },
  "reference": "<ReferenceData snapshot for run or in force>",
  "observed": null,
  "now": "2026-10-29T13:02:11Z"
}
```

## Evidence

Evidence counts toward the minimum only if `caseId` equals the Proposal's, `obsolete = false` and
`suspicious = false`.

| Required item | `source` | `facts` |
|---|---|---|
| attempt policy | `tool.policies` | `policy = "attempt"` |
| substitution policy | `tool.policies` | `policy = "substitution"` |
| maintenance window | `tool.policies` | `policy = "maintenance"` |
| attempt history | `tool.partner_failure_history` | — |
| recent partner health | `tool.partner_health` | — |
| approved Mapping | `tool.mapping_catalog` | `mappingId` = `proposal.params.mappingId` |
| Order field | `tool.order_timeline` | `field` = Order path of the Mapping condition (e.g. `specimen.type`) |

**Owner of the convention**: 004. **Producer**: 006 Tools. To confirm with Henry before 006's plan.

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
precondition step (spec FR-022).

## Admit

`Admit(actor, run)` with `actor` matching the contract's `Actor` pattern; returns
`{ "admissible": true, "label": "automatic" }` for `benchmark` inside a run, `{ "admissible": false,
"reason": "ACTOR_BENCHMARK_OUTSIDE_RUN" }` outside, `{ "admissible": true, "label": "human" }` for
`operator:<name>`, and `{ "admissible": false, "reason": "ACTOR_NOT_ALLOWED_TO_APPROVE" }` for any
other actor.
