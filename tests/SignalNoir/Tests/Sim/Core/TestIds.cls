Class SignalNoir.Tests.Sim.Core.TestIds Extends %UnitTest.TestCase
{

/// 002 T005 - identifiers (research D4, 26 base32 chars after V2)
Method TestInstanceIds()
{
	Set I = "SignalNoir.Sim.Ids"
	Set first = $ClassMethod(I, "NewInstanceId")
	Do $$$AssertTrue(first ? 1"sci_"26(1U,1N), "sci_ + 26 base32: " _ first)
	Do $$$AssertTrue($Match(first, "^sci_[A-Za-z0-9_-]{4,64}$"), "matches the contract pattern")
	Kill seen
	Set dup = 0
	For i = 1 : 1 : 1000 {
		Set id = $ClassMethod(I, "NewInstanceId")
		If $Data(seen(id)) Set dup = dup + 1
		Set seen(id) = ""
	}
	Do $$$AssertEquals(dup, 0, "1000 distinct ids")
}

Method TestDerivedIds()
{
	Set I = "SignalNoir.Sim.Ids"
	Set sci = "sci_ABCDEFGH"
	Do $$$AssertEquals($ClassMethod(I, "OrderId", sci, 1), "ORD-sci_ABCDEFGH-0001", "orderId")
	Do $$$AssertEquals($ClassMethod(I, "OrderId", sci, 12), "ORD-sci_ABCDEFGH-0012", "padded ordinal")
	Do $$$AssertEquals($ClassMethod(I, "TransactionId", sci, 2), "txn_ABCDEFGH_2", "transactionId")
	Do $$$AssertEquals($ClassMethod(I, "ReceiptId", sci, 3), "rcp_ABCDEFGH_3", "receiptId")
}

}
