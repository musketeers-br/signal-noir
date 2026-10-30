Class SignalNoir.Tests.Sim.Contract.TestPartnerEvidence Extends %UnitTest.TestCase
{

/// 002 T049 - health says one thing, history another (US4)
Method OnBeforeAllTests() As %Status
{
	Set ^SignalNoir.Sim.Config("clientTimeoutSeconds") = 1
	Return ##class(SignalNoir.Sim.Setup).EnsureWebApplication()
}

Method OnAfterAllTests() As %Status
{
	Kill ^SignalNoir.Sim.Config("clientTimeoutSeconds")
	Return $$$OK
}

Method TestP8aContradiction()
{
	Set C = "SignalNoir.Tests.Sim.Contract.Client"
	Set x = $ClassMethod(C, "Emitted", "P8", "P8a-tune-01", 91, 0.01)
	Set order = x.orders.%Get(0), path = "/partners/" _ x.partnerId _ "/orders"
	For n = 1, 2 Do $ClassMethod(C, "Call", "POST", path, $ClassMethod(C, "Delivery", x.sci, order, "idk_p8a_" _ n _ $Extract(x.sci, 5, 15)), 1)
	Set h = $ClassMethod(C, "Call", "GET", "/partners/" _ x.partnerId _ "/health?scenarioInstanceId=" _ x.sci)
	Do $$$AssertEquals(h.status _ ":" _ h.body.status, "200:UP", "health says UP")
	Do $ClassMethod(C, "Capture", "health.200", "getPartnerHealth", 200, "PartnerHealth", h.body)
	Set hist = $ClassMethod(C, "Call", "GET", "/partners/" _ x.partnerId _ "/history?scenarioInstanceId=" _ x.sci)
	Do $$$AssertEquals(hist.status, 200, "history")
	Do $ClassMethod(C, "Capture", "history.200", "getPartnerHistory", 200, "PartnerHistory", hist.body)
	Do $$$AssertEquals(hist.body.window.timeouts _ "/" _ hist.body.window.total, "2/2", "every call timed out")
	Do $$$AssertEquals(hist.body.window.errorRate, 1, "error rate 1")
	Do $$$AssertEquals(hist.body.items.%Get(0).%GetTypeOf("httpStatus"), "null", "no status on a timeout")
	Set first = hist.body.items.%Get(0).at, second = hist.body.items.%Get(1).at
	Do $$$AssertTrue(first ]] second || (first = second), "newest first")
	Set one = $ClassMethod(C, "Call", "GET", "/partners/" _ x.partnerId _ "/history?scenarioInstanceId=" _ x.sci _ "&orderId=" _ order.orderId)
	Do $$$AssertEquals(one.body.items.%Size(), 2, "filtered by orderId")
	Set later = $ClassMethod(C, "Call", "GET", "/partners/" _ x.partnerId _ "/history?scenarioInstanceId=" _ x.sci _ "&since=2099-01-01T00:00:00Z")
	Do $$$AssertEquals(later.body.window.total, 0, "since filters the window")
	Set bad = $ClassMethod(C, "Call", "GET", "/partners/" _ x.partnerId _ "/health")
	Do $$$AssertEquals(bad.status, 400, "instance required")
	Do $ClassMethod(C, "Capture", "health.400", "getPartnerHealth", 400, "ErrorEnvelope", bad.body)
	Set nf = $ClassMethod(C, "Call", "GET", "/partners/" _ x.partnerId _ "/history?scenarioInstanceId=sci_doesnotexist")
	Do $$$AssertEquals(nf.status, 404, "unknown instance")
	Do $ClassMethod(C, "Capture", "history.404", "getPartnerHistory", 404, "ErrorEnvelope", nf.body)
	Do $$$AssertEquals($ClassMethod(C, "Call", "GET", "/partners/labpartner-z/health?scenarioInstanceId=" _ x.sci).status, 404, "another partner")
}

}
