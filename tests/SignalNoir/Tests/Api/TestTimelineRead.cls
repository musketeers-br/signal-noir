Class SignalNoir.Tests.Api.TestTimelineRead Extends %UnitTest.TestCase
{

/// 003 T042 - payload builders for CaseListPage, CaseDetail, TimelinePage and
/// the error envelope (contract openapi-signalnoir.yaml)
Method TestTimelinePagePayload()
{
	Set svc = ##class(SignalNoir.Application.CaseService).Default()
	Set caseId = ##class(SignalNoir.Tests.Support).OpenCase(svc, ##class(SignalNoir.Tests.Support).Uid("api-tl"))
	Set r = svc.GetTimeline(caseId, 0, 1)
	Set p = ##class(SignalNoir.Api.Dispatch).TimelinePayload(caseId, r)
	For f = "caseId", "state", "events", "hasMore", "nextSinceSeq", "caseVersion", "lastEventSeq", "serverTime" {
		Do $$$AssertTrue(p.%IsDefined(f), "TimelinePage." _ f)
	}
	Do $$$AssertEquals(p.%GetTypeOf("hasMore"), "boolean", "hasMore is boolean")
	Set ev = p.events.%Get(0)
	Do $$$AssertEquals(p.events.%GetTypeOf(0) = "object" && (ev.%GetTypeOf("seq") = "number"), 1, "seq is a JSON integer")
	For f = "seq", "at", "type", "actor", "refId", "payload" {
		Do $$$AssertTrue(ev.%IsDefined(f), "TimelineEvent." _ f)
	}
}

Method TestDetailPayload()
{
	Set svc = ##class(SignalNoir.Application.CaseService).Default()
	Set caseId = ##class(SignalNoir.Tests.Support).OpenCase(svc, ##class(SignalNoir.Tests.Support).Uid("api-d"))
	Set p = ##class(SignalNoir.Api.Dispatch).CasePayload(svc.GetCase(caseId).obj)
	For f = "caseId", "orderId", "partnerId", "state", "labels", "createdAt", "lastEventAt", "caseVersion", "lastEventSeq", "serverTime", "updatedAt", "order", "exceptions", "evidence", "proposals", "approvals", "executions", "metrics", "denialCount", "currentProposalId", "diagnosis", "receipt", "dossier" {
		Do $$$AssertTrue(p.%IsDefined(f), "CaseDetail." _ f)
	}
	Do $$$AssertEquals(p.labels.%GetTypeOf("synthetic"), "boolean", "synthetic is boolean")
	Do $$$AssertEquals(p.labels.synthetic, 1, "synthetic true")
	For f = "orderId", "correlationId", "snapshot", "equivalenceKey", "transactionIds" {
		Do $$$AssertTrue(p.order.%IsDefined(f), "OrderView." _ f)
	}
	Do $$$AssertEquals(p.order.equivalenceKey.examCodes.%Size(), 2, "key parts")
	Set ex = p.exceptions.%Get(0)
	For f = "exceptionId", "kind", "observedAt" {
		Do $$$AssertTrue(ex.%IsDefined(f), "CaseException." _ f)
	}
}

Method TestErrorStatusMap()
{
	Do $$$AssertEquals(##class(SignalNoir.Api.Dispatch).HttpStatus("VALIDATION_FAILED"), "400 Bad Request", "400")
	Do $$$AssertEquals(##class(SignalNoir.Api.Dispatch).HttpStatus("NOT_FOUND"), "404 Not Found", "404")
	Do $$$AssertEquals(##class(SignalNoir.Api.Dispatch).HttpStatus("INVALID_ACTOR"), "403 Forbidden", "403")
	Do $$$AssertEquals(##class(SignalNoir.Api.Dispatch).HttpStatus("STALE_VERSION"), "409 Conflict", "409 stale")
	Do $$$AssertEquals(##class(SignalNoir.Api.Dispatch).HttpStatus("INVALID_TRANSITION"), "409 Conflict", "409 transition")
	Do $$$AssertEquals(##class(SignalNoir.Api.Dispatch).HttpStatus(""), "500 Internal Server Error", "internal")
}

}
