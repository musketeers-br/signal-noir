Class SignalNoir.Tests.Application.TestBenchmarkApproval Extends %UnitTest.TestCase
{

/// 007 T017 - automatic approval exists only inside a BenchmarkRun
ClassMethod RunCase(svc, tag, runId, answer, ByRef cmd) As %String
{
	Set S = "SignalNoir.Tests.Support"
	Set caseId = $ClassMethod(S, "InvestigatingCase", svc, tag, "rules", .cmd, "SERUM")
	Set rec = ##class(SignalNoir.Application.Model.CaseRecord).%OpenId(caseId)
	; feature 010: a run id counts only for a run that exists and is running
	If runId '= "" Do $ClassMethod(S, "EnsureRun", runId)
	Set rec.runId = runId
	Do rec.%Save()
	Do $ClassMethod(S, "Script", caseId, "answer", answer)
	Return caseId
}

Method TestApprovedByBenchmarkInsideARun()
{
	Set S = "SignalNoir.Tests.Support"
	Set svc = ##class(SignalNoir.Application.CaseService).Default()
	Set caseId = ..RunCase(svc, "bench-in", "run_bench_01", $ClassMethod(S, "P8bAnswer"), .cmd)
	Do $$$AssertTrue($ClassMethod(S, "Investigate", cmd).ok, "investigated")
	Set c = svc.GetCase(caseId).obj
	Do $$$AssertEquals(c.state, "Approved", "approved in the same commit")
	Do $$$AssertEquals(c.approvals.%Size(), 1, "one approval")
	Set a = c.approvals.%Get(0)
	Do $$$AssertEquals(a.by, "benchmark", "by the benchmark")
	Do $$$AssertEquals(a.proposalId, c.currentProposalId, "on the current Proposal")
	Do $$$AssertTrue(a.reason [ "run_bench_01", "labelled with its run")
	Set tl = svc.GetTimeline(caseId, 0, 500).list
	Set automatic = 0
	For i = 1 : 1 : tl.Count() If (tl.GetAt(i).type = "ApprovalRecorded") && tl.GetAt(i).payload.automatic Set automatic = 1
	Do $$$AssertTrue(automatic, "ApprovalRecorded says automatic")
	Do $$$AssertEquals(##class(SignalNoir.Tests.Application.TestDecision).Requests(caseId, "Execute"), 1, "execution request queued")
	Do $ClassMethod(S, "ClearScript", caseId)
}

Method TestNormalCaseWaitsForOperator()
{
	Set S = "SignalNoir.Tests.Support"
	Set svc = ##class(SignalNoir.Application.CaseService).Default()
	Set caseId = ..RunCase(svc, "bench-out", "", $ClassMethod(S, "P8bAnswer"), .cmd)
	Do $ClassMethod(S, "Investigate", cmd)
	Set c = svc.GetCase(caseId).obj
	Do $$$AssertEquals(c.state, "PendingApproval", "waits for an Operator")
	Do $$$AssertEquals(c.approvals.%Size(), 0, "no approval")
	Do $ClassMethod(S, "ClearScript", caseId)
}

Method TestHoldInARunNeedsNoApproval()
{
	Set S = "SignalNoir.Tests.Support"
	Set svc = ##class(SignalNoir.Application.CaseService).Default()
	Set hold = $Replace($Replace($ClassMethod(S, "P5Answer"), """REQUEST_REVIEW""", """HOLD"""), """reason"":""business error""", """reason"":""partner maintenance""")
	Set caseId = ..RunCase(svc, "bench-hold", "run_bench_02", hold, .cmd)
	Do $ClassMethod(S, "Investigate", cmd)
	Set c = svc.GetCase(caseId).obj
	Do $$$AssertEquals(c.state, "Executing", "HOLD goes straight to execution")
	Do $$$AssertEquals(c.approvals.%Size(), 0, "no automatic approval for HOLD")
	Do $ClassMethod(S, "ClearScript", caseId)
}

Method TestBenchmarkActorOutsideARun()
{
	Set S = "SignalNoir.Tests.Support"
	Set svc = ##class(SignalNoir.Application.CaseService).Default()
	Set caseId = $ClassMethod(S, "PendingCase", svc, "bench-actor")
	Set c = svc.GetCase(caseId).obj
	Set r = svc.Transition(caseId, c.caseVersion, "Rejected", "benchmark", $ClassMethod(S, "Ev", "no run"))
	Do $$$AssertEquals(r.code, "INVALID_ACTOR", "benchmark refused outside a run")
	Do $$$AssertEquals(svc.GetCase(caseId).obj.caseVersion, c.caseVersion, "nothing recorded")
	; the decision always acts as an Operator, even one called benchmark
	Set d = svc.DecideProposal(caseId, c.currentProposalId, {"decision": "approved", "operator": "benchmark", "expectedCaseVersion": (c.caseVersion)})
	Do $$$AssertEquals(svc.ApprovalJson(d.details.approvalId).by, "operator:benchmark", "an Operator named benchmark")
}

}
