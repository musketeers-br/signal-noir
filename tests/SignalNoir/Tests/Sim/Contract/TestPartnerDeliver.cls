Class SignalNoir.Tests.Sim.Contract.TestPartnerDeliver Extends %UnitTest.TestCase
{

/// 002 T031 - deliveries, deduplication before the script, refusals (US2)
Method OnBeforeAllTests() As %Status
{
	Return ##class(SignalNoir.Sim.Setup).EnsureWebApplication()
}

Method TestSuccessAndReplay()
{
	Set C = "SignalNoir.Tests.Sim.Contract.Client"
	Set x = $ClassMethod(C, "Emitted", "clean", "clean-success-tune-01", 11)
	Set order = x.orders.%Get(0), key = "idk_" _ $Extract(x.sci, 5, 20)
	Set path = "/partners/" _ x.partnerId _ "/orders"
	Set r = $ClassMethod(C, "Call", "POST", path, $ClassMethod(C, "Delivery", x.sci, order, key))
	Do $$$AssertEquals(r.status, 200, "accepted")
	Do $ClassMethod(C, "Capture", "deliver.200.receipt", "deliverOrder", 200, "PartnerResponseBody", r.body)
	Do $$$AssertEquals(r.body.orderId _ ":" _ r.body.idempotencyKey, order.orderId _ ":" _ key, "receipt matches the delivery")
	Do $$$AssertEquals(r.body.partnerId, x.partnerId, "partner")
	; same key + same payload, another transaction and a mappingRef: the original receipt
	Set again = $ClassMethod(C, "Delivery", x.sci, {}.%FromJSON(..Reordered(order)), key, "txn-test-2")
	Set again.mappingRef = {"mappingId": "m", "mappingVersion": "1"}
	Set d = $ClassMethod(C, "Call", "POST", path, again)
	Do $$$AssertEquals(d.status _ ":" _ d.body.receiptId, "200:" _ r.body.receiptId, "replay of the original receipt")
	Do $$$AssertEquals(d.replayed, "true", "Idempotent-Replayed")
	Do $ClassMethod(C, "Capture", "deliver.200.replay", "deliverOrder", 200, "PartnerResponseBody", d.body)
	; same key, different payload
	Set changed = {}.%FromJSON(order.%ToJSON())
	Set changed.exams = [{"code": "OTHER"}]
	Set k = $ClassMethod(C, "Call", "POST", path, $ClassMethod(C, "Delivery", x.sci, changed, key))
	Do $$$AssertEquals(k.status _ ":" _ k.body.error.code, "422:IDEMPOTENCY_KEY_REUSED", "key reuse refused")
	Do $$$AssertEquals(k.body.error.details.originalReceiptId, r.body.receiptId, "names the original receipt")
	Do $ClassMethod(C, "Capture", "deliver.422", "deliverOrder", 422, "ErrorEnvelope", k.body)
	Set h = $ClassMethod(C, "Call", "GET", "/partners/" _ x.partnerId _ "/history?scenarioInstanceId=" _ x.sci)
	Do $$$AssertEquals(h.body.items.%Get(0).outcome, "duplicate", "the replay is in the history")
	Do $$$AssertEquals(h.body.items.%Size(), 2, "the refused reuse is not a delivery")
}

Method TestDedupBeforeScript()
{
	Set C = "SignalNoir.Tests.Sim.Contract.Client"
	; attempt 1 is unavailable, attempt 3 accepts; a key that has a receipt replays even on a failing attempt
	Set x = $ClassMethod(C, "Emitted", "clean", "clean-unavailable-tune-01", 12)
	Set order = x.orders.%Get(0), path = "/partners/" _ x.partnerId _ "/orders"
	Set first = $ClassMethod(C, "Call", "POST", path, $ClassMethod(C, "Delivery", x.sci, order, "idk_a_" _ $Extract(x.sci, 5, 15)))
	Do $$$AssertEquals(first.status, 503, "unavailable")
	Do $ClassMethod(C, "Capture", "deliver.503", "deliverOrder", 503, "PartnerResponseBody", first.body)
	Do $ClassMethod(C, "Call", "POST", path, $ClassMethod(C, "Delivery", x.sci, order, "idk_b_" _ $Extract(x.sci, 5, 15)))
	Set ok = $ClassMethod(C, "Call", "POST", path, $ClassMethod(C, "Delivery", x.sci, order, "idk_c_" _ $Extract(x.sci, 5, 15)))
	Do $$$AssertEquals(ok.status, 200, "attempt 3 accepts")
	Set replay = $ClassMethod(C, "Call", "POST", path, $ClassMethod(C, "Delivery", x.sci, order, "idk_c_" _ $Extract(x.sci, 5, 15)))
	Do $$$AssertEquals(replay.status _ ":" _ replay.body.receiptId, "200:" _ ok.body.receiptId, "deduplication first")
}

Method TestRefusals()
{
	Set C = "SignalNoir.Tests.Sim.Contract.Client"
	Set x = $ClassMethod(C, "Emitted", "clean", "clean-success-tune-01", 13)
	Set order = x.orders.%Get(0), path = "/partners/" _ x.partnerId _ "/orders"
	Set short = $ClassMethod(C, "Call", "POST", path, $ClassMethod(C, "Delivery", x.sci, order, "short"))
	Do $$$AssertEquals(short.status _ ":" _ short.body.error.code, "400:INVALID_REQUEST", "key too short")
	Do $ClassMethod(C, "Capture", "deliver.400.invalid", "deliverOrder", 400, "ErrorEnvelope", short.body)
	Set noOrder = {"idempotencyKey": "idk_12345678", "transactionId": "t", "scenarioInstanceId": (x.sci)}
	Do $$$AssertEquals($ClassMethod(C, "Call", "POST", path, noOrder).status, 400, "no order")
	Set nf = $ClassMethod(C, "Call", "POST", path, $ClassMethod(C, "Delivery", "sci_doesnotexist", order, "idk_12345678"))
	Do $$$AssertEquals(nf.status _ ":" _ nf.body.error.code, "404:NOT_FOUND", "unknown instance")
	Do $ClassMethod(C, "Capture", "deliver.404", "deliverOrder", 404, "ErrorEnvelope", nf.body)
	Do $$$AssertEquals($ClassMethod(C, "Call", "POST", "/partners/labpartner-z/orders", $ClassMethod(C, "Delivery", x.sci, order, "idk_12345678")).status, 404, "partner of another instance")
	Set h = $ClassMethod(C, "Call", "GET", "/partners/" _ x.partnerId _ "/history?scenarioInstanceId=" _ x.sci)
	Do $$$AssertEquals(h.body.items.%Size(), 0, "no history for refused requests")
}

/// The same Order with its keys in another order (JSON text)
ClassMethod Reordered(order As %DynamicObject) As %String
{
	Kill keys
	Set it = order.%GetIterator()
	While it.%GetNext(.k, .v) {
		Set keys(k) = ""
	}
	Set out = {}, k = ""
	For {
		Set k = $Order(keys(k), -1)
		Quit:k=""
		Do out.%Set(k, order.%Get(k), $Select($IsObject(order.%Get(k)): "", 1: order.%GetTypeOf(k)))
	}
	Return out.%ToJSON()
}

}
