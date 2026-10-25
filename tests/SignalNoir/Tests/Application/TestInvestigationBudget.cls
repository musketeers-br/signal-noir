Class SignalNoir.Tests.Application.TestInvestigationBudget Extends %UnitTest.TestCase
{

/// 006 T021 - US2: 6 Tool calls and the time limit, enforced by the server
Method TestSeventhToolCallRefused()
{
	Set S = "SignalNoir.Tests.Support"
	Set svc = ##class(SignalNoir.Application.CaseService).Default()
	Set caseId = $ClassMethod(S, "InvestigatingCase", svc, "calls", "rules", .cmd)
	Do $ClassMethod(S, "Script", caseId, "tools", "tool.order_timeline,tool.receipts_and_orders_by_patient")
	Do $ClassMethod(S, "Script", caseId, "answer", $ClassMethod(S, "P5Answer"))
	Set r = $ClassMethod(S, "Investigate", cmd)
	Do $$$AssertEquals(r.details.status, "review", "closed by the budget")
	Do $$$AssertEquals($Extract(^SignalNoir.TestScript(caseId, "toolResult", 1), 1, 3), "ok:", "6th call allowed")
	Do $$$AssertEquals(^SignalNoir.TestScript(caseId, "toolResult", 2), "budget_exceeded", "7th call refused")
	Do $$$AssertEquals(+^SignalNoir.TestScript(caseId, "reads"), 6, "the 7th call never reached the source")
	Set c = svc.GetCase(caseId).obj
	Do $$$AssertEquals(c.state, "ReviewRequired", "ReviewRequired")
	Do $$$AssertEquals(c.reviewReason, "investigation budget exceeded: tool calls", "reason")
	Set tools = 0
	For i = 1 : 1 : c.evidence.Count() If $Extract(c.evidence.GetAt(i).source, 1, 5) = "tool." Set tools = tools + 1
	Do $$$AssertEquals(tools, 6, "the 6 Evidence collected are kept")
	Do $$$AssertEquals(c.proposals.Count(), 0, "no Proposal")
	Do $$$AssertEquals(##class(SignalNoir.Application.Model.InvestigationRecord).%OpenId(cmd).toolCalls, 6, "never more than 6")
	Do $ClassMethod(S, "ClearScript", caseId)
}

Method TestTimeLimitAndLateAnswer()
{
	Set S = "SignalNoir.Tests.Support"
	Set svc = ##class(SignalNoir.Application.CaseService).Default()
	Set caseId = $ClassMethod(S, "InvestigatingCase", svc, "slow", "rules", .cmd)
	Do $ClassMethod(S, "Script", caseId, "sleep", 3)
	Do $ClassMethod(S, "Script", caseId, "answer", $ClassMethod(S, "P5Answer"))
	; a 1.5 s budget for the test; the production value is the core's 20 s
	Set r = $ClassMethod(S, "Investigate", cmd, , 1500)
	Do $$$AssertEquals(r.details.status, "review", "closed by the time limit")
	Set c = svc.GetCase(caseId).obj
	Do $$$AssertEquals(c.state, "ReviewRequired", "ReviewRequired")
	Do $$$AssertEquals(c.reviewReason, "investigation budget exceeded: time", "reason")
	Set before = c.lastEventSeq
	Set evidenceBefore = c.evidence.Count()
	Do $$$AssertTrue(evidenceBefore >= 6, "Evidence collected before the limit kept")
	; the worker answers after the closure
	For i = 1 : 1 : 100 {
		Quit:$ClassMethod(S, "Types", svc, caseId)["CommandDiscarded"
		Hang 0.1
	}
	Set c = svc.GetCase(caseId).obj
	Do $$$AssertEquals(c.state, "ReviewRequired", "the late answer changed nothing")
	Do $$$AssertEquals(c.proposals.Count(), 0, "no Proposal from the late answer")
	Do $$$AssertTrue($ClassMethod(S, "Types", svc, caseId) [ "CommandDiscarded", "the late answer is recorded as discarded")
	Do $ClassMethod(S, "ClearScript", caseId)
}

}
