Class SignalNoir.Tests.Core.TestPrecedentStatus Extends %UnitTest.TestCase
{

/// 015 T004 - six distinct statuses in a fixed order
Method TestOrder()
{
	Set ps = "SignalNoir.Core.PrecedentStatus"
	Do $$$AssertEquals($ClassMethod(ps, "Decide", 1, 1, 5, 5, 5), "rebuilding", "rebuilding first")
	Do $$$AssertEquals($ClassMethod(ps, "Decide", 0, 1, 5, 0, 5), "unavailable", "embedder failure")
	Do $$$AssertEquals($ClassMethod(ps, "Decide", 0, 0, 0, 3, 0), "needs_rebuild", "only another model")
	Do $$$AssertEquals($ClassMethod(ps, "Decide", 0, 0, 0, 0, 0), "no_precedents", "empty")
	Do $$$AssertEquals($ClassMethod(ps, "Decide", 0, 0, 4, 0, 0), "nothing_similar", "below minimum")
	Do $$$AssertEquals($ClassMethod(ps, "Decide", 0, 0, 4, 2, 3), "results", "results")
}

}
