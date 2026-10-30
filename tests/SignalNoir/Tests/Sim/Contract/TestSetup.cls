Class SignalNoir.Tests.Sim.Contract.TestSetup Extends %UnitTest.TestCase
{

/// 002 T015/T016 - the web application and the error envelope (V5, V6)
Method TestWebApplication()
{
	Do $$$AssertStatusOK(##class(SignalNoir.Sim.Setup).EnsureWebApplication(), "registered")
	Do $$$AssertStatusOK(##class(SignalNoir.Sim.Setup).EnsureWebApplication(), "idempotent")
	Do $$$AssertTrue(##class(SignalNoir.Sim.Setup).Exists("/sim/api/v1"), "simulator app")
	Do $$$AssertTrue(##class(SignalNoir.Sim.Setup).Exists("/signalnoir/api/v1"), "product app untouched")
}

Method TestUnknownRoute()
{
	Do ##class(SignalNoir.Sim.Setup).EnsureWebApplication()
	Set r = ##class(SignalNoir.Tests.Sim.Contract.Client).Call("GET", "/_unknown")
	Do $$$AssertEquals(r.status, 404, "404")
	Do $$$AssertEquals(r.body.error.code, "NOT_FOUND", "envelope")
	Do $$$AssertTrue(r.body.error.message '= "", "message")
}

}
