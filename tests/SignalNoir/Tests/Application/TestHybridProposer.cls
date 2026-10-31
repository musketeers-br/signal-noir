Class SignalNoir.Tests.Application.TestHybridProposer Extends %UnitTest.TestCase
{

/// 016 T003-T007 - Decisions first, the AI Hub Agent when Decisions is not
/// decisive, through the shared Investigation path (fake runtimes, no key)
Parameter FAKE = "SignalNoir.Tests.Fakes.HybridWithFakes";

ClassMethod Reset(decisions As %String = "", decisionsFail As %String = "", agent As %String = "", agentFail As %String = "", hang As %Integer = 0)
{
	Set g = "^SignalNoir.TestScript(""decisions"")" Kill @g
	Set g = "^SignalNoir.TestScript(""agent"")" Kill @g
	If decisions '= "" Set ^SignalNoir.TestScript("decisions", "answer") = decisions
	If decisionsFail '= "" Set ^SignalNoir.TestScript("decisions", "fail") = decisionsFail
	If hang Set ^SignalNoir.TestScript("decisions", "hang") = hang
	If agent '= "" Set ^SignalNoir.TestScript("agent", "content") = agent
	If agentFail '= "" Set ^SignalNoir.TestScript("agent", "fail") = agentFail
}

ClassMethod Run(svc, tag As %String, budgetMs As %Integer = 20000, ByRef cmd) As %String
{
	Set caseId = ##class(SignalNoir.Tests.Support).InvestigatingCase(svc, tag, "hybrid", .cmd, "serum")
	Do ##class(SignalNoir.Tests.Support).Investigate(cmd, ..#FAKE, budgetMs)
	Return caseId
}

/// The proposer_cascade Annotations of a Case
ClassMethod Cascades(svc, caseId) As %DynamicArray
{
	Set out = []
	Set tl = svc.GetTimeline(caseId, 0, 500).list
	For i = 1 : 1 : tl.Count() {
		Set ev = tl.GetAt(i)
		If (ev.type = "Annotation") && $IsObject(ev.payload) && (ev.payload.kind = "proposer_cascade") Do out.%Push(ev.payload)
	}
	Return out
}

/// US1: a decisive typed answer settles it; the Agent is never called
Method TestDecisiveDecisions()
{
	Set F = "SignalNoir.Tests.Fakes.FakeDecisionsRuntime", S = "SignalNoir.Tests.Support"
	Set svc = ##class(SignalNoir.Application.CaseService).Default()
	Do ..Reset($ClassMethod(F, "Answer", "HOLD", 0.85, 0.05, 0.8, "tool.partner_health:0.9"), , $ClassMethod(S, "P8bAnswer"))
	Set caseId = ..Run(svc, "hyb-dec", , .cmd)
	Set c = svc.GetCase(caseId).obj
	Do $$$AssertEquals(c.state '= "Investigating", 1, "investigation finished")
	Do $$$AssertEquals(c.proposals.Count(), 1, "one Proposal")
	Do $$$AssertEquals(c.proposals.GetAt(1).origin, "decisions", "authored decisions")
	Do $$$AssertEquals(c.proposals.GetAt(1).action, "HOLD", "the typed answer")
	Do $$$AssertEquals(+$Get(^SignalNoir.TestScript("agent", "calls")), 0, "no AI Hub call")
	Set cs = ..Cascades(svc, caseId)
	Do $$$AssertEquals(cs.%Size(), 1, "one cascade event")
	Do $$$AssertEquals(cs.%Get(0).decisions, "decisive", "decisions was decisive")
	Do $$$AssertEquals(cs.%Get(0).decidedBy, "decisions", "decided by decisions")
	Do $$$AssertEquals(cs.%Get(0).choice, "HOLD", "choice recorded")
	Set inv = ##class(SignalNoir.Application.Model.InvestigationRecord).%OpenId(cmd)
	Do $$$AssertEquals(inv.mode, "hybrid", "the Investigation keeps the mode")
	Do $$$AssertEquals(inv.provider, "openai-decisions", "usage of the decider")
	Do ..Reset()
}

/// US2: every non-decisive outcome hands over to the Agent, once
Method TestFallbackToAgent()
{
	Set F = "SignalNoir.Tests.Fakes.FakeDecisionsRuntime", S = "SignalNoir.Tests.Support"
	Set svc = ##class(SignalNoir.Application.CaseService).Default()
	Set outcomes = []
	Do outcomes.%Push(["answer", ($ClassMethod(F, "Answer", "RETRY", 0.45, 0.2)), "uncertain"])
	Do outcomes.%Push(["answer", ($ClassMethod(F, "Answer", "RETRY", 0.52, 0.48)), "uncertain"])
	Do outcomes.%Push(["answer", ($ClassMethod(F, "Answer", "other", 0.9)), "uncertain"])
	Do outcomes.%Push(["answer", ("{""answers"":[{""type"":""refusal"",""name"":""action""}]}"), "refused"])
	Do outcomes.%Push(["answer", ($ClassMethod(F, "Answer", "DELETE_ORDER", 0.99)), "invalid_response"])
	Do outcomes.%Push(["fail", "provider_unavailable:decisions HTTP 401 invalid_api_key", "provider_unavailable"])
	For i = 0 : 1 : outcomes.%Size() - 1 {
		Set o = outcomes.%Get(i)
		If o.%Get(0) = "answer" {
			Do ..Reset(o.%Get(1), , $ClassMethod(S, "P8bAnswer"))
		} Else {
			Do ..Reset(, o.%Get(1), $ClassMethod(S, "P8bAnswer"))
		}
		Set caseId = ..Run(svc, "hyb-fb", , .cmd)
		Set c = svc.GetCase(caseId).obj
		Do $$$AssertEquals(+$Get(^SignalNoir.TestScript("agent", "calls")), 1, "one Agent call " _ i)
		Do $$$AssertEquals(c.proposals.Count(), 1, "one Proposal " _ i)
		Do $$$AssertEquals(c.proposals.GetAt(1).origin, "agent", "authored agent " _ i)
		Do $$$AssertEquals(c.proposals.GetAt(1).params.mappingId, "map_glicj_soro", "the Agent's answer " _ i)
		Set cs = ..Cascades(svc, caseId)
		Do $$$AssertEquals(cs.%Size(), 1, "one cascade event " _ i)
		Do $$$AssertEquals(cs.%Get(0).decisions, o.%Get(2), "decisions outcome " _ i)
		Do $$$AssertEquals(cs.%Get(0).decidedBy, "agent", "decided by the Agent " _ i)
		Do $$$AssertNotTrue(cs.%Get(0).%ToJSON() [ "Incorrect API key", "no provider text " _ i)
		Do $$$AssertEquals(##class(SignalNoir.Application.Model.InvestigationRecord).%OpenId(cmd).provider, "fake-ai-hub", "usage of the Agent " _ i)
	}
	Do ..Reset()
}

/// US3: neither decides, a human does, with the Agent's reason
Method TestNeitherDecides()
{
	Set F = "SignalNoir.Tests.Fakes.FakeDecisionsRuntime"
	Set svc = ##class(SignalNoir.Application.CaseService).Default()
	Do ..Reset($ClassMethod(F, "Answer", "RETRY", 0.4, 0.3), , , "provider_unavailable:fake-ai-hub timed out")
	Set caseId = ..Run(svc, "hyb-none", , .cmd)
	Set c = svc.GetCase(caseId).obj
	Do $$$AssertEquals(c.state, "ReviewRequired", "review")
	Do $$$AssertEquals(c.reviewReason, "provider unavailable: fake-ai-hub timed out", "the Agent's reason")
	Do $$$AssertEquals(c.proposals.Count(), 0, "no Proposal")
	Set cs = ..Cascades(svc, caseId)
	Do $$$AssertEquals(cs.%Get(0).decidedBy, "none", "nobody decided")
	Do $$$AssertEquals(cs.%Get(0).agent, "provider_unavailable", "the Agent's code")
	Do ..Reset()
}

/// US4: Decisions is capped; the Agent keeps the rest of the budget
Method TestBudget()
{
	Set F = "SignalNoir.Tests.Fakes.FakeDecisionsRuntime", S = "SignalNoir.Tests.Support"
	Do $$$AssertEquals(##class(SignalNoir.Proposers.Hybrid).FirstShare(20000), 5000, "a quarter")
	Do $$$AssertEquals(##class(SignalNoir.Proposers.Hybrid).FirstShare(120000), 10000, "at most 10 s")
	Set svc = ##class(SignalNoir.Application.CaseService).Default()
	; Decisions takes 2 s of a 6 s budget, then is not decisive: the Agent still proposes
	Do ..Reset($ClassMethod(F, "Answer", "RETRY", 0.4, 0.3), , $ClassMethod(S, "P8bAnswer"), , 2)
	Set caseId = ..Run(svc, "hyb-bud", 6000, .cmd)
	Set c = svc.GetCase(caseId).obj
	Do $$$AssertEquals(c.proposals.Count(), 1, "the Agent proposed within the budget")
	Do $$$AssertEquals(c.proposals.GetAt(1).origin, "agent", "authored agent")
	; the whole budget passes: closed as for any Investigation
	Do ..Reset($ClassMethod(F, "Answer", "HOLD", 0.9), , , , 3)
	Set caseId = ..Run(svc, "hyb-late", 1000, .cmd)
	Set c = svc.GetCase(caseId).obj
	Do $$$AssertEquals(c.reviewReason, "investigation budget exceeded: time", "budget reason")
	Hang 3
	Do $$$AssertEquals(svc.GetCase(caseId).obj.proposals.Count(), 0, "a late answer changes nothing")
	Do ..Reset()
}

/// US5: the deployment chooses the mode
Method TestModeSelection()
{
	Set Fy = "SignalNoir.Proposers.Factory"
	Do $$$AssertEquals($ClassMethod(Fy, "ClassFor", "hybrid"), "SignalNoir.Proposers.Hybrid", "class")
	Do $$$AssertEquals($ClassMethod(Fy, "Ready", "hybrid"), ##class(SignalNoir.Proposers.AiHubRuntime).Configured() || ##class(SignalNoir.Proposers.DecisionsHttp).Configured(), "ready when either half is")
	If $System.Util.GetEnviron("SN_PROPOSER_MODE") = "" Do $$$AssertEquals($ClassMethod(Fy, "ConfiguredMode"), "agent", "agent by default")
	Do $$$AssertEquals(##class(SignalNoir.Application.InvestigationService).Author("agent", ##class(SignalNoir.Core.Result).OkRef("")), "agent", "other modes keep their author")
}

}
