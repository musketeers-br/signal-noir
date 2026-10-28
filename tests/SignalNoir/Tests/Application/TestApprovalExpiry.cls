Class SignalNoir.Tests.Application.TestApprovalExpiry Extends %UnitTest.TestCase
{

/// 007 T014 - an approval has a deadline; only the sweeper expires it
ClassMethod Svc(now As %String) As SignalNoir.Application.CaseService
{
	Set svc = ##class(SignalNoir.Application.CaseService).Default()
	Set clock = ##class(SignalNoir.Tests.Fakes.FixedClock).%New()
	Set clock.Value = now
	Set svc.Clock = clock
	Return svc
}

/// The sweeper over this Case only (the dev database keeps other tests' rows)
ClassMethod Sweep(caseId As %String, now As %String) As %DynamicObject
{
	Return ##class(SignalNoir.Tasks.Sweeper).Run(now, $ListBuild(caseId), 0, 30, "none")
}

Method TestExpiresAfterDeadline()
{
	Set S = "SignalNoir.Tests.Support"
	Set svc = ..Svc("2026-10-29T13:00:00Z")
	Set caseId = $ClassMethod(S, "PendingCase", svc, "exp-due")
	Set d = $ClassMethod(S, "Decide", svc, caseId)
	Do $$$AssertTrue(d.ok, "approved")
	Set exec = ##class(SignalNoir.Tests.Application.TestCommandBus).Last(caseId, "Execute")
	; within the deadline nothing happens
	Set out = ..Sweep(caseId, "2026-10-29T13:14:59Z")
	Do $$$AssertEquals(out.expired, 0, "still valid")
	Do $$$AssertEquals(svc.GetCase(caseId).obj.state, "Approved", "still approved")
	; past it
	Set out = ..Sweep(caseId, "2026-10-29T13:15:01Z")
	Do $$$AssertEquals(out.expired, 1, "expired")
	Set c = svc.GetCase(caseId).obj
	Do $$$AssertEquals(c.state, "PendingApproval", "waits for a new approval")
	Do $$$AssertEquals(c.currentApprovalId, "", "no current approval")
	Do $$$AssertEquals(svc.ApprovalJson(d.details.approvalId).status, "expired", "marked expired")
	Set tl = svc.GetTimeline(caseId, 0, 500).list
	Set found = 0
	For i = 1 : 1 : tl.Count() If (tl.GetAt(i).type = "ApprovalExpired") && (tl.GetAt(i).actor = "sweeper") Set found = 1
	Do $$$AssertTrue(found, "ApprovalExpired by the sweeper")
	; the queued execution request can no longer run: it is discarded on delivery
	Set bus = ##class(SignalNoir.Tests.Application.TestCommandBus).Bus()
	Do $$$AssertEquals(bus.Deliver(exec).details.status, "discarded", "old execution request discarded")
	; approving again gives a new approval with a new deadline, never the expired one
	Set svc2 = ..Svc("2026-10-29T13:20:00Z")
	Set again = $ClassMethod(S, "Decide", svc2, caseId)
	Do $$$AssertTrue(again.ok, "approved again")
	Do $$$AssertEquals(again.details.replay, 0, "not a replay")
	Do $$$AssertTrue(again.details.approvalId '= d.details.approvalId, "a new approval")
	Do $$$AssertEquals(svc.ApprovalJson(again.details.approvalId).expiresAt, "2026-10-29T13:35:00Z", "new deadline")
}

Method TestNewEvidenceKeepsApproval()
{
	Set S = "SignalNoir.Tests.Support"
	Set svc = ..Svc("2026-10-29T13:00:00Z")
	Set caseId = $ClassMethod(S, "PendingCase", svc, "exp-ev")
	Set d = $ClassMethod(S, "Decide", svc, caseId)
	Set orderId = svc.GetCase(caseId).obj.orderId
	; a new Exception of the Order is attached while Approved (003)
	Do $$$AssertTrue(svc.RecordException(orderId, $ClassMethod(S, "Exception")).ok, "exception attached")
	Set c = svc.GetCase(caseId).obj
	Do $$$AssertEquals(c.state, "Approved", "still approved")
	Do $$$AssertEquals(c.currentApprovalId, d.details.approvalId, "same approval")
	Do $$$AssertEquals(svc.ApprovalJson(d.details.approvalId).status, "valid", "still valid")
}

Method TestExecutingIsNotTouched()
{
	Set S = "SignalNoir.Tests.Support"
	Set svc = ..Svc("2026-10-29T13:00:00Z")
	Set caseId = $ClassMethod(S, "PendingCase", svc, "exp-exec")
	Set d = $ClassMethod(S, "Decide", svc, caseId)
	Do svc.Transition(caseId, svc.GetCase(caseId).obj.caseVersion, "Executing", "system", $ClassMethod(S, "Ev"))
	Set out = ..Sweep(caseId, "2026-10-29T14:00:00Z")
	Do $$$AssertEquals(out.expired, 0, "left to revalidation (008)")
	Do $$$AssertEquals(svc.GetCase(caseId).obj.state, "Executing", "still executing")
	Do $$$AssertEquals(svc.ApprovalJson(d.details.approvalId).status, "valid", "not marked")
}

Method TestSweeperRedelivers()
{
	Set S = "SignalNoir.Tests.Support"
	Set svc = ..Svc("2026-10-29T13:00:00Z")
	Set caseId = $ClassMethod(S, "PendingCase", svc, "exp-redeliver")
	Do $ClassMethod(S, "Decide", svc, caseId, "denied", "Carla", "no")
	Set cmd = ##class(SignalNoir.Tests.Application.TestCommandBus).Last(caseId, "Reassess")
	; the decision's own delivery was lost; within the grace period the sweeper waits
	Set out = ##class(SignalNoir.Tasks.Sweeper).Run("2026-10-29T13:00:10Z", $ListBuild(caseId), 0, 30, "none")
	Do $$$AssertEquals(out.redelivered, 0, "too recent")
	Set out = ##class(SignalNoir.Tasks.Sweeper).Run("2026-10-29T13:01:00Z", $ListBuild(caseId), 0, 30, "none")
	; the walk's stale Investigate is redelivered (and discarded) along with it
	Do $$$AssertTrue(out.redelivered >= 1, "redelivered")
	Do $$$AssertEquals(##class(SignalNoir.Tests.Application.TestCommandBus).Status(cmd), "done", "processed")
	Do $$$AssertEquals(svc.GetCase(caseId).obj.state, "Investigating", "the denial's destination")
}

Method TestNewProposalSupersedesApproval()
{
	Set S = "SignalNoir.Tests.Support"
	Set svc = ##class(SignalNoir.Application.CaseService).Default()
	Set caseId = $ClassMethod(S, "InvestigatingCase", svc, "exp-sup", "agent", .cmd, "SERUM")
	Set rec = ##class(SignalNoir.Application.Model.CaseRecord).%OpenId(caseId)
	; an approval of the previous Proposal is still valid on record
	Set old = $ClassMethod(S, "FixtureProposal", caseId)
	Set appr = ##class(SignalNoir.Application.Model.ApprovalRecord).%New()
	Set appr.approvalId = ##class(SignalNoir.Application.IdFactory).%New().New("appr_"), appr.caseId = caseId, appr.proposalId = old
	Set appr.decision = "approved", appr.by = "operator:ana", appr.at = "2026-10-29T13:00:00Z", appr.expiresAt = "2026-10-29T13:15:00Z"
	Do appr.%Save()
	Do $ClassMethod(S, "Script", caseId, "answer", $ClassMethod(S, "P8bAnswer"))
	Do $$$AssertTrue($ClassMethod(S, "Investigate", cmd).ok, "investigated")
	Set c = svc.GetCase(caseId).obj
	Do $$$AssertTrue(c.currentProposalId '= old, "a new Proposal")
	Do $$$AssertEquals(svc.ApprovalJson(appr.approvalId).status, "superseded", "the old approval can authorize nothing")
	Do $ClassMethod(S, "ClearScript", caseId)
}

/// 007 T016: the sweeper is one scheduled task
Method TestTaskEnsuredOnce()
{
	Do $$$AssertStatusOK(##class(SignalNoir.Tasks.SweeperTask).Ensure(), "ensured")
	Do $$$AssertStatusOK(##class(SignalNoir.Tasks.SweeperTask).Ensure(), "ensured again")
	Do $$$AssertEquals(##class(SignalNoir.Tasks.SweeperTask).Count(), 1, "one task")
	Do $$$AssertStatusOK(##class(SignalNoir.Tasks.SweeperTask).Remove(), "removed (tests leave no schedule behind)")
	Do $$$AssertEquals(##class(SignalNoir.Tasks.SweeperTask).Count(), 0, "gone")
}

}
