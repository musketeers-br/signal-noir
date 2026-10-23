Class SignalNoir.Tests.Application.TestCaseRestart Extends %UnitTest.TestCase
{

/// T027 - Restart durability: the Case and every timeline row are identical after re-opening.
/// Simulates a fresh process by killing the service reference and re-opening.

Method TestCaseAndTimelineSurviveReconnect()
{
	Set svc = ##class(SignalNoir.Application.CaseService).Default()
	Set order = ..MakeOrder("T027-restart-" _ $JOB)
	Set r = svc.AcceptOrder(order)
	Do $$$AssertTrue(r.ok, "order accepted")
	If 'r.ok Return
	Set caseId = r.ref

	; snapshot what we read through the queries
	Set before = svc.GetCase(caseId)
	Do $$$AssertTrue(before.ok, "case readable")
	Set tl = svc.GetTimeline(caseId, 0)
	Do $$$AssertTrue(tl.ok, "timeline readable")
	Set beforeJson = ..TimelineJson(tl.list)
	Do $$$AssertEquals(tl.list.Count(), 2, "two timeline rows after opening")

	; simulate a reconnect: drop every in-memory reference and re-open
	Kill svc, before, tl
	Set svc2 = ##class(SignalNoir.Application.CaseService).Default()
	Set after = svc2.GetCase(caseId)
	Do $$$AssertTrue(after.ok, "case readable after reconnect")
	Do $$$AssertEquals(after.obj.caseId, caseId, "same caseId")
	Do $$$AssertEquals(after.obj.orderId, order.orderId, "same orderId")
	Do $$$AssertEquals(after.obj.state, "Open", "same state")
	Do $$$AssertEquals(after.obj.caseVersion, 1, "same caseVersion")
	Do $$$AssertEquals(after.obj.lastEventSeq, 2, "same lastEventSeq (OrderAccepted and CaseOpened)")

	Set tl2 = svc2.GetTimeline(caseId, 0)
	Do $$$AssertTrue(tl2.ok, "timeline readable after reconnect")
	Do $$$AssertEquals(..TimelineJson(tl2.list), beforeJson, "timeline identical after reconnect")
}

/// A minimal synthetic Order helper.

ClassMethod MakeOrder(orderId As %String) As SignalNoir.Core.Dto.Order
{
	Set order = ##class(SignalNoir.Core.Dto.Order).%New()
	Set order.orderId = orderId
	Set snapshot = ##class(%DynamicObject).%New()
	Do snapshot.%Set("patientId", "P-" _ orderId)
	Set exams = ##class(%DynamicArray).%New()
	Do exams.%Push("GLICJ")
	Do snapshot.%Set("exams", exams)
	Set order.snapshot = snapshot
	Set order.equivalenceKey = "P-" _ orderId _ "|glicj|2026-10-23T10:00:00Z|SP-1"
	Set order.receivedAt = ##class(SignalNoir.Application.SystemClock).%New().NowUtc()
	Set order.synthetic = 1
	Return order
}

/// Serialize timeline to a JSON string for comparison.

ClassMethod TimelineJson(list As %ListOfObjects) As %String
{
	Set out = "["
	For i = 1 : 1 : list.Count() {
		Set ev = list.GetAt(i)
		If i > 1 Set out = out _ ","
		Set out = out _ ev.seq _ "|" _ ev.type _ "|" _ ev.actor _ "|" _ ev.refId
	}
	Return out _ "]"
}

}