Class SignalNoir.Tests.Sim.Isolation.TestAnswerKeyLeak Extends %UnitTest.TestCase
{

/// 002 T063 - no endpoint exposes the answer key or a private rule (SC-006, FR-030)
Method OnBeforeAllTests() As %Status
{
	Set ^SignalNoir.Sim.Config("clientTimeoutSeconds") = 1
	Return ##class(SignalNoir.Sim.Setup).EnsureWebApplication()
}

Method OnAfterAllTests() As %Status
{
	Kill ^SignalNoir.Sim.Config("clientTimeoutSeconds")
	Return $$$OK
}

Method TestNoLeak()
{
	Set C = "SignalNoir.Tests.Sim.Contract.Client"
	Set all = ##class(SignalNoir.Sim.Catalog.Loader).All().obj
	Set leaks = "", texts = $ClassMethod(C, "Call", "GET", "/scenario-catalog").text
	For i = 0 : 1 : all.%Size() - 1 {
		Set v = all.%Get(i)
		Set x = $ClassMethod(C, "Emitted", v.family, v.variant, 900 + i, 0.01)
		Set texts = texts _ x.emission.%ToJSON()
		Set order = x.orders.%Get(0)
		Set texts = texts _ $ClassMethod(C, "Call", "POST", "/partners/" _ x.partnerId _ "/orders", $ClassMethod(C, "Delivery", x.sci, order, "idk_leak_" _ $Extract(x.sci, 5, 20)), 1).text
		For path = "/partners/" _ x.partnerId _ "/health?scenarioInstanceId=" _ x.sci, "/partners/" _ x.partnerId _ "/history?scenarioInstanceId=" _ x.sci, "/receipts?orderId=" _ order.orderId, "/origin/orders/" _ order.orderId, "/origin/orders?patientId=" _ order.patient.patientId _ "&scenarioInstanceId=" _ x.sci, "/scenarios/" _ x.sci {
			Set texts = texts _ $ClassMethod(C, "Call", "GET", path).text
		}
		; the private acceptance rule of this variant
		If $IsObject(v.partnerRule) {
			Set rules = v.partnerRule.accepts
			For j = 0 : 1 : rules.%Size() - 1 {
				Set when = rules.%Get(j).when
				If $IsObject(when) && (texts [ when.%ToJSON()) Set leaks = leaks _ v.variant _ " rule; "
			}
		}
	}
	For word = "partnerRule", "expectedAction", "expectedParams", "expectedState", "expectedClass", "answerKey", "gabarito" {
		If texts [ word Set leaks = leaks _ word _ "; "
	}
	Do $$$AssertEquals(leaks, "", "no answer-key content in any response")
}

}
