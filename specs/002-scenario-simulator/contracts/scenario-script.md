# Scenario Script Format (internal contract of `SignalNoir.Sim`)

**Status**: draft for feature 002. The HTTP contract stays `contracts/openapi-sim.yaml`; this
document fixes the free-form `ScenarioVariant.script` ("Forma livre na v1") and the private
`partnerRule` that live in `SignalNoir.Sim.Catalog.*` XData. It is the contract between the
Simulator and whoever authors variants (tuning: this feature; reserved test: the reserved-case
holder, spec 010).

## Variant document

```json
{
  "family": "P8",
  "subtype": "P8b",
  "variant": "P8b-tune-01",
  "set": "tuning",
  "partnerId": "labpartner-a",
  "language": "mixed",
  "description": "Discontinued glucose code; two approved mappings differ by specimen type.",
  "orders": [
    { "template": "glucose-panel", "exams": ["GLIC-J"], "specimen": { "type": "plasma" } }
  ],
  "script": {
    "health": { "status": "UP", "message": "all systems nominal" },
    "attempts": [
      { "match": "beforeMapping", "respond": { "status": 400, "body": "discontinued-code", "delay": "fast" } },
      { "match": "wrongMapping",  "respond": { "status": 400, "body": "exam-specimen-mismatch", "delay": "fast" } },
      { "match": "accepted",      "respond": { "status": 200, "receipt": true, "delay": "fast" } }
    ],
    "triggers": []
  },
  "partnerRule": {
    "accepts": [ { "code": "GLI-02", "when": { "specimen.type": "plasma" } } ]
  }
}
```

## Fields

- **`orders[]`**: emission template. Content not given explicitly (names, ids, dates, wording
  choice) is drawn from the seed (research D3). Raw-data quirks (mixed case, unordered codes,
  non-UTC offsets, embedded instructions in `notes`) are declared here.
  An entry may declare `"priorOf": <ordinal>` with `"receivedAtOffsetSeconds": -180`: it is the
  original of the Order at that ordinal (same patient, exams and specimen; its own orderId and
  transactionId), seeded at emission with `inFeed = false` and a Receipt at the given offset from
  the resend's emission time. Only P9 variants use it.
- **`script.health`**: initial `PartnerHealth` (status, message, maintenance).
- **`script.attempts[]`**: ordered rules; the first that matches answers the Attempt.
  - `match`: `attempt:<n>`, `attempt:<n>+`, `beforeMapping`, `wrongMapping`, `accepted`,
    `afterEvent:<EVENT_TYPE>`, `any`. `beforeMapping` / `wrongMapping` / `accepted` are evaluated
    against the private `partnerRule` and never reveal it.
  - `respond.status`: HTTP status, or `none` for a timeout (no response before the client gives
    up).
  - `respond.body`: a wording key resolved per `language` and seed into the scripted text (PT/EN,
    possibly misleading, possibly with an embedded instruction), `empty` for no body, or `receipt`.
  - `respond.receipt`: `true` → a Receipt is recorded before the response (also for
    `lose: true`).
  - `respond.lose`: `true` → the Receipt is recorded and the response is held beyond the client
    timeout (lost response).
  - `respond.delay`: `fast` (≤ 200 ms), `slow` (nominal 5 s), `timeout` (nominal 90 s); the
    applied hold follows research D6.
- **`script.afterEvent`**: optional map `{ "<EVENT_TYPE>": { "health": {…}, "history": [ {
  "outcome": "timeout", "httpStatus": null, "latencyMs": 90000, "message": "<wording key>" }, … ]
  } }`. `health` overrides PartnerHealth; `history` entries are appended at event time as
  third-party traffic (no orderId). Entry count and wording are drawn from the seed.
- **`script.triggers[]`**: `{ "on": "read:health" | "read:history" | "read:originStatus" |
  "attempt", "nth": <n>, "event": "<EVENT_TYPE>", "orderOrdinal": <k>? }`.
- **`partnerRule`** (private): what the Partner accepts. Never serialized by any endpoint;
  covered by the leak test (SC-006).

## Served form

`GET /scenario-catalog` serves the variant without `partnerRule` and with `orders[]` reduced to
counts and declared quirks; `script.attempts[].match` values that refer to the private rule are
served as-is (`beforeMapping`, `wrongMapping`, `accepted`) because they name a condition, not its
value.

## Invariants

1. No field of a variant document contains the expected Action, its parameters, the expected final
   state or the expected classification.
2. A variant is immutable once its `set` is `test` and the freeze commit is made; a change creates
   a new `variant` id.
3. Every subtype of the contract enumeration has at least one `tuning` variant; P5 and P8b have at
   least 5 `test` variants each at the freeze (FR-032).
