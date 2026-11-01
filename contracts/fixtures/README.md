# API fixtures for `openapi-signalnoir.yaml`

Example responses of `/signalnoir/api/v1`, one per case state and per server response that the UI must handle (B03). The SPA develops against them until the backend exists, and they are the reference examples for B07 and B10. All data is synthetic.

## Where they come from

They are generated, not hand-written, by the prototype's mock API (`_bmad-output/initiative-signal-noir/prototype-signal-noir/`). The mock runs deterministic scenarios and the exporter saves the real responses:

```sh
node _bmad-output/initiative-signal-noir/prototype-signal-noir/tools/export-api-fixtures.js contracts/fixtures
```

Running it twice produces identical files.

## Checked against the contract

`manifest.json` maps each file to its operation, HTTP status and contract schema. The validator checks every fixture against `openapi-signalnoir.yaml` as JSON Schema 2020-12:

```sh
uv run --with jsonschema --with pyyaml python contracts/tools/validate_fixtures.py
```

Re-run both commands after any contract change. A fixture that stops validating means either the contract changed under the UI or the mock drifted from the contract; fix one of them, never the fixture by hand.

## What is covered

| Situation | Files |
|---|---|
| List | `cases.list.needs-you.json`, `cases.list.outcome-unknown.json` |
| Waiting for approval (P5/P8b) | `case.pending-approval.p5-p8b.json`, `timeline.full.p5-p8b.json` |
| Superseded proposal, obsoleted evidence | `case.pending-approval.superseded.json` |
| Approval, replay, denial | `decision.201.approved.json`, `decision.200.idempotent-replay.json`, `decision.201.denied.json` |
| Errors | `decision.409.stale-version.json`, `decision.409.invalid-transition.json`, `decision.400.denial-without-reason.json`, `case.404.json` |
| Resolved, incremental timeline | `case.resolved.p5-p8b.json`, `timeline.incremental.p5-p8b.json` |
| Held after failed revalidation (P3) | `case.held.p3.json` |
| Outcome unknown, then reconciliation | `case.executing.outcome-unknown.json`, `case.resolved.by-reconciliation.json` |
| Dossiers | `case.review.provider-unavailable.json`, `case.review.ambiguous-identity.json`, `case.review.after-denial.json` |
| Operator resolution | `resolution.422.validator-blocked.json`, `resolution.201.action.json`, `resolution.201.cancel.json` |
| Prior receipt (P9, conditional) | `case.resolved-by-prior-receipt.p9.json` |
| Reference data | `reference.mappings.json` |

Benchmark responses are not covered yet; they depend on API-Q1 (how one command runs both modes).

Precedents (015) are not here: the mock has no precedents, so their hand-written fixtures live in
`contracts/precedents-fixtures/` with their own manifest. Validate them with
`uv run --with jsonschema --with pyyaml python contracts/tools/validate_fixtures.py contracts/precedents-fixtures`.
