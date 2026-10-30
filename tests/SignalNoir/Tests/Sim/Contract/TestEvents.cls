Class SignalNoir.Tests.Sim.Contract.TestEvents Extends %UnitTest.TestCase
{

/// 002 T056 - explicit world changes (US5)
Method OnBeforeAllTests() As %Status
{
	Return ##class(SignalNoir.Sim.Setup).EnsureWebApplication()
}

Method TestDegrades()
{
	Set C = "SignalNoir.Tests.Sim.Contract.Client"
	Set x = $ClassMethod(C, "Emitted", "P3", "P3-fails-tune-01", 111)
	Set other = $ClassMethod(C, "Emitted", "P3", "P3-fails-tune-01", 111)
	Set e = $ClassMethod(C, "Call", "POST", "/scenarios/" _ x.sci _ "/events", {"type": "PARTNER_DEGRADES"})
	Do $$$AssertEquals(e.status, 202, "applied")
	Do $ClassMethod(C, "Capture", "events.202", "injectScenarioEvent", 202, "ScenarioInstance", e.body)
	Do $$$AssertEquals(e.body.phase, "partner_degraded", "phase")
	Do $$$AssertEquals(e.body.appliedEvents.%Get(0).type, "PARTNER_DEGRADES", "applied events")
	Set h = $ClassMethod(C, "Call", "GET", "/partners/" _ x.partnerId _ "/health?scenarioInstanceId=" _ x.sci)
	Do $$$AssertEquals(h.body.status, "DEGRADED", "health reflects it")
	Set hist = $ClassMethod(C, "Call", "GET", "/partners/" _ x.partnerId _ "/history?scenarioInstanceId=" _ x.sci)
	Do $$$AssertTrue(hist.body.window.errorRate > 0, "history reflects it before any delivery")
	Do $$$AssertNotTrue(hist.body.items.%Get(0).%IsDefined("orderId"), "third-party traffic has no order")
	Set d = $ClassMethod(C, "Call", "POST", "/partners/" _ x.partnerId _ "/orders", $ClassMethod(C, "Delivery", x.sci, x.orders.%Get(0), "idk_ev_" _ $Extract(x.sci, 5, 20)))
	Do $$$AssertEquals(d.status, 503, "the next delivery fails as scripted")
	Set o = $ClassMethod(C, "Call", "GET", "/partners/" _ other.partnerId _ "/health?scenarioInstanceId=" _ other.sci)
	Do $$$AssertEquals(o.body.status, "UP", "another instance is untouched")
	Set r = $ClassMethod(C, "Call", "POST", "/scenarios/" _ x.sci _ "/events", {"type": "PARTNER_RECOVERS"})
	Do $$$AssertEquals(r.body.phase, "partner_recovered", "recovers")
	; (a health read now would be this variant's 2nd: its scripted trigger degrades it again)
	Set d = $ClassMethod(C, "Call", "POST", "/partners/" _ x.partnerId _ "/orders", $ClassMethod(C, "Delivery", x.sci, x.orders.%Get(0), "idk_rec_" _ $Extract(x.sci, 5, 20)))
	Do $$$AssertEquals(d.status, 200, "back to the base script after the recovery")
}

Method TestMaintenanceAndCancel()
{
	Set C = "SignalNoir.Tests.Sim.Contract.Client"
	Set x = $ClassMethod(C, "Emitted", "P3", "P3-maintenance-tune-01", 112)
	Do $ClassMethod(C, "Call", "POST", "/scenarios/" _ x.sci _ "/events", {"type": "MAINTENANCE_STARTS"})
	Set h = $ClassMethod(C, "Call", "GET", "/partners/" _ x.partnerId _ "/health?scenarioInstanceId=" _ x.sci)
	Do $$$AssertEquals(h.body.maintenance.active, 1, "maintenance announced")
	Do $$$AssertTrue((h.body.maintenance.startsAt '= "") && (h.body.maintenance.endsAt ]] h.body.maintenance.startsAt), "with its window")
	Do $ClassMethod(C, "Capture", "health.200.maintenance", "getPartnerHealth", 200, "PartnerHealth", h.body)
	Set y = $ClassMethod(C, "Emitted", "P3", "P3-cancelled-tune-01", 113)
	Set orderId = y.orders.%Get(0).orderId
	Do $$$AssertEquals($ClassMethod(C, "Call", "POST", "/scenarios/" _ y.sci _ "/events", {"type": "ORDER_CANCELLED_AT_ORIGIN"}).status, 400, "orderId required")
	Set bad = $ClassMethod(C, "Call", "POST", "/scenarios/" _ y.sci _ "/events", {"type": "ORDER_CANCELLED_AT_ORIGIN", "orderId": (x.orders.%Get(0).orderId)})
	Do $$$AssertEquals(bad.status, 400, "an Order of another instance")
	Do $ClassMethod(C, "Capture", "events.400", "injectScenarioEvent", 400, "ErrorEnvelope", bad.body)
	Do $$$AssertEquals($ClassMethod(C, "Call", "GET", "/origin/orders/" _ x.orders.%Get(0).orderId).body.status, "active", "the other instance's Order is untouched")
	Do $ClassMethod(C, "Call", "POST", "/scenarios/" _ y.sci _ "/events", {"type": "ORDER_CANCELLED_AT_ORIGIN", "orderId": (orderId)})
	Set s = $ClassMethod(C, "Call", "GET", "/origin/orders/" _ orderId)
	Do $$$AssertEquals(s.body.status, "cancelled", "cancelled")
	Do $$$AssertTrue((s.body.statusChangedAt '= "") && (s.body.reason '= ""), "when and why")
	Do $ClassMethod(C, "Capture", "origin.order-status.200.cancelled", "getOriginOrderStatus", 200, "OriginOrderStatus", s.body)
	Set nf = $ClassMethod(C, "Call", "POST", "/scenarios/sci_doesnotexist/events", {"type": "PARTNER_DEGRADES"})
	Do $$$AssertEquals(nf.status, 404, "unknown instance")
	Do $ClassMethod(C, "Capture", "events.404", "injectScenarioEvent", 404, "ErrorEnvelope", nf.body)
}

}
