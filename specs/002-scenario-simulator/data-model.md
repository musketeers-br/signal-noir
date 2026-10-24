# Data Model: Scenario Simulator

All records belong to the `SignalNoir.Sim` bounded context and are stored only in its own
globals. Every record except catalog entries and feed items is owned by exactly one
`ScenarioInstance` and is read only through it (FR-005). Field names follow
`contracts/openapi-sim.yaml`; the HTTP shape of each entity is the contract schema named in
brackets.

## ScenarioVariant (catalog, read-only) [`ScenarioVariant`]

Defined in `SignalNoir.Sim.Catalog.<Family>` XData (research D7). Not persisted.

| Field | Rule |
|-------|------|
| `family` | `clean`, `P1`, `P3`, `P5`, `P8`, `P9`, `idempotency` |
| `subtype` | closed enum of the contract (`clean.success` … `idempotency.repeated_approval`) |
| `variant` | stable id, unique in the catalog, e.g. `P8b-tune-01`, `P8b-test-03` |
| `set` | `tuning` or `test` |
| `partnerId` | matches `^[a-z0-9][a-z0-9-]{1,62}$` |
| `language` | `pt`, `en`, `mixed` |
| `description` | free text, no answer-key content |
| `script` | public script (served) — see [contracts/scenario-script.md](./contracts/scenario-script.md) |
| `partnerRule` | private acceptance rule — **never serialized** (research D8) |
| `orders` | emission template: one entry per Order to emit (content drawn from the seed) |

## ScenarioInstance [`ScenarioInstance`]

| Field | Rule |
|-------|------|
| `scenarioInstanceId` | `sci_…` from a GUID (D4); primary key |
| `family`, `subtype`, `variant`, `set`, `partnerId` | copied from the variant at creation |
| `seed` | integer ≥ 0 |
| `runId` | `run_…` or null |
| `repetition` | integer ≥ 1, default 1 |
| `timeScale` | 0 < x ≤ 1, default 1 |
| `status` | `created` → `emitted` (one way) |
| `phase` | `initial`, then whatever the applied events set (`partner_degraded`, `maintenance`, `order_cancelled`, `partner_recovered`) |
| `appliedEvents` | append-only list of `{type, at}` |
| `emittedOrderIds` | filled at emission, in ordinal order |
| `createdAt` | UTC |

Per-instance counters (not served): attempt count per `orderId`, read counts per resource for
triggers, Receipt ordinal.

**State transitions**

```text
created --emit--> emitted          (emit again: same EmissionResult, 200)
phase: initial --event/trigger--> <event phase> --event/trigger--> ...
```

## OriginOrder

The Order as the Origin emitted it, plus its status.

| Field | Rule |
|-------|------|
| `orderId` | `ORD-<sci>-<NNNN>` (D4); unique globally |
| `scenarioInstanceId` | owner |
| `transactionId` | Origin transaction id |
| `ordinal` | position in the variant's emission template |
| `order` | `SyntheticOrder` raw snapshot, immutable, `synthetic: true`; unordered/mixed-case codes and non-UTC offsets preserved |
| `inFeed` | false for the P9 original (seeded, not published) |
| `status` | `active` or `cancelled` [`OriginOrderStatus`] |
| `statusChangedAt`, `reason` | set on cancellation |
| `emittedAt` | UTC |

## FeedItem [`OrderEnvelope`]

| Field | Rule |
|-------|------|
| `feedSeq` | global monotonic `$INCREMENT`, ≥ 1, never reused |
| `scenarioInstanceId`, `runId`, `repetition`, `transactionId`, `emittedAt`, `order` | copied from the OriginOrder at publication; immutable |

## Delivery (Attempt) and PartnerLogEntry [`PartnerLogEntry`]

One record per call to `POST /partners/{partnerId}/orders` that passed request validation.

| Field | Rule |
|-------|------|
| `scenarioInstanceId`, `partnerId` | from the request |
| `orderId`, `transactionId`, `idempotencyKey` | from the request |
| `attempt` | per-`orderId` ordinal within the instance |
| `payloadCanon` | canonical form of `order` (D5) |
| `httpStatus` | null when the outcome is a timeout |
| `outcome` | `delivered`, `duplicate`, `rejected`, `error`, `timeout`, `unavailable` |
| `latencyMs` | scripted latency actually applied |
| `message` | raw log line (PT/EN), data only |
| `at` | UTC |

History is the list of these entries for an instance, newest first, with the window summary
(`total`, `delivered`, `errors`, `timeouts`, `errorRate = (errors + timeouts) / total`, 0 when
total = 0). Malformed requests (400/404) create no entry.

## Receipt [`Receipt`, `ReceiptRecord`]

| Field | Rule |
|-------|------|
| `receiptId` | `rcp_…` (D4) |
| `orderId`, `idempotencyKey`, `partnerId` | equal to the delivery that produced it |
| `idempotencyKey` | **unique** (D5) |
| `receivedAt` | UTC; for the P9 original, `emission − 3 min` |
| `scenarioInstanceId`, `transactionId` | from the delivery |
| `orderSnapshot` | the delivered `order`, raw |
| `externalRef` | `/sim/api/v1/receipts/{receiptId}` |
| `payloadCanon` | stored for the duplicate comparison; not served |

Created only when the script says the Partner accepted (FR-018). Never carries an equivalence
key (FR-023).

## PartnerState [`PartnerHealth`]

One per instance (the instance's partner).

| Field | Rule |
|-------|------|
| `status` | `UP`, `DEGRADED`, `DOWN` — what the Partner declares, set by script and events, independent of history (P8a) |
| `message` | free text, data |
| `maintenance` | `{active, startsAt, endsAt}` or null |
| `checkedAt` | time of the read (UTC) |

## ScenarioEvent

| Field | Rule |
|-------|------|
| `type` | `PARTNER_DEGRADES`, `PARTNER_RECOVERS`, `MAINTENANCE_STARTS`, `MAINTENANCE_ENDS`, `ORDER_CANCELLED_AT_ORIGIN` |
| `orderId` | required for `ORDER_CANCELLED_AT_ORIGIN`; must belong to the instance |
| `source` | `explicit` or `trigger` (internal) |
| `at` | UTC |

Effect of each event:

| Event | PartnerState | Next deliveries | Origin |
|-------|--------------|-----------------|--------|
| `PARTNER_DEGRADES` | `DEGRADED` (or as scripted) | follow the script's `afterEvent` responses (503 / timeout) | — |
| `PARTNER_RECOVERS` | `UP` | back to the base script | — |
| `MAINTENANCE_STARTS` | `maintenance.active = true` with window | as scripted | — |
| `MAINTENANCE_ENDS` | `maintenance.active = false` | as scripted | — |
| `ORDER_CANCELLED_AT_ORIGIN` | — | unchanged (the Partner does not know) | status `cancelled`, `reason` |

## Relationships

```text
ScenarioVariant 1 ──< ScenarioInstance 1 ──< OriginOrder ──o FeedItem
                                       1 ──< Delivery ──o Receipt   (Receipt unique per idempotencyKey)
                                       1 ── PartnerState
                                       1 ──< ScenarioEvent
```

## Validation rules (request side)

- `POST /scenarios`: known `family` + `variant` (else 404); `seed ≥ 0`; `0 < timeScale ≤ 1`;
  `repetition ≥ 1`; `runId` matches `^run_…` or null (else 400).
- `POST /partners/{partnerId}/orders`: `idempotencyKey` 8–128 chars, `transactionId`,
  `scenarioInstanceId`, `order` with the `SyntheticOrder` required fields (else 400); known
  partner and instance, partner = instance partner (else 404).
- `GET /receipts`: at least one of `idempotencyKey`, `orderId`, `patientId`; `patientId` requires
  `scenarioInstanceId` (else 400). Empty result is 200 `items: []`.
- `GET /partners/{partnerId}/health|history`, `GET /origin/orders`: `scenarioInstanceId` required
  (else 400); unknown partner or instance → 404.
- `POST /scenarios/{id}/events`: known type; `orderId` required and owned by the instance for
  `ORDER_CANCELLED_AT_ORIGIN` (else 400).
- `limit` 1–200, default 50.
