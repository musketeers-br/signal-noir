# Quickstart: Order Intake and Case Lifecycle

## Prerequisites

- The dev IRIS container running (`docker compose up -d`), namespace `IRISAPP`.
- iris-agentic-dev configured (`IRIS_CONTAINER` or `--container`, `IRIS_NAMESPACE=IRISAPP`,
  credentials from the environment).
- For the conformance check: `uv` (Python with `jsonschema`, `pyyaml`, `requests`).

## 1. Compile

```sh
iris-agentic-dev compile -n IRISAPP src/SignalNoir/**/*.cls tests/SignalNoir/**/*.cls
```

Expected: every class compiles with no error.

## 2. Run the suites

```sh
iris-agentic-dev exec -n IRISAPP 'set ^UnitTestRoot="/home/irisowner/dev/tests" do ##class(%UnitTest.Manager).RunTest("SignalNoir","/noload/nodelete/recursive")'
```

Expected: all `SignalNoir.Tests.*` pass, including the 003 suites:
`Core.TestOrderShape`, `Core.TestCanon`, `Core.TestCaseMachine`, `Core.TestCursor`,
`Application.TestIntake`, `Application.TestExceptionRouting`, `Application.TestTransitions`,
`Application.TestConcurrency`, `Application.TestRestart003`, `Application.TestRejectionExpiry`,
`Application.TestProjections`, `Api.TestTimelineRead`.

## 3. Scenario walk-through (spec acceptance)

| Scenario | How | Expect |
|---|---|---|
| Invalid Order | `OrderIn.Accept` with a snapshot lacking `specimen` | `VALIDATION_FAILED`, `details.reasons` names the field, an `IntakeRefusalRecord`, no Order, no Case |
| Failed delivery | accept a valid Order, `OrderIn.ReportException(orderId, timeout…)` | one Case; Timeline `CaseOpened`, `ExceptionRecorded`, then `StateChanged Open→Investigating` (or `→ReviewRequired` with the provider unavailable) |
| Second Exception | report again | same Case, two Exceptions |
| After terminal | drive the Case to `Cancelled` (`ReviewRequired → Cancelled` by `operator:x`), report again | new Case, `CaseOpened.previousCaseId` = old Case |
| Stale version | two `Transition` calls with the same expected version | one ok, one `STALE_VERSION` with `details` |
| Restart | `docker compose restart iris`, then read the Cases | same state, version, Timeline; interrupted `Investigating` → `ReviewRequired` |

## 4. Read views over HTTP

```sh
PORT=$(docker port congenial-waffle-iris-1 52773 | head -1 | cut -d: -f2)
curl -s "http://localhost:$PORT/signalnoir/api/v1/cases?limit=2"
curl -s "http://localhost:$PORT/signalnoir/api/v1/cases/<caseId>"
curl -s "http://localhost:$PORT/signalnoir/api/v1/cases/<caseId>/timeline?sinceSeq=0"
```

## 5. Contract conformance of live responses

```sh
uv run --with jsonschema --with pyyaml --with requests python tests/contract/validate_live.py --base "http://localhost:$PORT/signalnoir/api/v1"
```

Expected: every list, detail and Timeline response validates against
`contracts/openapi-signalnoir.yaml` (`CaseListPage`, `CaseDetail`, `TimelinePage`,
`ErrorEnvelope` for 400/404).
