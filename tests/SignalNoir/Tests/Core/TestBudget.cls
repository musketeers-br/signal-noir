Class SignalNoir.Tests.Core.TestBudget Extends %UnitTest.TestCase
{

/// 006 T020 - 6 Tool calls, 20 seconds
Method TestLimits()
{
	Do $$$AssertEquals(##class(SignalNoir.Core.Budget).#MAXTOOLCALLS, 6, "6 calls")
	Do $$$AssertEquals(##class(SignalNoir.Core.Budget).#MAXMILLIS, 20000, "20 s")
}

Method TestBreach()
{
	Set B = "SignalNoir.Core.Budget"
	Do $$$AssertEquals($ClassMethod(B, "Breach", 0, 0), "", "fresh")
	Do $$$AssertEquals($ClassMethod(B, "Breach", 5, 19999), "", "sixth call allowed")
	Do $$$AssertEquals($ClassMethod(B, "Breach", 6, 1000), "tool calls", "seventh refused")
	Do $$$AssertEquals($ClassMethod(B, "Breach", 0, 20000), "time", "time out")
	Do $$$AssertEquals($ClassMethod(B, "Breach", 6, 20000), "time", "time first")
	Do $$$AssertEquals($ClassMethod(B, "Reason", "time"), "investigation budget exceeded: time", "reason text")
}

}
