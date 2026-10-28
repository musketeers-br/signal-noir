Class SignalNoir.Tests.Sim.Contract.TestOriginOrders Extends %UnitTest.TestCase
{

/// 002 T050 - recent Origin Orders of a synthetic patient (US4)
Method OnBeforeAllTests() As %Status
{
	Return ##class(SignalNoir.Sim.Setup).EnsureWebApplication()
}

Method TestByPatient()
{
	Set C = "SignalNoir.Tests.Sim.Contract.Client"
	Set x = $ClassMethod(C, "Emitted", "clean", "clean-success-tune-01", 101)
	Set y = $ClassMethod(C, "Emitted", "clean", "clean-success-tune-01", 101)
	Set patient = x.orders.%Get(0).patient.patientId
	Do $$$AssertEquals(y.orders.%Get(0).patient.patientId, patient, "same seed, same patient")
	Set r = $ClassMethod(C, "Call", "GET", "/origin/orders?patientId=" _ patient _ "&scenarioInstanceId=" _ x.sci)
	Do $$$AssertEquals(r.status _ ":" _ r.body.items.%Size(), "200:1", "only this instance")
	Do $$$AssertEquals(r.body.items.%Get(0).order.%ToJSON(), x.orders.%Get(0).%ToJSON(), "raw snapshot")
	Do $ClassMethod(C, "Capture", "origin.orders.200", "searchOriginOrders", 200, "OriginOrderList", r.body)
	Do $$$AssertEquals($ClassMethod(C, "Call", "GET", "/origin/orders?patientId=" _ patient _ "&scenarioInstanceId=" _ x.sci _ "&emittedAfter=2099-01-01T00:00:00Z").body.items.%Size(), 0, "emittedAfter")
	Set bad = $ClassMethod(C, "Call", "GET", "/origin/orders?patientId=" _ patient)
	Do $$$AssertEquals(bad.status, 400, "instance required")
	Do $ClassMethod(C, "Capture", "origin.orders.400", "searchOriginOrders", 400, "ErrorEnvelope", bad.body)
}

}
