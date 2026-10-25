Class SignalNoir.Tests.Application.TestProjections Extends %UnitTest.TestCase
{

/// 003 T041 - US5: list, detail and incremental Timeline. Lists are scoped by
/// a unique runId so other data in the namespace does not interfere.
Method TestListPagesOlderAndPollsNewer()
{
	Set svc = ##class(SignalNoir.Application.CaseService).Default()
	Set run = "run_" _ $Translate(##class(SignalNoir.Tests.Support).Uid("p"), "-", "_")
	For i = 1 : 1 : 5 {
		Set ids(i) = ##class(SignalNoir.Tests.Support).OpenCase(svc, ##class(SignalNoir.Tests.Support).Uid("list"), run)
		Hang 0.01
	}
	Set filters = {"runId": (run)}
	Set seen = 0, cursor = "", pages = 0
	Kill got
	For {
		Set r = svc.ListCases(cursor, "older", 2, filters)
		Do $$$AssertTrue(r.ok, "page read")
		Quit:'r.ok
		Set pages = pages + 1
		For i = 1 : 1 : r.list.Count() {
			Set s = r.list.GetAt(i)
			Set got(s.caseId) = $Get(got(s.caseId)) + 1
			Set seen = seen + 1
			Set order(seen) = s.caseId
		}
		Set cursor = r.details.nextCursor
		Quit:cursor=""
		Quit:pages>5
	}
	Do $$$AssertEquals(seen, 5, "every Case once")
	Do $$$AssertEquals(pages, 3, "pages of 2")
	Do $$$AssertEquals(order(1), ids(5), "newest first")
	Do $$$AssertEquals(order(5), ids(1), "oldest last")
	Set head = r.details.headCursor
	Do $$$AssertTrue(head '= "", "head cursor")
	; poll for newer: touch two Cases
	Hang 0.01
	Do svc.Transition(ids(2), 1, "Investigating", "system", ##class(SignalNoir.Tests.Support).Ev())
	Hang 0.01
	Do svc.Transition(ids(4), 1, "Investigating", "system", ##class(SignalNoir.Tests.Support).Ev())
	Set p = svc.ListCases(head, "newer", 50, filters)
	Do $$$AssertEquals(p.list.Count(), 2, "the two changed Cases")
	Do $$$AssertEquals(p.list.GetAt(1).caseId, ids(2), "oldest change first")
	Do $$$AssertEquals(p.list.GetAt(2).caseId, ids(4), "then the newer")
	Do $$$AssertTrue(p.details.headCursor '= head, "head moved")
	Do $$$AssertEquals(svc.ListCases(p.details.headCursor, "newer", 50, filters).list.Count(), 0, "nothing newer")
}

Method TestListFiltersAndBadCursor()
{
	Set svc = ##class(SignalNoir.Application.CaseService).Default()
	Set run = "run_" _ $Translate(##class(SignalNoir.Tests.Support).Uid("f"), "-", "_")
	Set a = ##class(SignalNoir.Tests.Support).OpenCase(svc, ##class(SignalNoir.Tests.Support).Uid("fa"), run)
	Set b = ##class(SignalNoir.Tests.Support).OpenCase(svc, ##class(SignalNoir.Tests.Support).Uid("fb"), run)
	Set c = ##class(SignalNoir.Tests.Support).OpenCase(svc, ##class(SignalNoir.Tests.Support).Uid("fc"), run)
	Do ##class(SignalNoir.Tests.Support).DriveTo(svc, b, "PendingApproval")
	Do ##class(SignalNoir.Tests.Support).DriveTo(svc, c, "Cancelled")
	Do $$$AssertEquals(svc.ListCases("", "older", 50, {"runId": (run), "state": ["PendingApproval"]}).list.Count(), 1, "state filter")
	Do $$$AssertEquals(svc.ListCases("", "older", 50, {"runId": (run), "pendingApproval": true}).list.GetAt(1).caseId, b, "pendingApproval filter")
	Do $$$AssertEquals(svc.ListCases("", "older", 50, {"runId": (run), "status": "terminal"}).list.Count(), 1, "terminal")
	Do $$$AssertEquals(svc.ListCases("", "older", 50, {"runId": (run), "status": "open"}).list.Count(), 2, "open")
	Do $$$AssertEquals(svc.ListCases("garbage!", "older", 50, {}).code, "VALIDATION_FAILED", "bad cursor refused")
	Do $$$AssertEquals(svc.ListCases("", "sideways", 50, {}).code, "VALIDATION_FAILED", "bad direction")
	Do $$$AssertEquals(svc.ListCases("", "older", 0, {}).code, "VALIDATION_FAILED", "bad limit")
	Do $$$AssertEquals(svc.ListCases("", "older", 50, {"state": ["Sleeping"]}).code, "VALIDATION_FAILED", "unknown state")
	Set s = svc.ListCases("", "older", 50, {"runId": (run), "state": ["Open"]}).list.GetAt(1)
	Do $$$AssertEquals(s.caseId, a, "summary of a")
	Do $$$AssertEquals(s.exceptionCount, 1, "exceptionCount")
	Do $$$AssertEquals(s.lastExceptionSummary, "timeout", "lastExceptionSummary")
	Do $$$AssertEquals(s.synthetic, 1, "synthetic")
	Do $$$AssertTrue(s.partnerId '= "", "partnerId")
}

Method TestDetailAndTimelinePaging()
{
	Set svc = ##class(SignalNoir.Application.CaseService).Default()
	Set orderId = ##class(SignalNoir.Tests.Support).Uid("detail")
	Set caseId = ##class(SignalNoir.Tests.Support).OpenCase(svc, orderId)
	Do ##class(SignalNoir.Tests.Support).DriveTo(svc, caseId, "PendingApproval")
	Set d = svc.GetCase(caseId).obj
	Do $$$AssertEquals(d.order.orderId, orderId, "order view")
	Do $$$AssertEquals(d.order.transactionIds.Count(), 1, "transaction ids")
	Do $$$AssertTrue($IsObject(d.order.snapshot), "snapshot")
	Do $$$AssertEquals(d.exceptions.Count(), 1, "exceptions")
	Do $$$AssertEquals(d.synthetic, 1, "synthetic")
	Do $$$AssertEquals(d.denialCount, 0, "denialCount")
	Set all = svc.GetTimeline(caseId, 0, 2)
	Do $$$AssertEquals(all.list.Count(), 2, "limit")
	Do $$$AssertEquals(all.details.hasMore, 1, "more remain")
	Do $$$AssertEquals(all.details.nextSinceSeq, 2, "next since")
	Set rest = svc.GetTimeline(caseId, 2, 200)
	Do $$$AssertEquals(rest.list.GetAt(1).seq, 3, "continues after 2")
	Do $$$AssertEquals(rest.details.hasMore, 0, "no more")
	Do $$$AssertEquals(rest.details.nextSinceSeq, d.lastEventSeq, "ends at the watermark")
	Set none = svc.GetTimeline(caseId, d.lastEventSeq)
	Do $$$AssertEquals(none.list.Count(), 0, "nothing after the last")
	Do $$$AssertEquals(none.details.nextSinceSeq, d.lastEventSeq, "echoes sinceSeq")
	Do $$$AssertEquals(svc.GetTimeline(caseId, -1).code, "VALIDATION_FAILED", "negative sinceSeq")
	Do $$$AssertEquals(svc.GetTimeline(caseId, "x").code, "VALIDATION_FAILED", "non-numeric sinceSeq")
	Do $$$AssertEquals(svc.GetTimeline("case_nope", 0).code, "NOT_FOUND", "unknown case")
	Do $$$AssertEquals(svc.GetCase("case_nope").code, "NOT_FOUND", "unknown case detail")
}

/// SC-005: an event confirmed late is never skipped by an incremental reader
Method TestLateConfirmationIsNeverSkipped()
{
	Set svc = ##class(SignalNoir.Application.CaseService).Default()
	Set caseId = ##class(SignalNoir.Tests.Support).OpenCase(svc, ##class(SignalNoir.Tests.Support).Uid("late"))
	Set start = svc.GetCase(caseId).obj.lastEventSeq
	Set key = "late-" _ $JOB _ "-" _ $Increment(^SignalNoir.TestSeq)
	Job ##class(SignalNoir.Tests.Support).SlowAppend(key, caseId, 2)
	For i = 1 : 1 : 500 {
		Quit:$Data(^SignalNoir.TestRace(key, "appended"))
		Hang 0.01
	}
	Do $$$AssertTrue(+$Get(^SignalNoir.TestRace(key, "appended")) = (start + 1), "the slow writer holds seq " _ (start + 1))
	; a reader polling now must not see the uncommitted event, and must not
	; see anything that would let it skip it later
	Set poll = svc.GetTimeline(caseId, start)
	Set committed = $Get(^SignalNoir.TestRace(key, "committed"))
	If 'committed {
		Do $$$AssertEquals(poll.list.Count(), 0, "uncommitted event not visible")
	} Else {
		Do $$$AssertEquals(poll.list.Count(), 1, "visible only once committed")
	}
	Do ##class(SignalNoir.Tests.Support).WaitResults(key, 2)
	Set after = svc.GetTimeline(caseId, poll.details.nextSinceSeq)
	Set total = poll.list.Count() + after.list.Count()
	Do $$$AssertEquals(total, 1, "the late event is read exactly once")
	Kill ^SignalNoir.TestRace(key)
}

}
