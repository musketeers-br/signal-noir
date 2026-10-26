Class SignalNoir.Tests.Application.TestRejectionExpiry Extends %UnitTest.TestCase
{

/// 003 T048 - US6: rejection has a limit, expiry a destination
Method TestFirstAndSecondRejection()
{
	Set svc = ##class(SignalNoir.Application.CaseService).Default()
	Set caseId = ##class(SignalNoir.Tests.Support).OpenCase(svc, ##class(SignalNoir.Tests.Support).Uid("rej"))
	Do $$$AssertEquals(##class(SignalNoir.Tests.Support).DriveTo(svc, caseId, "Rejected"), "", "first rejection")
	Set c = svc.GetCase(caseId).obj
	Do $$$AssertEquals(c.denialCount, 1, "count 1")
	Set r = svc.ResolveRejection(caseId, c.caseVersion, "wrong mapping")
	Do $$$AssertTrue(r.ok, "resolved")
	Set c = svc.GetCase(caseId).obj
	Do $$$AssertEquals(c.state, "Investigating", "new investigation")
	Set n = ##class(SignalNoir.Tests.Support).Outbox(caseId, .rows)
	Do $$$AssertEquals($ListGet(rows(n), 2), "Investigate", "investigation requested")
	Do $$$AssertEquals({}.%FromJSON($ListGet(rows(n), 5)).rejectionReason, "wrong mapping", "the reason travels to the investigation")
	; second round
	For step = "DecisionProposed:agent", "PendingApproval:system", "Rejected:operator:ana" {
		Set g = svc.GetCase(caseId).obj
		Do $$$AssertTrue(svc.Transition(caseId, g.caseVersion, $Piece(step, ":", 1), $Piece(step, ":", 2, 3), ##class(SignalNoir.Tests.Support).Ev()).ok, step)
	}
	Set c = svc.GetCase(caseId).obj
	Do $$$AssertEquals(c.denialCount, 2, "count 2")
	Set before = ##class(SignalNoir.Tests.Support).Outbox(caseId, .rows)
	Set r = svc.ResolveRejection(caseId, c.caseVersion, "still wrong")
	Do $$$AssertTrue(r.ok, "resolved")
	Set c = svc.GetCase(caseId).obj
	Do $$$AssertEquals(c.state, "ReviewRequired", "second rejection -> review")
	Do $$$AssertEquals(c.reviewReason, "second rejection", "reason")
	Do $$$AssertEquals(##class(SignalNoir.Tests.Support).Outbox(caseId, .rows), before, "no new investigation")
}

Method TestResolveRejectionNeedsRejected()
{
	Set svc = ##class(SignalNoir.Application.CaseService).Default()
	Set caseId = ##class(SignalNoir.Tests.Support).OpenCase(svc, ##class(SignalNoir.Tests.Support).Uid("rejx"))
	Set c = svc.GetCase(caseId).obj
	Do $$$AssertEquals(svc.ResolveRejection(caseId, c.caseVersion, "x").code, "STALE_VERSION", "only from Rejected")
}

Method TestExpiryOnlyBySweeper()
{
	Set svc = ##class(SignalNoir.Application.CaseService).Default()
	Set caseId = ##class(SignalNoir.Tests.Support).OpenCase(svc, ##class(SignalNoir.Tests.Support).Uid("exp"))
	Do $$$AssertEquals(##class(SignalNoir.Tests.Support).DriveTo(svc, caseId, "Approved"), "", "approved")
	Set c = svc.GetCase(caseId).obj
	For actor = "system", "operator:x", "agent" {
		Do $$$AssertEquals(svc.Transition(caseId, c.caseVersion, "PendingApproval", actor, ##class(SignalNoir.Tests.Support).Ev("approval expired")).code, "INVALID_ACTOR", "expiry refused to " _ actor)
	}
	Set t = svc.Transition(caseId, c.caseVersion, "PendingApproval", "sweeper", ##class(SignalNoir.Tests.Support).Ev("approval expired"))
	Do $$$AssertTrue(t.ok, "sweeper expires")
	Set after = svc.GetCase(caseId).obj
	Do $$$AssertEquals(after.state, "PendingApproval", "needs a new Approval")
	Do $$$AssertEquals(after.currentApprovalId, "", "expired Approval cleared")
	Set ev = svc.GetTimeline(caseId, c.lastEventSeq).list.GetAt(1)
	Do $$$AssertEquals(ev.payload.reason, "approval expired", "expiry on the Timeline")
	Do $$$AssertEquals(ev.actor, "sweeper", "by the sweeper")
}

}
