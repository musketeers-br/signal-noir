# Quickstart: validate the Scenario Simulator

Validation guide for feature 002. Shapes are in `contracts/openapi-sim.yaml`; entities in
[data-model.md](./data-model.md); script format in
[contracts/scenario-script.md](./contracts/scenario-script.md).

## Prerequisites

- The dev container (build 154) is up and the module is loaded.
- iris-agentic-dev is configured for the instance (`IRIS_HOST`, `IRIS_WEB_PORT`,
  `IRIS_USERNAME`, `IRIS_PASSWORD`, `IRIS_NAMESPACE=IRISAPP`).
- `uv` is available on the host (for the capture validator).
- `/sim/api/v1` is registered: run `##class(SignalNoir.Sim.Setup).EnsureWebApplication()` through
  iris-agentic-dev `exec` (until the G1 gate wires it into the product bootstrap).

Below, `SIM=http://localhost:<host port of 52773>/sim/api/v1`.

## 1. Unit and contract suites (primary check)

Run through iris-agentic-dev:

- `SignalNoir.Tests.Sim.Core` — determinism, ids, canonical payload, script matching (no HTTP).
- `SignalNoir.Tests.Sim.Contract` — every operation over HTTP; writes captures to
  `tests/sim-contract/captures/`.
- `SignalNoir.Tests.Sim.Isolation` — no class outside `SignalNoir.Sim` references it; answer-key
  leak scan.

Then on the host:

```sh
uv run --with jsonschema --with pyyaml python tests/sim-contract/validate_sim_captures.py
```

**Expected**: all suites pass; the validator prints `N valid, 0 invalid` and covers all 12
operations (SC-009).

## 2. Determinism and isolation (Story 1)

```sh
curl -s -X POST $SIM/scenarios -H 'Content-Type: application/json' \
  -d '{"family":"P8","variant":"P8b-tune-01","seed":42}'          # → 201, status "created"
curl -s -X POST $SIM/scenarios/<sciA>/emissions                     # → 201, emitted[]
curl -s -X POST $SIM/scenarios/<sciA>/emissions                     # → 200, same emitted[]
```

Repeat with the same seed (`<sciB>`). **Expected**: `emitted[].order` equal between A and B except
`orderId`; orderIds `ORD-<sciA>-0001` vs `ORD-<sciB>-0001` (SC-001, SC-002).

## 3. Delivery and deduplication (Story 2)

Deliver the `clean.success` Order twice with the same key and payload, then once with a changed
exam code. **Expected**: 200 + Receipt; 200 + same Receipt with `Idempotent-Replayed: true`; 422
`IDEMPOTENCY_KEY_REUSED` (SC-004). The contract suite also fires 10 concurrent identical
deliveries and asserts exactly one Receipt.

## 4. Lost response (Story 3)

Create an `idempotency.lost_receipt` instance with `timeScale: 0.1`, deliver with a client timeout
of `SN_PARTNER_TIMEOUT_SECONDS`. **Expected**: the client times out; then
`GET $SIM/receipts?orderId=<orderId>` returns the Receipt with `orderSnapshot` and no equivalence
key (SC-005).

## 5. Contradictory evidence (Story 4)

P8a instance: deliver until timeout, then read `/partners/<p>/health?scenarioInstanceId=…` and
`/history?…`. **Expected**: health `UP`; history window shows `timeouts ≥ 1` and `errorRate > 0`.

## 6. World change (Story 5)

P3 instance: read health (healthy), `POST /scenarios/<sci>/events {"type":"PARTNER_DEGRADES"}`,
read health again, deliver. **Expected**: `DEGRADED`, next delivery 503/timeout per script; instance
`phase` and `appliedEvents` updated (SC-007). Repeat without the explicit call: the 2nd health
read fires the scripted trigger.

## 7. Answer key (Story 6)

Run `SignalNoir.Tests.Sim.Isolation`. **Expected**: zero occurrences of any `partnerRule` value or
answer-key field across responses of every variant (SC-006).

## 8. P9 data (Story 7)

Emit a P9 instance. **Expected**: one feed item (the resend); `GET /receipts?patientId=…&
scenarioInstanceId=…` returns the original Receipt with `receivedAt` ≈ emission − 3 min and its own
orderId and transactionId.

## Timing check (SC-008)

With `timeScale: 0.1`, the P1 first Attempt holds for `SN_PARTNER_TIMEOUT_SECONDS + 5 s`, never
less. Record the measured hold in research.md's Verification log (V4).
