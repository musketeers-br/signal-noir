# Quickstart: validate the state machine

**Feature**: [spec.md](spec.md) | **Plan**: [plan.md](plan.md)

## Prerequisites

- Repository cloned; `uv` and Node 24 installed (the same as the `contracts` workflow).
- No IRIS instance is needed in Phase A.

## 1. Automatic validation of the table

```bash
uv run --with pyyaml python contracts/tools/test_validate_state_machine.py
```

Expected result: every negative case prints `ok` (each one produced the error it expects), then `ok case-state-machine.yaml`, and the exit code is 0.

The validator alone, which also lists the contract changes still pending for 2.5:

```bash
uv run --with pyyaml python contracts/tools/validate_state_machine.py
```

Expected result: `ok …/case-state-machine.yaml`, followed by `pending contract changes (2.5)` listing C1–C5 of [contracts/openapi-delta.md](contracts/openapi-delta.md).

Manual negative checks: delete T18 in a copy of the YAML and run the validator with `--file <copy>`; it must fail (the spec still has T18, and the trace no longer matches). Change T18's actor to `system`: it must fail with an actor mismatch between spec and YAML. Add an `Open → Executing` row: it must fail with "transition not in spec.md".

## 2. Contracts stay green

```bash
npx --yes @redocly/cli@1.34.0 lint contracts/openapi-signalnoir.yaml contracts/openapi-sim.yaml
```

```bash
uv run --with jsonschema --with pyyaml python contracts/tools/validate_fixtures.py
```

Both must still pass, because this story does not edit the OpenAPI or the fixtures.

## 3. Human proof (SC-002)

1. Give José only `contracts/case-state-machine.yaml` (or the spec's table) and `ux-signal-noir/EXPERIENCE.md`.
2. Without help and with a timer, he fills in the transition and actor of each step of UJ-1 to UJ-4.
3. Compare with the YAML's `journeyTrace`. The proof passes with a 100% match within 30 min. Record the result in the ticket's notes.

## 4. Replacement recorded

- `addendum.md` §D and the "Pontos fixados" table of AD-24 show the "Replaced" note with a link.
- PRD FR-5 points to the new table.

## 5. Phase B (from 10/26, another story)

The parity test described in [contracts/core-transition-port.md](contracts/core-transition-port.md) runs on the live instance through iris-agentic-dev and uses the same YAML as its oracle. Its language and test framework are chosen in the Phase B Plan (research R4).
