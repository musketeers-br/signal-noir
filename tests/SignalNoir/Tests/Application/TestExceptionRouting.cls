Class SignalNoir.Tests.Application.TestExceptionRouting Extends %UnitTest.TestCase
{

/// 003 T022 - US2: the first Exception opens a Case; later Exceptions join it
Method TestNoExceptionNoCase()
{
	Set svc = ##class(SignalNoir.Application.CaseService).Default()
	Set orderId = ##class(SignalNoir.Tests.Support).Uid("clean")
	Do $$$AssertTrue(svc.AcceptOrder(##class(SignalNoir.Tests.Support).Order(orderId)).ok, "accepted")
	Do $$$AssertEquals(svc.OpenCase(orderId).code, "NOT_FOUND", "no Case without an Exception")
}

Method TestFirstExceptionOpensCase()
{
	Set svc = ##class(SignalNoir.Application.CaseService).Default()
	Set orderId = ##class(SignalNoir.Tests.Support).Uid("first")
	Do svc.AcceptOrder(##class(SignalNoir.Tests.Support).Order(orderId))
	Set r = svc.RecordException(orderId, ##class(SignalNoir.Tests.Support).Exception("http_error", 500))
	Do $$$AssertTrue(r.ok, "recorded")
	Do $$$AssertEquals(r.details.route, "open", "route open")
	Set g = svc.GetCase(r.ref)
	Do $$$AssertEquals(g.obj.state, "Open", "Open")
	Do $$$AssertEquals(g.obj.caseVersion, 1, "caseVersion 1")
	Do $$$AssertEquals(g.obj.exceptions.Count(), 1, "one Exception")
	Do $$$AssertEquals(g.obj.exceptions.GetAt(1).httpStatus, 500, "status kept")
	Do $$$AssertEquals(g.obj.exceptions.GetAt(1).body.detail, "unknown exam code", "body kept as data")
	Do $$$AssertEquals(g.obj.order.correlationId '= "", 1, "correlation ids on the Case")
	Set tl = svc.GetTimeline(r.ref, 0)
	Do $$$AssertEquals(tl.list.Count(), 2, "two events")
	Do $$$AssertEquals(tl.list.GetAt(1).type, "CaseOpened", "opening first")
	Do $$$AssertEquals(tl.list.GetAt(2).type, "ExceptionRecorded", "then the failure")
	Do $$$AssertEquals(tl.list.GetAt(2).payload.kind, "http_error", "kind on the Timeline")
	Do $$$AssertEquals(svc.OpenCase(orderId).ref, r.ref, "OpenCase finds it")
}

Method TestUnknownOrderAndBadKind()
{
	Set svc = ##class(SignalNoir.Application.CaseService).Default()
	Do $$$AssertEquals(svc.RecordException("never-accepted-" _ $JOB, ##class(SignalNoir.Tests.Support).Exception()).code, "NOT_FOUND", "unknown order")
	Set orderId = ##class(SignalNoir.Tests.Support).Uid("kind")
	Do svc.AcceptOrder(##class(SignalNoir.Tests.Support).Order(orderId))
	Do $$$AssertEquals(svc.RecordException(orderId, ##class(SignalNoir.Tests.Support).Exception("crash")).code, "VALIDATION_FAILED", "unknown kind")
	Do $$$AssertEquals(svc.OpenCase(orderId).code, "NOT_FOUND", "no Case from a refused Exception")
}

Method TestSecondExceptionJoinsAndReinvestigates()
{
	Set svc = ##class(SignalNoir.Application.CaseService).Default()
	Set orderId = ##class(SignalNoir.Tests.Support).Uid("second")
	Set caseId = ##class(SignalNoir.Tests.Support).OpenCase(svc, orderId)
	Set r = svc.RecordException(orderId, ##class(SignalNoir.Tests.Support).Exception("business_rejection"))
	Do $$$AssertEquals(r.ref, caseId, "same Case")
	Do $$$AssertEquals(r.details.route, "attach_and_investigate", "Open reinvestigates")
	Set g = svc.GetCase(caseId)
	Do $$$AssertEquals(g.obj.exceptions.Count(), 2, "two Exceptions")
	Do $$$AssertEquals(g.obj.state, "Investigating", "back to Investigating")
	Do $$$AssertEquals(##class(SignalNoir.Tests.Support).Count("SELECT COUNT(*) FROM SignalNoir_Application_Model.CaseRecord WHERE orderId = ?", orderId), 1, "no second Case")
	; in Investigating a further Exception is an attachment only
	Set v = g.obj.caseVersion
	Set r3 = svc.RecordException(orderId, ##class(SignalNoir.Tests.Support).Exception("timeout"))
	Do $$$AssertEquals(r3.details.route, "attach", "attach only while investigating")
	Do $$$AssertEquals(svc.GetCase(caseId).obj.caseVersion, v, "caseVersion unchanged")
}

Method TestExceptionDuringApprovedIsAttachmentOnly()
{
	Set svc = ##class(SignalNoir.Application.CaseService).Default()
	Set orderId = ##class(SignalNoir.Tests.Support).Uid("approved")
	Set caseId = ##class(SignalNoir.Tests.Support).OpenCase(svc, orderId)
	Do $$$AssertEquals(##class(SignalNoir.Tests.Support).DriveTo(svc, caseId, "Approved"), "", "walked to Approved")
	Set before = svc.GetCase(caseId).obj
	Set r = svc.RecordException(orderId, ##class(SignalNoir.Tests.Support).Exception("timeout"))
	Do $$$AssertEquals(r.details.route, "attach", "attachment")
	Set after = svc.GetCase(caseId).obj
	Do $$$AssertEquals(after.state, "Approved", "state unchanged")
	Do $$$AssertEquals(after.caseVersion, before.caseVersion, "caseVersion unchanged")
	Do $$$AssertEquals(after.lastEventSeq, before.lastEventSeq + 1, "Timeline advanced")
	Do $$$AssertEquals(after.exceptions.GetAt(2).duringExecution, 1, "marked during execution")
}

Method TestExceptionAfterTerminalOpensRelatedCase()
{
	Set svc = ##class(SignalNoir.Application.CaseService).Default()
	Set orderId = ##class(SignalNoir.Tests.Support).Uid("episode")
	Set old = ##class(SignalNoir.Tests.Support).OpenCase(svc, orderId)
	Do $$$AssertEquals(##class(SignalNoir.Tests.Support).DriveTo(svc, old, "Cancelled"), "", "walked to Cancelled")
	Set oldBefore = svc.GetCase(old).obj
	Set r = svc.RecordException(orderId, ##class(SignalNoir.Tests.Support).Exception())
	Do $$$AssertEquals(r.details.route, "open", "new episode")
	Do $$$AssertTrue(r.ref '= old, "a new Case")
	Set opened = svc.GetTimeline(r.ref, 0).list.GetAt(1)
	Do $$$AssertEquals(opened.payload.previousCaseId, old, "references the previous Case")
	Do $$$AssertEquals(svc.GetCase(r.ref).obj.previousCaseId, old, "link on the Case")
	Set oldAfter = svc.GetCase(old).obj
	Do $$$AssertEquals(oldAfter.state, "Cancelled", "previous Case stays terminal")
	Do $$$AssertEquals(oldAfter.lastEventSeq, oldBefore.lastEventSeq, "previous Timeline unchanged")
}

Method TestTwoOrdersTwoCases()
{
	Set svc = ##class(SignalNoir.Application.CaseService).Default()
	Set a = ##class(SignalNoir.Tests.Support).OpenCase(svc, ##class(SignalNoir.Tests.Support).Uid("two-a"))
	Set b = ##class(SignalNoir.Tests.Support).OpenCase(svc, ##class(SignalNoir.Tests.Support).Uid("two-b"))
	Do $$$AssertTrue((a '= "") && (b '= "") && (a '= b), "two Cases")
}

}
