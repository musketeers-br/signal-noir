# Contract change 001 — add a health surface to the product API

**Status**: proposed, to be applied before any code for this feature.
**Owner**: feature 001 (runtime skeleton and shared seams).
**Target**: `contracts/openapi-signalnoir.yaml` (frozen, normative).

## Why

Spec 001 requires a health surface that reports, distinctly, **liveness**, **readiness** and
**provider availability** (FR-001, FR-002, FR-003, FR-020). The frozen contract exposes only
product resources (`/cases`, Approvals, Review, Benchmark, Reference) and has no endpoint that
carries an operational signal. Under AD-16 every HTTP interface has a versioned OpenAPI, so the
endpoint must be added to the contract rather than added silently to the code.

## Proposed addition

Add `GET /health` under the existing server `/signalnoir/api/v1`.

```yaml
  /health:
    get:
      tags: [Reference]
      summary: Liveness, readiness and provider availability
      operationId: getHealth
      responses:
        "200":
          description: >
            Always returned while the process is alive; the body distinguishes ready from degraded.
          content:
            application/json:
              schema:
                type: object
                required: [status, liveness, provider, serverTime]
                properties:
                  status:
                    type: string
                    enum: [ready, degraded]
                  liveness:
                    type: string
                    enum: [alive]
                  provider:
                    type: object
                    required: [configured]
                    properties:
                      configured:
                        type: boolean
                      reason:
                        type: string
                        description: Present when configured is false; names the unavailable provider.
                  serverTime:
                    type: string
                    format: date-time
```

## Behaviour

- `liveness` is `alive` whenever the process answers.
- `status` is `ready` when the application can serve the product API; it is `degraded` when the
  provider is not configured, while the product API still answers (the "no key" requirement).
- `provider.configured` is false when no valid key is present; `reason` then names the unavailable
  provider.
- The endpoint never returns 500 for a missing key; a missing key is a reported value, not a
  failure (Principle VII).

## Compatibility and process

- Purely additive: no existing path, schema or code changes.
- The change is made by editing `contracts/openapi-signalnoir.yaml` before the corresponding code
  is written (AD-16, contract-first).
- The `docs/seams.md` copy of the seam does not include HTTP; the health surface is a product API
  concern and lives only in the OpenAPI.
- Approval: at least one other team member reviews this change (Constitution Governance). Until
  approved, the feature uses this draft and does not merge code that depends on the endpoint.

## Alternatives rejected

- Reusing `GET /cases` as readiness — conflates a product resource with an operational signal and
  cannot report provider availability without changing `/cases`.
- A separate, unversioned web app outside `/signalnoir/api/v1` — violates AD-16 (every HTTP
  interface must be in a versioned contract) and splits the API surface for a juror.
