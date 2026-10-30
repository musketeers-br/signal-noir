Class SignalNoir.Tests.Sim.Contract.TestTriggers Extends %UnitTest.TestCase
{

/// 002 T057 - scripted triggers change the world on the 2nd read (US5, SC-007)
Method OnBeforeAllTests() As %Status
{
	Return ##class(SignalNoir.Sim.Setup).EnsureWebApplication()
}

Method TestHealthTrigger()
{
	Set C = "SignalNoir.Tests.Sim.Contract.Client"
	Set x = $ClassMethod(C, "Emitted", "P3", "P3-fails-tune-01", 121)
	Set path = "/partners/" _ x.partnerId _ "/health?scenarioInstanceId=" _ x.sci
	Do $$$AssertEquals($ClassMethod(C, "Call", "GET", path).body.status, "UP", "1st read: the evidence")
	Do $$$AssertEquals($ClassMethod(C, "Call", "GET", path).body.status, "DEGRADED", "2nd read: revalidation sees the change")
	Set i = $ClassMethod(C, "Call", "GET", "/scenarios/" _ x.sci)
	Do $$$AssertEquals(i.body.appliedEvents.%Size(), 1, "applied once")
	Do $ClassMethod(C, "Call", "GET", path)
	Do $$$AssertEquals($ClassMethod(C, "Call", "GET", "/scenarios/" _ x.sci).body.appliedEvents.%Size(), 1, "fires once")
}

Method TestOriginStatusTrigger()
{
	Set C = "SignalNoir.Tests.Sim.Contract.Client"
	Set x = $ClassMethod(C, "Emitted", "P3", "P3-cancelled-tune-01", 122)
	Set path = "/origin/orders/" _ x.orders.%Get(0).orderId
	Do $$$AssertEquals($ClassMethod(C, "Call", "GET", path).body.status, "active", "1st read")
	Do $$$AssertEquals($ClassMethod(C, "Call", "GET", path).body.status, "cancelled", "2nd read: cancelled")
}

}
