Class SignalNoir.Tests.Sim.Core.TestClock Extends %UnitTest.TestCase
{

/// 002 T013 - Simulator times are UTC with Z
Method TestClock()
{
	Set now = ##class(SignalNoir.Sim.Clock).NowUtc()
	Do $$$AssertTrue($Match(now, "^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d{1,6})?Z$"), "UTC with Z: " _ now)
	Do $$$AssertEquals(##class(SignalNoir.Sim.Clock).Shift("2026-10-28T14:03:11.250Z", -180), "2026-10-28T14:00:11.250Z", "180 s earlier")
	Do $$$AssertEquals(##class(SignalNoir.Sim.Clock).Shift("2026-10-28T00:01:00Z", -120), "2026-10-27T23:59:00Z", "across midnight")
	Do $$$AssertTrue(##class(SignalNoir.Sim.Clock).Seconds("2026-10-28T14:03:11.5Z") - ##class(SignalNoir.Sim.Clock).Seconds("2026-10-28T14:03:10Z") = 1.5, "seconds with fraction")
}

}
