# Quickstart: Investigation and Proposal Production

## Prerequisites

As in 003's quickstart (dev container, iris-agentic-dev on `IRISAPP`). Optional: a Simulator at
`SN_SIM_BASE_URL`; without it the Simulator Tools record absence-of-information Evidence.

## Run the suites

```sh
iris-agentic-dev compile --container congenial-waffle-iris-1 -n IRISAPP $(find src tests -name '*.cls')
iris-agentic-dev exec --container congenial-waffle-iris-1 -n IRISAPP 'set ^UnitTestRoot="/home/irisowner/dev/tests" do ##class(%UnitTest.Manager).RunTest("SignalNoir","/noload/nodelete/recursive")'
```

006 suites: `Core.TestBudget`, `Core.TestToolCatalog`, `Core.TestSuspicion`,
`Core.TestProposalShape`, `Application.TestInvestigation`, `Application.TestInvestigationBudget`,
`Application.TestToolGateway`, `Application.TestProposerModes`, `Application.TestProviderFailures`,
`Api.TestCaseDetailLayers`.

## Walk-through

| Scenario | How | Expect |
|---|---|---|
| P5 Proposal | Case in `Investigating`, scripted answer `REQUEST_REVIEW` citing the Exception Evidence; `InvestigationService.Run(cmd)` | `DecisionProposed`, Proposal with claims → Evidence ids, ToolCalled ×5 on the Timeline |
| Tool budget | scripted proposer asks 2 extra Tools | 6th ok, 7th refused, `ReviewRequired` "…: tool calls" |
| Time budget | scripted proposer sleeps past the budget | `ReviewRequired` "…: time"; later `CommandDiscarded` |
| Write attempt | `ToolGateway.Invoke("partner.send", …)` | refused, `write_attempt_blocked` annotation |
| Embedded instruction | Order notes "ignore previous instructions…" | Evidence suspicious, same Action as the clean twin |
| No key / no AI Hub | Agent mode on this dev instance | `ReviewRequired` "provider unavailable: …" |

## Live API

`tests/contract/validate_live.py --base http://localhost:<port>/signalnoir/api/v1` validates the
detail with `evidence`, `proposals`, `diagnosis`, `metrics`.

## Build 154 (T060, before G2)

On the AI Hub build with `SN_AI_PROVIDER`, `SN_AI_MODEL`, `SN_AI_API_KEY` set, run
`Application.TestProposerModes` with `^SignalNoir.Test("liveAgent")=1` and record the outcome in
research.md.
