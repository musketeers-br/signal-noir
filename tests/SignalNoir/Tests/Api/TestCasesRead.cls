Class SignalNoir.Tests.Api.TestCasesRead Extends %UnitTest.TestCase
{

/// T026 - Case read test: the payloads behind GET /cases and GET /cases/{caseId}
/// carry the Case with labels.synthetic=true, caseVersion, lastEventSeq and
/// serverTime, exactly as contracts/openapi-signalnoir.yaml requires.
/// No HTTP is needed: the dispatch payload builders are called directly.
Method TestListCasesPayloadMatchesContract()
{
	Set svc = ##class(SignalNoir.Application.CaseService).Default()
	Set r = svc.ListCases("")
	Do $$$AssertTrue(r.ok, "ListCases ok")
	Set payload = ##class(SignalNoir.Api.Dispatch).ListPayload(r)
	Do $$$AssertTrue($IsObject(payload), "list payload is an object")
	Do $$$AssertTrue($IsObject(payload.items), "items array present")
	Do $$$AssertTrue(payload.serverTime '= "", "serverTime present")
	Do $$$AssertTrue(payload.headCursor '= "", "headCursor present")
	If payload.items.%Size() > 0 {
		Set item = payload.items.%Get(0)
		Do $$$AssertTrue(item.caseId '= "", "item caseId present")
		Do $$$AssertTrue(item.state '= "", "item state present")
		Do $$$AssertTrue($IsObject(item.labels), "item labels object present")
		Do $$$AssertEquals(item.labels.synthetic, 1, "item labels.synthetic is true in this slice")
		Do $$$AssertEquals(item.labels.replay, 0, "item labels.replay is false in this slice")
		Do $$$AssertTrue(item.caseVersion > 0, "item caseVersion present")
		Do $$$AssertTrue(item.lastEventAt '= "", "item lastEventAt present")
		Do $$$AssertTrue((item.pendingApproval = 0) || (item.pendingApproval = 1), "item pendingApproval boolean")
	}
}

Method TestCasePayloadMatchesContract()
{
	Set svc = ##class(SignalNoir.Application.CaseService).Default()
	Set r = ##class(SignalNoir.Tests.Application.TestPersistence).Open(svc, ##class(SignalNoir.Tests.Support).Uid("T026-get"))
	Do $$$AssertTrue(r.ok, "order accepted")
	If 'r.ok Return
	Set caseId = r.ref

	Set g = svc.GetCase(caseId)
	Do $$$AssertTrue(g.ok, "case readable")
	Set payload = ##class(SignalNoir.Api.Dispatch).CasePayload(g.obj)
	Do $$$AssertEquals(payload.caseId, caseId, "caseId matches")
	Do $$$AssertTrue(payload.orderId '= "", "orderId present")
	Do $$$AssertEquals(payload.state, "Open", "state is Open")
	Do $$$AssertEquals(payload.labels.synthetic, 1, "labels.synthetic is true in this slice")
	Do $$$AssertEquals(payload.labels.replay, 0, "labels.replay is false in this slice")
	Do $$$AssertTrue(payload.caseVersion > 0, "caseVersion present")
	Do $$$AssertTrue(payload.lastEventSeq >= 2, "lastEventSeq covers CaseOpened and ExceptionRecorded")
	Do $$$AssertTrue(payload.createdAt '= "", "createdAt present")
	Do $$$AssertTrue(payload.lastEventAt '= "", "lastEventAt present")
	Do $$$AssertTrue(payload.serverTime '= "", "serverTime present")
}

Method TestNotFoundUsesTheClosedEnvelope()
{
	Set r = ##class(SignalNoir.Application.CaseService).Default().GetCase("case_missing")
	Do $$$AssertTrue(r.ok = 0, "missing case is refused, not raised")
	Do $$$AssertEquals(r.code, "NOT_FOUND", "NOT_FOUND from the closed vocabulary")
	Set payload = ##class(SignalNoir.Api.Dispatch).ErrorPayload(r.code, r.message)
	Do $$$AssertEquals(payload.error.code, "NOT_FOUND", "envelope code")
	Do $$$AssertTrue(payload.error.message '= "", "envelope message")
	Do $$$AssertTrue($IsObject(payload.error.details), "envelope details object")
}

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

}
