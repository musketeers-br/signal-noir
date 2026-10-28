Class SignalNoir.Tests.Sim.Contract.TestReceipts Extends %UnitTest.TestCase
{

/// 002 T043 - receipt search and read (US3)
Method OnBeforeAllTests() As %Status
{
	Return ##class(SignalNoir.Sim.Setup).EnsureWebApplication()
}

Method TestSearchAndRead()
{
	Set C = "SignalNoir.Tests.Sim.Contract.Client"
	Set x = $ClassMethod(C, "Emitted", "clean", "clean-success-tune-01", 71)
	Set order = x.orders.%Get(0), key = "idk_rcp_" _ $Extract(x.sci, 5, 20)
	Set d = $ClassMethod(C, "Call", "POST", "/partners/" _ x.partnerId _ "/orders", $ClassMethod(C, "Delivery", x.sci, order, key))
	Set rid = d.body.receiptId
	For q = "idempotencyKey=" _ key, "orderId=" _ order.orderId, "patientId=" _ order.patient.patientId _ "&scenarioInstanceId=" _ x.sci, "orderId=" _ order.orderId _ "&idempotencyKey=" _ key {
		Set r = $ClassMethod(C, "Call", "GET", "/receipts?" _ q)
		Do $$$AssertEquals(r.status _ ":" _ r.body.items.%Size(), "200:1", "found by " _ q)
	}
	Set item = r.body.items.%Get(0)
	Do $ClassMethod(C, "Capture", "receipts.200", "searchReceipts", 200, "ReceiptSearchResult", r.body)
	Do $$$AssertEquals(item.receiptId, rid, "the receipt")
	Do $$$AssertEquals(item.orderSnapshot.%ToJSON(), order.%ToJSON(), "the raw Order as delivered")
	Do $$$AssertNotTrue($ZConvert(r.text, "L") [ "equivalence", "no equivalence key")
	Do $$$AssertEquals($ClassMethod(C, "Call", "GET", "/receipts?orderId=" _ order.orderId _ "&idempotencyKey=other-key-123").body.items.%Size(), 0, "AND, and no match is an empty list")
	Set none = $ClassMethod(C, "Call", "GET", "/receipts")
	Do $$$AssertEquals(none.status, 400, "a filter is required")
	Do $ClassMethod(C, "Capture", "receipts.400", "searchReceipts", 400, "ErrorEnvelope", none.body)
	Do $$$AssertEquals($ClassMethod(C, "Call", "GET", "/receipts?patientId=" _ order.patient.patientId).status, 400, "patient needs the instance")
	Set one = $ClassMethod(C, "Call", "GET", "/receipts/" _ rid)
	Do $$$AssertEquals(one.status, 200, "read")
	Do $$$AssertTrue(one.body.externalRef [ ("/receipts/" _ rid), "externalRef")
	Do $ClassMethod(C, "Capture", "receipt.200", "getReceipt", 200, "ReceiptRecord", one.body)
	Set nf = $ClassMethod(C, "Call", "GET", "/receipts/rcp_nope")
	Do $$$AssertEquals(nf.status, 404, "unknown")
	Do $ClassMethod(C, "Capture", "receipt.404", "getReceipt", 404, "ErrorEnvelope", nf.body)
}

}
