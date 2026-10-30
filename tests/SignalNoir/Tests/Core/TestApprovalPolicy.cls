Class SignalNoir.Tests.Core.TestApprovalPolicy Extends %UnitTest.TestCase
{

/// 007 T003 - default approval policy until 004: a 15-minute deadline, and
/// the benchmark actor only on a Case of a BenchmarkRun
Method TestDeadline()
{
	Set p = ##class(SignalNoir.Core.ApprovalPolicy).%New()
	Do $$$AssertEquals(p.DeadlineSeconds(), 900, "15 minutes")
	Do $$$AssertEquals(p.ExpiresAt("2026-10-29T13:00:13Z"), "2026-10-29T13:15:13Z", "fixture deadline")
	Do $$$AssertEquals(p.ExpiresAt("2026-10-29T23:50:00.250Z"), "2026-10-30T00:05:00.250Z", "across midnight, keeps the fraction")
	Do $$$AssertNotTrue(p.IsExpired("2026-10-29T13:15:13Z", "2026-10-29T13:15:12.900Z"), "not yet")
	Do $$$AssertNotTrue(p.IsExpired("2026-10-29T13:15:13Z", "2026-10-29T13:15:13Z"), "at the deadline it still holds")
	Do $$$AssertTrue(p.IsExpired("2026-10-29T13:15:13Z", "2026-10-29T13:15:13.001Z"), "past it")
	Do $$$AssertTrue(p.IsExpired("2026-10-29T13:15:13Z", "2026-10-30T00:00:00Z"), "next day")
	Do $$$AssertNotTrue(p.IsExpired("", "2026-10-30T00:00:00Z"), "no deadline (a denial) never expires")
}

Method TestAdmit()
{
	Set p = ##class(SignalNoir.Core.ApprovalPolicy).%New()
	Do $$$AssertTrue(p.Admit("benchmark", "run_01"), "benchmark inside a run")
	Do $$$AssertNotTrue(p.Admit("benchmark", ""), "benchmark outside a run")
	Do $$$AssertTrue(p.Admit("operator:carla", ""), "an operator")
	Do $$$AssertTrue(p.Admit("sweeper", ""), "other actors are the state machine's business")
}

}
