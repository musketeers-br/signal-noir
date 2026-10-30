Class SignalNoir.Tests.Interop.TestPartnerHttp Extends %UnitTest.TestCase
{

/// 008 T007 - the Partner adapter over the Simulator's HTTP contract
/// (Constitution I: reached only over HTTP)
Property Partner As SignalNoir.Interop.PartnerHttp;

Property Ready As %Boolean;

Method OnBeforeAllTests() As %Status
{
	Set ..Partner = ##class(SignalNoir.Interop.PartnerHttp).%New()
	Set ..Partner.Base = ##class(SignalNoir.Tests.Interop.TestOriginFeed).#SIM, ..Partner.TimeoutSeconds = 10
	Set ..Ready = ..Partner.SearchReceipts({"idempotencyKey": "bek_probe"}).ok
	Return $$$OK
}

Method TestReadsAndDelivery()
{
	If '..Ready {
		Do $$$LogMessage("skipped: the Simulator is not reachable")
		Return
	}
	Set x = ##class(SignalNoir.Tests.Interop.TestOriginFeed).Emit("clean", "clean-success-tune-01", 11)
	Set order = x.order
	Set h = ..Partner.Health(order.partnerId, x.sci)
	Do $$$AssertEquals(h.ok _ ":" _ h.obj.status, "1:UP", "health of a clean instance")
	Set s = ..Partner.OriginStatus(order.orderId)
	Do $$$AssertEquals(s.ok _ ":" _ s.obj.status, "1:active", "status of an emitted Order")
	Set none = ..Partner.SearchReceipts({"idempotencyKey": ("bek_never_" _ $Job)})
	Do $$$AssertEquals(none.ok _ ":" _ none.obj.items.%Size(), "1:0", "an unknown key: empty items, not an error")
	Set key = ##class(SignalNoir.Core.EffectKey).Derive(order.orderId, order.partnerId, order)
	Set request = {"idempotencyKey": (key), "transactionId": ("txn_test_" _ $Job), "scenarioInstanceId": (x.sci), "order": (order)}
	Set a = ..Partner.Deliver(order.partnerId, request)
	Do $$$AssertEquals(a.status, 200, "delivered")
	Do $$$AssertEquals(##class(SignalNoir.Core.ResponseClass).Classify(a, order.orderId, key).class, "success", "a valid Receipt")
	Do $$$AssertNotTrue(a.replayed, "first time")
	Set b = ..Partner.Deliver(order.partnerId, request)
	Do $$$AssertTrue(b.replayed, "the repeat is a replay")
	Do $$$AssertEquals(b.json.receiptId, a.json.receiptId, "of the original Receipt")
	Set found = ..Partner.SearchReceipts({"orderId": (order.orderId)})
	Do $$$AssertEquals(found.obj.items.%Size(), 1, "one Receipt for the Order")
}

}
