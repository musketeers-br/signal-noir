Class SignalNoir.Tests.Api.TestPrecedentsApi Extends %UnitTest.TestCase
{

/// 015 T013 - the PrecedentSearch payload and the error map
Method TestPayload()
{
	Set PS = "SignalNoir.Tests.Application.PrecedentSupport"
	Set svc = ##class(SignalNoir.Application.CaseService).Default()
	Set p = $ClassMethod(PS, "Service", svc)
	Set partner = ##class(SignalNoir.Tests.Support).Uid("PAPI")
	Do p.IndexCase($ClassMethod(PS, "FamilyCase", svc, partner, "timeout", "Resolved"))
	Set open = $ClassMethod(PS, "FamilyCase", svc, partner, "timeout", "")
	Set body = ##class(SignalNoir.Api.Dispatch).PrecedentsPayload(p.Search(open))
	For f = "caseId", "status", "mode", "model", "dimension", "k", "minSimilarity", "items", "recorded", "notice" {
		Do $$$AssertTrue(body.%IsDefined(f), "PrecedentSearch." _ f)
	}
	Do $$$AssertEquals(body.%GetTypeOf("recorded"), "boolean", "recorded is boolean")
	Do $$$AssertNotTrue(body.%IsDefined("reason"), "no reason on results")
	Set item = body.items.%Get(0)
	For f = "caseId", "orderId", "partnerId", "description", "action", "finalState", "closedAt", "durationSeconds", "similarity", "synthetic", "replay" {
		Do $$$AssertTrue(item.%IsDefined(f), "PrecedentMatch." _ f)
	}
	Do $$$AssertEquals(item.%GetTypeOf("synthetic"), "boolean", "synthetic is boolean")
	Do $$$AssertEquals(item.%GetTypeOf("similarity"), "number", "similarity is a number")
	Set p.Embedder.Fail = 1
	Set body = ##class(SignalNoir.Api.Dispatch).PrecedentsPayload(p.Search(open))
	Do $$$AssertEquals(body.status, "unavailable", "200 body says unavailable")
	Do $$$AssertEquals(body.reason, "provider_unavailable", "with its reason")
	Do $$$AssertEquals(##class(SignalNoir.Api.Dispatch).HttpStatus(p.Search(open, 99).code), "400 Bad Request", "k out of range")
	Do $$$AssertEquals(##class(SignalNoir.Api.Dispatch).HttpStatus(p.Search("case_none").code), "404 Not Found", "unknown Case")
	Do $ClassMethod(PS, "Cleanup", p)
}

}
