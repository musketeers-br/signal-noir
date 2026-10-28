# Simulator contract captures (feature 002)

`captures/` holds JSON responses written by the `SignalNoir.Tests.Sim.Contract.*` suites when they
call `/sim/api/v1` over HTTP, plus `manifest.json` (`{file, operationId, status, schema}`). They are
never edited by hand; rerun the suites to refresh them.

Validate them against `contracts/openapi-sim.yaml`:

```sh
uv run --with jsonschema --with pyyaml python tests/sim-contract/validate_sim_captures.py
```

The validator fails when a capture does not match its schema or when an operation of the contract
has no capture.
