Class SignalNoir.Tests.Application.Benchmark.TestAutomaticApproval Extends %UnitTest.TestCase
{

/// 010 T035 - Automatic Approval exists only for a Case whose run is running (FR-008 to
/// FR-010, Principle IV). The 007 cases (TestBenchmarkApproval) pin the behaviour inside a
/// run; these pin the new edge: a run that is not running, or does not exist, approves nothing.
ClassMethod Run(runId As %String, status As %String)
{
	If ##class(SignalNoir.Application.Model.BenchmarkRunRecord).%ExistsId(runId) Do ##class(SignalNoir.Application.Model.BenchmarkRunRecord).%DeleteId(runId)
	Set run = ##class(SignalNoir.Application.Model.BenchmarkRunRecord).%New()
	Set run.runId = runId, run.mode = "rules", run.purpose = "benchmark", run.status = status
	$$$ThrowOnError(run.%Save())
}

/// An Investigating Case that carries runId (the Case may outlive the run's state)
ClassMethod RunCase(svc, tag, runId, answer, ByRef cmd) As %String
{
	Set S = "SignalNoir.Tests.Support"
	Set caseId = $ClassMethod(S, "InvestigatingCase", svc, tag, "rules", .cmd, "SERUM")
	Set rec = ##class(SignalNoir.Application.Model.CaseRecord).%OpenId(caseId)
	Set rec.runId = runId
	Do rec.%Save()
	Do $ClassMethod(S, "Script", caseId, "answer", answer)
	Return caseId
}

Method TestInsideARunningRunTheBenchmarkApproves()
{
	Set S = "SignalNoir.Tests.Support"
	Do ..Run("run_auto_in", "running")
	Set svc = ##class(SignalNoir.Application.CaseService).Default()
	Set caseId = ..RunCase(svc, "auto-in", "run_auto_in", $ClassMethod(S, "P8bAnswer"), .cmd)
	Do $$$AssertTrue($ClassMethod(S, "Investigate", cmd).ok, "investigated")
	Set c = svc.GetCase(caseId).obj
	Do $$$AssertEquals(c.state, "Approved", "approved")
	Set a = c.approvals.%Get(0)
	Do $$$AssertEquals(a.by, "benchmark", "by the benchmark actor")
	Do $$$AssertTrue(a.reason [ "run_auto_in", "naming its run")
	Set rec = ##class(SignalNoir.Application.Model.ApprovalRecord).%OpenId(a.approvalId)
	Do $$$AssertTrue(rec.expiresAt '= "", "it has a deadline, like a human Approval")
	Do $$$AssertEquals(rec.status, "valid", "and it is valid until used or expired")
	Set tl = svc.GetTimeline(caseId, 0, 500).list
	Set automatic = 0
	For i = 1 : 1 : tl.Count() If (tl.GetAt(i).type = "ApprovalRecorded") && tl.GetAt(i).payload.automatic Set automatic = 1
	Do $$$AssertTrue(automatic, "labelled automatic on the Timeline")
	Do $ClassMethod(S, "ClearScript", caseId)
}

Method TestARunThatEndedApprovesNothing()
{
	Set S = "SignalNoir.Tests.Support"
	Set svc = ##class(SignalNoir.Application.CaseService).Default()
	For status = "completed", "failed", "created" {
		Set run = "run_auto_" _ status
		Do ..Run(run, status)
		Set caseId = ..RunCase(svc, "auto-" _ status, run, $ClassMethod(S, "P8bAnswer"), .cmd)
		Do $ClassMethod(S, "Investigate", cmd)
		Set c = svc.GetCase(caseId).obj
		Do $$$AssertEquals(c.state, "PendingApproval", "run " _ status _ ": the Case waits for an Operator")
		Do $$$AssertEquals(c.approvals.%Size(), 0, "run " _ status _ ": nothing was approved")
		Set r = svc.Transition(caseId, c.caseVersion, "Approved", "benchmark", $ClassMethod(S, "Ev", "late"))
		Do $$$AssertEquals(r.code, "INVALID_ACTOR", "run " _ status _ ": the benchmark actor is refused")
		Do $ClassMethod(S, "ClearScript", caseId)
	}
}

Method TestAnUnknownRunApprovesNothing()
{
	Set S = "SignalNoir.Tests.Support"
	Set svc = ##class(SignalNoir.Application.CaseService).Default()
	Set caseId = ..RunCase(svc, "auto-unknown", "run_never_created", $ClassMethod(S, "P8bAnswer"), .cmd)
	Do $ClassMethod(S, "Investigate", cmd)
	Set c = svc.GetCase(caseId).obj
	Do $$$AssertEquals(c.state, "PendingApproval", "waits for an Operator")
	Do $$$AssertEquals(c.approvals.%Size(), 0, "nothing approved")
	Set r = svc.Transition(caseId, c.caseVersion, "Approved", "benchmark", $ClassMethod(S, "Ev", "no such run"))
	Do $$$AssertEquals(r.code, "INVALID_ACTOR", "refused")
	Do $ClassMethod(S, "ClearScript", caseId)
}

Method TestACaseOutsideARunIsRefusedThroughEveryPath()
{
	Set S = "SignalNoir.Tests.Support"
	Set svc = ##class(SignalNoir.Application.CaseService).Default()
	Set caseId = $ClassMethod(S, "PendingCase", svc, "auto-outside")
	Set c = svc.GetCase(caseId).obj
	Do $$$AssertEquals(svc.Transition(caseId, c.caseVersion, "Approved", "benchmark", $ClassMethod(S, "Ev", "x")).code, "INVALID_ACTOR", "the state machine")
	Set d = svc.DecideProposal(caseId, c.currentProposalId, {"decision": "approved", "operator": "benchmark", "expectedCaseVersion": (c.caseVersion)})
	Do $$$AssertEquals(svc.ApprovalJson(d.details.approvalId).by, "operator:benchmark", "the decision endpoint acts as an Operator, even one named benchmark")
	Do $$$AssertEquals(svc.GetCase(caseId).obj.approvals.%Get(0).by, "operator:benchmark", "so no approval by the benchmark actor exists")
}

Method TestAHoldInARunNeedsNoApproval()
{
	Set S = "SignalNoir.Tests.Support"
	Do ..Run("run_auto_hold", "running")
	Set svc = ##class(SignalNoir.Application.CaseService).Default()
	Set hold = $Replace($Replace($ClassMethod(S, "P5Answer"), """REQUEST_REVIEW""", """HOLD"""), """reason"":""business error""", """reason"":""partner maintenance""")
	Set caseId = ..RunCase(svc, "auto-hold", "run_auto_hold", hold, .cmd)
	Do $ClassMethod(S, "Investigate", cmd)
	Set c = svc.GetCase(caseId).obj
	Do $$$AssertEquals(c.state, "Executing", "straight to execution")
	Do $$$AssertEquals(c.approvals.%Size(), 0, "no Approval is recorded for a HOLD")
	Do $ClassMethod(S, "ClearScript", caseId)
}

}
