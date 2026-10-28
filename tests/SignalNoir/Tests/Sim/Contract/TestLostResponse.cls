Class SignalNoir.Tests.Sim.Contract.TestLostResponse Extends %UnitTest.TestCase
{

/// 002 T044 - a lost response: the receipt exists, the caller saw nothing (SC-005)
Method OnBeforeAllTests() As %Status
{
	Set ^SignalNoir.Sim.Config("clientTimeoutSeconds") = 2
	Return ##class(SignalNoir.Sim.Setup).EnsureWebApplication()
}

Method OnAfterAllTests() As %Status
{
	Kill ^SignalNoir.Sim.Config("clientTimeoutSeconds")
	Return $$$OK
}

Method TestLostReceipt()
{
	Set C = "SignalNoir.Tests.Sim.Contract.Client"
	Set x = $ClassMethod(C, "Emitted", "idempotency", "idempotency-lost-receipt-tune-01", 81, 0.01)
	Set order = x.orders.%Get(0), key = "idk_lost_" _ $Extract(x.sci, 5, 20)
	Set path = "/partners/" _ x.partnerId _ "/orders"
	Set r = $ClassMethod(C, "Call", "POST", path, $ClassMethod(C, "Delivery", x.sci, order, key), 2)
	Do $$$AssertEquals(r.status, 0, "the caller times out")
	Set byOrder = $ClassMethod(C, "Call", "GET", "/receipts?orderId=" _ order.orderId)
	Do $$$AssertEquals(byOrder.body.items.%Size(), 1, "found by orderId")
	Set byKey = $ClassMethod(C, "Call", "GET", "/receipts?idempotencyKey=" _ key)
	Do $$$AssertEquals(byKey.body.items.%Get(0).receiptId, byOrder.body.items.%Get(0).receiptId, "found by key")
	Set again = $ClassMethod(C, "Call", "POST", path, $ClassMethod(C, "Delivery", x.sci, order, key), 10)
	Do $$$AssertEquals(again.status _ ":" _ again.replayed, "200:true", "a redelivery replays it at once")
	Do $$$AssertEquals(again.body.receiptId, byKey.body.items.%Get(0).receiptId, "the same receipt")
}

}
