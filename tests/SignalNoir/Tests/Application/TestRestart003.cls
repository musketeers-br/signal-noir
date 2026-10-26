Class SignalNoir.Tests.Application.TestRestart003 Extends %UnitTest.TestCase
{

/// 003 T036 - US4: Cases survive a restart; interrupted investigations do
/// not stay orphaned
Method TestStateVersionTimelineAndWorkSurvive()
{
	Set svc = ##class(SignalNoir.Application.CaseService).Default()
	Kill snap
	For target = "Open", "PendingApproval", "Held" {
		Set caseId = ##class(SignalNoir.Tests.Support).OpenCase(svc, ##class(SignalNoir.Tests.Support).Uid("rs"))
		Do $$$AssertEquals(##class(SignalNoir.Tests.Support).DriveTo(svc, caseId, target), "", "walked to " _ target)
		Set c = svc.GetCase(caseId).obj
		Set tl = svc.GetTimeline(caseId, 0).list
		Set types = ""
		For i = 1 : 1 : tl.Count() Set types = types _ tl.GetAt(i).seq _ ":" _ tl.GetAt(i).type _ ";"
		Set snap(caseId) = $ListBuild(c.state, c.caseVersion, c.lastEventSeq, types, ##class(SignalNoir.Tests.Support).Outbox(caseId, .rows))
	}
	; restart: drop every in-memory reference, read from a fresh service
	Kill svc, c, tl
	Set svc2 = ##class(SignalNoir.Application.CaseService).Default()
	Set caseId = ""
	For {
		Set caseId = $Order(snap(caseId), 1, expected)
		Quit:caseId=""
		Set c = svc2.GetCase(caseId).obj
		Set tl = svc2.GetTimeline(caseId, 0).list
		Set types = ""
		For i = 1 : 1 : tl.Count() Set types = types _ tl.GetAt(i).seq _ ":" _ tl.GetAt(i).type _ ";"
		Do $$$AssertEquals($ListBuild(c.state, c.caseVersion, c.lastEventSeq, types, ##class(SignalNoir.Tests.Support).Outbox(caseId, .rows)), expected, "identical after restart: " _ $ListGet(expected, 1))
	}
}

Method TestInterruptedInvestigationGoesToReview()
{
	Set svc = ##class(SignalNoir.Application.CaseService).Default()
	Set interrupted = ##class(SignalNoir.Tests.Support).OpenCase(svc, ##class(SignalNoir.Tests.Support).Uid("intr"))
	Do $$$AssertEquals(##class(SignalNoir.Tests.Support).DriveTo(svc, interrupted, "Investigating"), "", "investigating")
	Do ##class(SignalNoir.Tests.Support).Outbox(interrupted, .rows)
	Do $$$AssertTrue(svc.MarkDispatched($ListGet(rows(1), 1)).ok, "the investigation was picked up")
	Set waiting = ##class(SignalNoir.Tests.Support).OpenCase(svc, ##class(SignalNoir.Tests.Support).Uid("wait"))
	Do $$$AssertEquals(##class(SignalNoir.Tests.Support).DriveTo(svc, waiting, "Investigating"), "", "investigating, not picked up")
	Set r = svc.RecoverInterrupted()
	Do $$$AssertTrue(r.ok, "recovery ran")
	Set c = svc.GetCase(interrupted).obj
	Do $$$AssertEquals(c.state, "ReviewRequired", "interrupted -> ReviewRequired")
	Do $$$AssertEquals(c.reviewReason, "investigation interrupted", "reason")
	Do $$$AssertEquals(svc.GetCase(waiting).obj.state, "Investigating", "pending work is left for the consumer")
	Do ##class(SignalNoir.Tests.Support).Outbox(waiting, .rows)
	Do $$$AssertEquals($ListGet(rows(1), 3), "pending", "still pending")
	Set v = c.caseVersion
	Do svc.RecoverInterrupted()
	Do $$$AssertEquals(svc.GetCase(interrupted).obj.caseVersion, v, "running it again changes nothing")
}

}
