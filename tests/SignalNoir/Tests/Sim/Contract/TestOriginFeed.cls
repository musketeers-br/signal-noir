Class SignalNoir.Tests.Sim.Contract.TestOriginFeed Extends %UnitTest.TestCase
{

/// 002 T019 - the Origin feed and Order status (US1)
Method OnBeforeAllTests() As %Status
{
	Return ##class(SignalNoir.Sim.Setup).EnsureWebApplication()
}

Method TestFeed()
{
	Set C = "SignalNoir.Tests.Sim.Contract.Client"
	Set head = ..Head()
	Set x = $ClassMethod(C, "Emitted", "P5", "P5-tune-01", 3)
	Set page = $ClassMethod(C, "Call", "GET", "/origin/feed?afterSeq=" _ head _ "&limit=200")
	Do $$$AssertEquals(page.status, 200, "200")
	Do $ClassMethod(C, "Capture", "origin.feed.200", "readOriginFeed", 200, "OriginFeedPage", page.body)
	Set found = 0, ordered = 1, last = head
	For i = 0 : 1 : page.body.items.%Size() - 1 {
		Set it = page.body.items.%Get(i)
		If it.feedSeq <= last Set ordered = 0
		Set last = it.feedSeq
		If it.scenarioInstanceId = x.sci Set found = found + 1, item = it
	}
	Do $$$AssertTrue(ordered, "ordered by feedSeq")
	Do $$$AssertEquals(found, 1, "the instance's Order is in the feed")
	For f = "feedSeq", "scenarioInstanceId", "repetition", "transactionId", "emittedAt", "order" Do $$$AssertTrue(item.%IsDefined(f), "envelope." _ f)
	Do $$$AssertEquals(page.body.lastSeq, last, "lastSeq is the last item")
	; past the end
	Set empty = $ClassMethod(C, "Call", "GET", "/origin/feed?afterSeq=" _ (last + 1000))
	Do $$$AssertEquals(empty.body.items.%Size() _ ":" _ empty.body.lastSeq, "0:" _ (last + 1000), "empty page keeps afterSeq")
	; items never change
	Set again = $ClassMethod(C, "Call", "GET", "/origin/feed?afterSeq=" _ (item.feedSeq - 1) _ "&limit=1")
	Do $$$AssertEquals(again.body.items.%Get(0).%ToJSON(), item.%ToJSON(), "unchanged on re-read")
	Do $$$AssertEquals($ClassMethod(C, "Call", "GET", "/origin/feed?limit=0").status, 400, "limit out of range")
	Do $$$AssertEquals($ClassMethod(C, "Call", "GET", "/origin/feed?afterSeq=-1").status, 400, "negative afterSeq")
	Set bad = $ClassMethod(C, "Call", "GET", "/origin/feed?limit=500")
	Do $$$AssertEquals(bad.status, 400, "limit too big")
	Do $ClassMethod(C, "Capture", "origin.feed.400", "readOriginFeed", 400, "ErrorEnvelope", bad.body)
}

Method TestOrderStatus()
{
	Set C = "SignalNoir.Tests.Sim.Contract.Client"
	Set x = $ClassMethod(C, "Emitted", "clean", "clean-success-tune-01", 5)
	Set orderId = x.orders.%Get(0).orderId
	Set s = $ClassMethod(C, "Call", "GET", "/origin/orders/" _ orderId)
	Do $$$AssertEquals(s.status _ ":" _ s.body.status, "200:active", "active")
	Do $$$AssertEquals(s.body.scenarioInstanceId, x.sci, "instance")
	Do $ClassMethod(C, "Capture", "origin.order-status.200", "getOriginOrderStatus", 200, "OriginOrderStatus", s.body)
	; 006's SimulatorSource appends scenarioInstanceId: unknown query parameters are ignored
	Do $$$AssertEquals($ClassMethod(C, "Call", "GET", "/origin/orders/" _ orderId _ "?scenarioInstanceId=" _ x.sci).status, 200, "extra query ignored")
	Set nf = $ClassMethod(C, "Call", "GET", "/origin/orders/ORD-nope")
	Do $$$AssertEquals(nf.status, 404, "unknown Order")
	Do $ClassMethod(C, "Capture", "origin.order-status.404", "getOriginOrderStatus", 404, "ErrorEnvelope", nf.body)
}

ClassMethod Head() As %Integer
{
	Return +$Get(^SignalNoir.Sim.FeedSeq)
}

}
