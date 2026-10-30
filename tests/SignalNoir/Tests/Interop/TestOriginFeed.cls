Class SignalNoir.Tests.Interop.TestOriginFeed Extends %UnitTest.TestCase
{

/// The inbound path over HTTP (FR-1..3): the Origin feed is read, each Order
/// is accepted and delivered once to the Partner; a failed attempt opens a
/// Case. Uses the Simulator only over HTTP (Constitution I).
Parameter SIM = "http://localhost:52773/sim/api/v1";

Property Reader As SignalNoir.Interop.Service.OriginFeed;

Property Ready As %Boolean;

Method OnBeforeAllTests() As %Status
{
	Set ..Reader = ##class(SignalNoir.Interop.Service.OriginFeed).%New()
	Set ..Reader.Base = ..#SIM, ..Reader.Cursor = "test-" _ $Job, ..Reader.Dispatch = 0, ..Reader.TimeoutSeconds = 10
	Set ..Ready = ..Reader.SkipToHead().ok
	Return $$$OK
}

Method OnAfterAllTests() As %Status
{
	Kill ^SignalNoir.Interop.Feed("test-" _ $Job)
	Return $$$OK
}

/// Creates and emits a Simulator instance over HTTP; returns its emitted Order
ClassMethod Emit(family As %String, variant As %String, seed As %Integer) As %DynamicObject
{
	Set c = ..Post("/scenarios", {"family": (family), "variant": (variant), "seed": (seed)})
	Set e = ..Post("/scenarios/" _ c.scenarioInstanceId _ "/emissions", "")
	Return {"sci": (c.scenarioInstanceId), "order": (e.emitted.%Get(0).order)}
}

ClassMethod Post(path As %String, body) As %DynamicObject
{
	Set req = ##class(%Net.HttpRequest).%New()
	Set req.Server = "localhost", req.Port = 52773, req.Timeout = 10
	If $IsObject(body) Set req.ContentType = "application/json"  Do req.EntityBody.Write(body.%ToJSON())
	Do req.Post("/sim/api/v1" _ path)
	Return {}.%FromJSON(req.HttpResponse.Data)
}

Method TestCleanSuccessOpensNoCase()
{
	If '..Ready {
		Do $$$LogMessage("skipped: the Simulator is not reachable at " _ ..#SIM)
		Return
	}
	Set x = ..Emit("clean", "clean-success-tune-01", 3)
	Set r = ..Reader.Poll()
	Do $$$AssertTrue(r.ok, "polled: " _ r.message)
	Do $$$AssertEquals(r.details.read _ ":" _ r.details.delivered _ ":" _ r.details.exceptions, "1:1:0", "read, delivered with a receipt, no exception")
	Set svc = ##class(SignalNoir.Application.CaseService).Default()
	Do $$$AssertTrue(##class(SignalNoir.Application.Model.OrderRecord).%ExistsId(x.order.orderId), "the Order was accepted")
	Do $$$AssertEquals(##class(SignalNoir.Application.Model.OrderRecord).%OpenId(x.order.orderId).scenarioInstanceId, x.sci, "with its instance")
	Do $$$AssertNotTrue(svc.OpenCase(x.order.orderId).ok, "no Case without an exception")
	Do $$$AssertEquals(..Reader.Poll().details.read, 0, "the cursor moved on")
}

Method TestFailedDeliveryOpensACase()
{
	If '..Ready {
		Do $$$LogMessage("skipped: the Simulator is not reachable at " _ ..#SIM)
		Return
	}
	Set x = ..Emit("P5", "P5-tune-01", 4)
	Set r = ..Reader.Poll()
	Do $$$AssertEquals(r.details.read _ ":" _ r.details.exceptions, "1:1", "a failed attempt")
	Set svc = ##class(SignalNoir.Application.CaseService).Default()
	Set open = svc.OpenCase(x.order.orderId)
	Do $$$AssertTrue(open.ok, "a Case was opened")
	Set c = svc.GetCase(open.ref).obj
	Do $$$AssertEquals(c.partnerId, x.order.partnerId, "the partner of the Order")
	Do $$$AssertEquals(c.exceptions.Count(), 1, "one exception")
	Set ex = c.exceptions.GetAt(1)
	Do $$$AssertEquals(ex.kind _ ":" _ ex.httpStatus, "http_error:500", "the partner's 500")
	Do $$$AssertTrue(ex.body.%ToJSON() [ "GLIC-J", "the body, as received")
	Do $$$AssertTrue((c.state = "Investigating") || (c.state = "ReviewRequired"), "routed: " _ c.state)
	; delivered once: polling again does not deliver again
	Do $$$AssertEquals(..Reader.Poll().details.read, 0, "nothing new")
}

Method TestDeliveryKeyIsStable()
{
	Set a = ##class(SignalNoir.Interop.Service.OriginFeed).DeliveryKey("ORD-x-0001")
	Do $$$AssertEquals(a, ##class(SignalNoir.Interop.Service.OriginFeed).DeliveryKey("ORD-x-0001"), "same Order, same key")
	Do $$$AssertTrue(a '= ##class(SignalNoir.Interop.Service.OriginFeed).DeliveryKey("ORD-x-0002"), "another Order, another key")
	Do $$$AssertTrue(($Length(a) >= 8) && ($Length(a) <= 128), "the Partner's key length")
}

}
