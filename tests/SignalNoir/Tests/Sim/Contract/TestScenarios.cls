Class SignalNoir.Tests.Sim.Contract.TestScenarios Extends %UnitTest.TestCase
{

/// 002 T018 - create, read and emit a scenario instance (US1)
Method OnBeforeAllTests() As %Status
{
	Return ##class(SignalNoir.Sim.Setup).EnsureWebApplication()
}

Method TestCreateReadEmit()
{
	Set C = "SignalNoir.Tests.Sim.Contract.Client"
	Set c = $ClassMethod(C, "Call", "POST", "/scenarios", {"family": "clean", "variant": "clean-success-tune-01", "seed": 42, "runId": "run_test_0001", "repetition": 2})
	Do $$$AssertEquals(c.status, 201, "201")
	Do $ClassMethod(C, "Capture", "scenarios.201.create", "createScenarioInstance", 201, "ScenarioInstance", c.body)
	Set sci = c.body.scenarioInstanceId
	Do $$$AssertTrue($Match(sci, "^sci_[A-Za-z0-9_-]{4,64}$"), "id")
	Do $$$AssertEquals(c.body.status, "created", "created")
	Do $$$AssertEquals(c.body.repetition _ ":" _ c.body.runId _ ":" _ c.body.seed, "2:run_test_0001:42", "echoes the request")
	Do $$$AssertEquals(c.body.emittedOrderIds.%Size(), 0, "nothing emitted")
	Do $$$AssertTrue(c.location [ ("/scenarios/" _ sci), "Location header")
	Set g = $ClassMethod(C, "Call", "GET", "/scenarios/" _ sci)
	Do $$$AssertEquals(g.status, 200, "read")
	Do $ClassMethod(C, "Capture", "scenarios.200.get", "getScenarioInstance", 200, "ScenarioInstance", g.body)
	Set e = $ClassMethod(C, "Call", "POST", "/scenarios/" _ sci _ "/emissions")
	Do $$$AssertEquals(e.status, 201, "emitted")
	Do $ClassMethod(C, "Capture", "emissions.201", "emitScenarioOrders", 201, "EmissionResult", e.body)
	Do $$$AssertEquals(e.body.emitted.%Size(), 1, "one Order")
	Set env = e.body.emitted.%Get(0)
	Do $$$AssertEquals(env.scenarioInstanceId _ ":" _ env.runId _ ":" _ env.repetition, sci _ ":run_test_0001:2", "bound to the instance")
	Do $$$AssertEquals(env.order.synthetic, 1, "synthetic")
	Set again = $ClassMethod(C, "Call", "POST", "/scenarios/" _ sci _ "/emissions")
	Do $$$AssertEquals(again.status, 200, "second emission is 200")
	Do $$$AssertEquals(again.body.%ToJSON(), e.body.%ToJSON(), "same emissions")
	Do $ClassMethod(C, "Capture", "emissions.200.again", "emitScenarioOrders", 200, "EmissionResult", again.body)
	Set g = $ClassMethod(C, "Call", "GET", "/scenarios/" _ sci)
	Do $$$AssertEquals(g.body.status, "emitted", "emitted")
	Do $$$AssertEquals(g.body.emittedOrderIds.%Get(0), env.order.orderId, "emittedOrderIds")
}

Method TestRefusals()
{
	Set C = "SignalNoir.Tests.Sim.Contract.Client"
	Set r = $ClassMethod(C, "Call", "POST", "/scenarios", {"family": "clean", "variant": "nope", "seed": 1})
	Do $$$AssertEquals(r.status _ ":" _ r.body.error.code, "404:NOT_FOUND", "unknown variant")
	Do $ClassMethod(C, "Capture", "scenarios.404.unknown-variant", "createScenarioInstance", 404, "ErrorEnvelope", r.body)
	For bad = {"family": "clean", "variant": "clean-success-tune-01", "seed": -1}, {"family": "clean", "variant": "clean-success-tune-01", "seed": 1, "timeScale": 0}, {"family": "clean", "variant": "clean-success-tune-01", "seed": 1, "timeScale": 1.5}, {"family": "clean", "variant": "clean-success-tune-01", "seed": 1, "repetition": 0}, {"family": "clean", "variant": "clean-success-tune-01", "seed": 1, "runId": "bad"}, {"family": "nope", "variant": "x", "seed": 1} {
		Set r = $ClassMethod(C, "Call", "POST", "/scenarios", bad)
		Do $$$AssertEquals(r.status _ ":" _ r.body.error.code, "400:INVALID_REQUEST", "refused: " _ bad.%ToJSON())
	}
	Do $ClassMethod(C, "Capture", "scenarios.400.invalid", "createScenarioInstance", 400, "ErrorEnvelope", r.body)
	Set r = $ClassMethod(C, "Call", "GET", "/scenarios/sci_doesnotexist")
	Do $$$AssertEquals(r.status, 404, "unknown instance")
	Do $ClassMethod(C, "Capture", "scenarios.404.get", "getScenarioInstance", 404, "ErrorEnvelope", r.body)
	Set r = $ClassMethod(C, "Call", "POST", "/scenarios/sci_doesnotexist/emissions")
	Do $$$AssertEquals(r.status, 404, "unknown instance emission")
	Do $ClassMethod(C, "Capture", "emissions.404", "emitScenarioOrders", 404, "ErrorEnvelope", r.body)
}

}
