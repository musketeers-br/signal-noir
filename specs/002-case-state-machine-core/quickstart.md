# Quickstart: validate the Case state machine Core

**Feature**: [spec.md](spec.md) | **Plan**: [plan.md](plan.md)

## Prerequisites

- iris-agentic-dev on the PATH and configured for the workspace (`.mcp.json`, `.iris-agentic-dev.toml`).
- **Target instance (SPIKE-DEPENDENT, research R2)**: an IRIS AI Hub build 154 container. Until it is up, the same commands run against the current dev container, and the results count as provisional.
- `uv`, for the contract tools.

## 1. Table fixture is up to date

```bash
uv run --with pyyaml python contracts/tools/test_export_state_machine_json.py
```

```bash
uv run --with pyyaml python contracts/tools/export_state_machine_json.py --xdata
```

```bash
git diff --exit-code -- tests/fixtures/case-state-machine.json tests/SignalNoir/Tests/Core/TableFixture.cls
```

Expected: the export test passes and there is no diff. A diff means the YAML changed: recompile `TableFixture` and run the parity test against the new table.

## 2. Compile

```bash
iris-agentic-dev compile src/SignalNoir/Core/*.cls src/SignalNoir/Application/*.cls src/SignalNoir/Application/Store/*.cls tests/SignalNoir/Tests/*.cls tests/SignalNoir/Tests/Core/*.cls tests/SignalNoir/Tests/Application/*.cls
```

Expected: all classes compile with no errors.

## 3. Run the suites

The `iris_test` tool of iris-agentic-dev does not find these classes (research, Verification log), so the suites run through the test-only runner (fallback of research R10). `^UnitTestRoot` must point to the tests folder inside the container (`/home/irisowner/dev/tests` in the dev container):

```bash
iris-agentic-dev exec 'do ##class(SignalNoir.Tests.Runner).Run("SignalNoir/Tests/Core")'
```

```bash
iris-agentic-dev exec 'do ##class(SignalNoir.Tests.Runner).Run("SignalNoir/Tests/Application")'
```

Suites in each package:

| Suite | Proves |
|---|---|
| `SignalNoir.Tests.Core.Purity`, `SignalNoir.Tests.Core.TableData` | the Core has no I/O; the compiled table equals the YAML |
| `SignalNoir.Tests.Application.Store` | one non-terminal Case per Order; append-only Timeline |
| `SignalNoir.Tests.Core.Parity` | 29/29 rows accepted as in the table; every pair outside it refused with `INVALID_TRANSITION` (SC-001) |
| `SignalNoir.Tests.Core.Decide` | refusal codes, idempotent Approval, precedence, `denialCount`, attachments, purity check |
| `SignalNoir.Tests.Application.CommandPath` | atomic recording, `CommandDiscarded` on refusal, unchanged state and version (SC-002) |
| `SignalNoir.Tests.Application.Concurrency` | one winner in 100 repeated runs per scenario (SC-004) |
| `SignalNoir.Tests.Application.Journeys` | UJ-1 to UJ-4 end to end with the `journeyTrace` actors (SC-003) |
| `SignalNoir.Tests.Application.Episodes` | terminal never reopens; T02 link; T25 → T02 |

Expected: `suite SignalNoir/Tests/Core: 17 passed, 0 failed` and `suite SignalNoir/Tests/Application: 23 passed, 0 failed` (counts as of 2026-10-22).

## 4. Table change is caught (SC-005)

In a scratch copy of the repository, change one row's `events` in `contracts/case-state-machine.yaml`, re-run step 1 and the `Parity` suite: it must fail naming that row.

## 5. Contract checks of spec 001 stay green

```bash
uv run --with pyyaml python contracts/tools/test_validate_state_machine.py
```
