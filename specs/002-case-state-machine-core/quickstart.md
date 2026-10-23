# Quickstart: validate the Case state machine Core

**Feature**: [spec.md](spec.md) | **Plan**: [plan.md](plan.md)

## Prerequisites

- iris-agentic-dev on the PATH and configured for the workspace (`.mcp.json`, `.iris-agentic-dev.toml`).
- **Target instance (SPIKE-DEPENDENT, research R2)**: an IRIS AI Hub build 154 container. Until it is up, the same commands run against the current dev container, and the results count as provisional.
- `uv`, for the contract tools.

## 1. Table fixture is up to date

```bash
uv run --with pyyaml python contracts/tools/export_state_machine_json.py
```

```bash
git diff --exit-code -- tests/fixtures/case-state-machine.json
```

Expected: no diff. A diff means the YAML changed and the parity test must run against the new table.

## 2. Compile

```bash
iris-agentic-dev compile src/SignalNoir/Core src/SignalNoir/Application tests/SignalNoir/Tests
```

Expected: all classes compile with no errors.

## 3. Run the suites

Run the `%UnitTest` packages through iris-agentic-dev (its unit-test tool, or `exec` of `%UnitTest.Manager` as a fallback, research R10):

| Suite | Proves |
|---|---|
| `SignalNoir.Tests.Core.Parity` | 29/29 rows accepted as in the table; every pair outside it refused with `INVALID_TRANSITION` (SC-001) |
| `SignalNoir.Tests.Core.Decide` | refusal codes, idempotent Approval, precedence, `denialCount`, attachments, purity check |
| `SignalNoir.Tests.Application.CommandPath` | atomic recording, `CommandDiscarded` on refusal, unchanged state and version (SC-002) |
| `SignalNoir.Tests.Application.Concurrency` | one winner in 100 repeated runs per scenario (SC-004) |
| `SignalNoir.Tests.Application.Journeys` | UJ-1 to UJ-4 end to end with the `journeyTrace` actors (SC-003) |
| `SignalNoir.Tests.Application.Episodes` | terminal never reopens; T02 link; T25 → T02 |

Expected: every suite passes, with zero failures.

## 4. Table change is caught (SC-005)

In a scratch copy of the repository, change one row's `events` in `contracts/case-state-machine.yaml`, re-run step 1 and the `Parity` suite: it must fail naming that row.

## 5. Contract checks of spec 001 stay green

```bash
uv run --with pyyaml python contracts/tools/test_validate_state_machine.py
```
