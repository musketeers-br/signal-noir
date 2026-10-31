# Contract change 015 — Case precedents

**Status**: proposed by feature 015 (Henry), 2026-10-31. Applied to
`contracts/openapi-signalnoir.yaml` and `docs/seams.md` together with the implementation; needs
review by another team member before merge (Constitution, Governance).

**Scope**: additive only. No existing operation, schema, state, Action, Timeline event type, actor,
command or error code changes. Existing fixtures stay valid.

## Why

The spec (Assumptions) makes the Operator-facing search a new observable operation. The contract is
frozen, so the operation enters through this change.

## HTTP: new operation

```yaml
  /cases/{caseId}/precedents:
    get:
      operationId: getCasePrecedents
      summary: Similar closed Cases (similarity search, not Evidence)
      description: >
        Up to k closed Cases most similar to this one, from IRIS vector search. Informational only:
        never Evidence, never input to the Validator. A search failure is reported in `status`
        with HTTP 200 so the Case always opens. Each call may append one Timeline Annotation
        (kind precedent_search), at most one per minute per Case and requester.
      parameters:
        - $ref: '#/components/parameters/CaseId'
        - name: k
          in: query
          required: false
          schema: { type: integer, minimum: 1, maximum: 10, default: 5 }
      responses:
        '200':
          content:
            application/json:
              schema: { $ref: '#/components/schemas/PrecedentSearch' }
        '400': { $ref: '#/components/responses/ValidationFailed' }   # k out of range
        '404': { $ref: '#/components/responses/NotFound' }
```

(The `$ref` names follow the existing components; the implementation uses whatever names the file
already defines for the CaseId parameter and the 400/404 error envelopes.)

## HTTP: new schemas

```yaml
    PrecedentSearch:
      type: object
      required: [caseId, status, mode, model, dimension, k, minSimilarity, items, recorded, notice]
      properties:
        caseId: { type: string }
        status:
          type: string
          enum: [results, no_precedents, nothing_similar, rebuilding, needs_rebuild, unavailable]
        mode: { type: string, enum: [lexical, provider] }
        model: { type: string }
        dimension: { type: integer }
        k: { type: integer }
        minSimilarity: { type: number }
        items:
          type: array
          maxItems: 10
          items: { $ref: '#/components/schemas/PrecedentMatch' }
        reason:
          type: string
          enum: [provider_unavailable, unsupported_dimension, index_error, model_changed]
        recorded: { type: boolean }
        notice: { type: string }
    PrecedentMatch:
      type: object
      required: [caseId, orderId, partnerId, description, finalState, closedAt, durationSeconds, similarity, synthetic, replay]
      properties:
        caseId: { type: string }
        orderId: { type: string }
        partnerId: { type: string }
        description: { type: string, maxLength: 600 }
        action:
          type: string
          nullable: true
          enum: [RETRY, APPLY_APPROVED_MAPPING, HOLD, REQUEST_REVIEW, null]
        finalState: { type: string, enum: [Resolved, ResolvedByPriorReceipt, Cancelled, Failed] }
        closedAt: { type: string, format: date-time }
        durationSeconds: { type: integer }
        similarity: { type: number, minimum: 0, maximum: 1 }
        synthetic: { type: boolean }
        replay: { type: boolean }
```

`PrecedentMatch` deliberately has no vector, raw text or model field (FR-008).

## Fixtures (new, validated by `contracts/tools/validate_fixtures.py`)

- `precedents.200.results.json` — lexical mode, three matches, one `Failed`.
- `precedents.200.no-precedents.json`
- `precedents.200.nothing-similar.json`
- `precedents.200.rebuilding.json`
- `precedents.200.needs-rebuild.json` (`reason: model_changed`)
- `precedents.200.unavailable.json` (`mode: provider`, `reason: provider_unavailable`)

## Timeline (no schema change)

The search record is an `Annotation` (existing type) with payload `kind: precedent_search` (see
data-model). The `Annotation` payload is free-form in the contract, so nothing changes there.

## Seams (docs/seams.md v4 → v5)

| v4 | v5 |
|---|---|
| `InvestigationContext`: `investigationId`, `case`, `order`, `evidence`, `tools`, `budget` | + `precedents` (optional list of `PrecedentMatch`; absent unless `SN_PRECEDENTS_AGENT=1`). Proposers MUST NOT turn it into Evidence; `ProposalShape` is unchanged and still accepts only Evidence ids. |
| — | New port `Embedder`: `Embed(text) -> Result{obj: vector (%List of numbers), details: {model, mode, dimension}}`, failure codes `provider_unavailable`, `unsupported_dimension`. |

Consumers that ignore `precedents` compile and run unchanged.
