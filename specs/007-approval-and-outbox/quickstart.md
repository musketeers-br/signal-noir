# Quickstart: Approval and the Transactional Outbox

## Tests

Through iris-agentic-dev (see 003 quickstart). 007 suites: `Core.TestDecisionShape`,
`Core.TestApprovalPolicy`, `Application.TestDecision`, `Application.TestApprovalExpiry`,
`Application.TestCommandBus`, `Application.TestBenchmarkApproval`, `Api.TestDecisionApi`; then the
full suite.

## Live API

```sh
PORT=$(docker port signalnoir-iris 52773 | head -1 | cut -d: -f2)
curl -s -X POST "http://localhost:$PORT/signalnoir/api/v1/cases/<caseId>/proposals/<proposalId>/decision" \
  -H 'Content-Type: application/json' -d '{"decision":"approved","operator":"Carla","expectedCaseVersion":5}'
uv run --with jsonschema --with pyyaml --with requests python tests/contract/validate_live.py --base "http://localhost:$PORT/signalnoir/api/v1"
```

| Check | Expect |
|---|---|
| approve current version | 201, `Approved`, `case.commandId` set |
| approve again | 200, `idempotentReplay: true`, same approval |
| stale version | 409 `STALE_VERSION`, `details.currentProposalId` |
| deny without reason | 400 `VALIDATION_FAILED` |
| sweeper after the deadline | Case back in `PendingApproval`, approval `expired` |

## Console

Open `/signalnoir/`, filter Needs you, open a `PendingApproval` Case, approve: the toast says
approved; approve again: "Already approved … No new effect."
