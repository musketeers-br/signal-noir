Class SignalNoir.Tests.Sim.Contract.TestCatalog Extends %UnitTest.TestCase
{

/// 002 T021 - GET /scenario-catalog (US1, US6)
Method OnBeforeAllTests() As %Status
{
	Return ##class(SignalNoir.Sim.Setup).EnsureWebApplication()
}

Method TestCatalog()
{
	Set C = "SignalNoir.Tests.Sim.Contract.Client"
	Set r = $ClassMethod(C, "Call", "GET", "/scenario-catalog")
	Do $$$AssertEquals(r.status, 200, "200")
	Do $ClassMethod(C, "Capture", "catalog.200", "listScenarioCatalog", 200, "#/paths/~1scenario-catalog/get/responses/200/content/application~1json/schema", r.body)
	Do $$$AssertTrue(r.body.items.%Size() >= 17, "every subtype")
	Do $$$AssertNotTrue(r.text [ "partnerRule", "no private rule")
	Set f = $ClassMethod(C, "Call", "GET", "/scenario-catalog?family=P8&set=tuning")
	Set wrong = 0
	For i = 0 : 1 : f.body.items.%Size() - 1 If (f.body.items.%Get(i).family '= "P8") || (f.body.items.%Get(i).set '= "tuning") Set wrong = wrong + 1
	Do $$$AssertTrue((f.body.items.%Size() > 0) && (wrong = 0), "filters")
	Set bad = $ClassMethod(C, "Call", "GET", "/scenario-catalog?set=gold")
	Do $$$AssertEquals(bad.status, 400, "invalid set")
	Do $ClassMethod(C, "Capture", "catalog.400", "listScenarioCatalog", 400, "ErrorEnvelope", bad.body)
}

}
