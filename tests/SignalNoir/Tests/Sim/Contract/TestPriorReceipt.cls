Class SignalNoir.Tests.Sim.Contract.TestPriorReceipt Extends %UnitTest.TestCase
{

/// 002 T067 - P9 data: the original was received about 3 minutes earlier (US7)
Method OnBeforeAllTests() As %Status
{
	Return ##class(SignalNoir.Sim.Setup).EnsureWebApplication()
}

Method TestPriorReceipt()
{
	Set C = "SignalNoir.Tests.Sim.Contract.Client"
	Set head = +$Get(^SignalNoir.Sim.FeedSeq)
	Set x = $ClassMethod(C, "Emitted", "P9", "P9-tune-01", 131)
	Do $$$AssertEquals(x.emission.emitted.%Size(), 1, "only the resend is emitted")
	Set resend = x.orders.%Get(0)
	Set feed = $ClassMethod(C, "Call", "GET", "/origin/feed?afterSeq=" _ head _ "&limit=200")
	Set mine = 0
	For i = 0 : 1 : feed.body.items.%Size() - 1 If feed.body.items.%Get(i).scenarioInstanceId = x.sci Set mine = mine + 1
	Do $$$AssertEquals(mine, 1, "one feed item")
	Set patient = resend.patient.patientId
	Set orders = $ClassMethod(C, "Call", "GET", "/origin/orders?patientId=" _ patient _ "&scenarioInstanceId=" _ x.sci)
	Do $$$AssertEquals(orders.body.items.%Size(), 2, "the original is in the Origin history")
	Set original = $Select(orders.body.items.%Get(0).orderId = resend.orderId: orders.body.items.%Get(1), 1: orders.body.items.%Get(0))
	Do $$$AssertTrue(original.orderId '= resend.orderId, "its own orderId")
	Do $$$AssertTrue(original.transactionId '= x.emission.emitted.%Get(0).transactionId, "its own transaction")
	Do $$$AssertEquals(original.order.exams.%ToJSON(), resend.exams.%ToJSON(), "the same exams")
	Set rcp = $ClassMethod(C, "Call", "GET", "/receipts?patientId=" _ patient _ "&scenarioInstanceId=" _ x.sci)
	Do $$$AssertEquals(rcp.body.items.%Size(), 1, "the prior receipt")
	Set gap = ##class(SignalNoir.Sim.Clock).Seconds(x.emission.emitted.%Get(0).emittedAt) - ##class(SignalNoir.Sim.Clock).Seconds(rcp.body.items.%Get(0).receivedAt)
	Do $$$AssertTrue((gap >= 179) && (gap <= 181), "about 3 minutes earlier: " _ gap)
	Do $ClassMethod(C, "Capture", "receipts.200.prior", "searchReceipts", 200, "ReceiptSearchResult", rcp.body)
	Set d = $ClassMethod(C, "Call", "POST", "/partners/" _ x.partnerId _ "/orders", $ClassMethod(C, "Delivery", x.sci, resend, "idk_p9_" _ $Extract(x.sci, 5, 20)))
	Do $$$AssertEquals(d.status _ ":" _ d.body.%IsDefined("receiptId"), "200:1", "the resend is accepted")
}

}
