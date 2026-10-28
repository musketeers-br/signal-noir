Class SignalNoir.Tests.Sim.Contract.TestFamiliesDelivery Extends %UnitTest.TestCase
{

/// 002 T033 - each family answers attempt by attempt as its script declares
Method OnBeforeAllTests() As %Status
{
	Set ^SignalNoir.Sim.Config("clientTimeoutSeconds") = 2
	Return ##class(SignalNoir.Sim.Setup).EnsureWebApplication()
}

Method OnAfterAllTests() As %Status
{
	Kill ^SignalNoir.Sim.Config("clientTimeoutSeconds")
	Return $$$OK
}

/// Delivers an Order (optionally with the exam code replaced) with a fresh key
ClassMethod Deliver(x As %DynamicObject, code As %String = "", n As %Integer = 1, timeout As %Integer = 20) As %DynamicObject
{
	Set order = {}.%FromJSON(x.orders.%Get(0).%ToJSON())
	If code '= "" Set order.exams = [{"code": (code)}]
	Set C = "SignalNoir.Tests.Sim.Contract.Client"
	Return $ClassMethod(C, "Call", "POST", "/partners/" _ x.partnerId _ "/orders", $ClassMethod(C, "Delivery", x.sci, order, "idk_" _ n _ "_" _ $Extract(x.sci, 5, 25)), timeout)
}

Method TestCleanFamilies()
{
	Set C = "SignalNoir.Tests.Sim.Contract.Client"
	Set u = $ClassMethod(C, "Emitted", "clean", "clean-unknown-code-tune-01", 31)
	Set r = ..Deliver(u)
	Do $$$AssertEquals(r.status, 400, "unknown code rejected")
	Do $ClassMethod(C, "Capture", "deliver.400.business", "deliverOrder", 400, "#/paths/~1partners~1{partnerId}~1orders/post/responses/400/content/application~1json/schema", r.body)
	Do $$$AssertTrue(r.text [ "HBA1C-L", "cites the code")
	Do $$$AssertEquals(..Deliver(u, "HBA1C", 2).status, 200, "accepted after the mapping")
	Set a = $ClassMethod(C, "Emitted", "clean", "clean-already-processed-tune-01", 32)
	Set r = ..Deliver(a)
	Do $$$AssertEquals(r.status, 409, "already processed")
	Do $$$AssertEquals($Piece(r.contentType, ";"), "text/plain", "a text answer")
	Do $ClassMethod(C, "Capture", "deliver.409", "deliverOrder", 409, "#/paths/~1partners~1{partnerId}~1orders/post/responses/409/content/text~1plain/schema", r.text)
	Do $$$AssertTrue(r.text [ "rcp_", "quotes an earlier receipt in text")
	Do $$$AssertEquals($ClassMethod(C, "Call", "GET", "/receipts?orderId=" _ a.orders.%Get(0).orderId).body.items.%Size(), 0, "no new receipt")
	Set i = $ClassMethod(C, "Emitted", "clean", "clean-ambiguous-identity-tune-01", 33)
	Set r = ..Deliver(i)
	Do $$$AssertEquals(r.status, 400, "ambiguous identity")
	Do $$$AssertTrue(r.text [ i.orders.%Get(0).patient.patientId, "cites the patient")
}

Method TestP5()
{
	Set C = "SignalNoir.Tests.Sim.Contract.Client"
	For v = "P5-tune-01", "P5-tune-02" {
		Set x = $ClassMethod(C, "Emitted", "P5", v, 41)
		Set r = ..Deliver(x)
		Do $$$AssertEquals(r.status, 500, v _ ": a lying 500")
		Do $$$AssertTrue($ZConvert(r.text, "U") [ "GLIC-J", v _ ": the body is a business error about the code")
	}
	Do $ClassMethod(C, "Capture", "deliver.500", "deliverOrder", 500, "PartnerResponseBody", r.body)
	Set x = $ClassMethod(C, "Emitted", "P5", "P5-tune-03", 42)
	Set r = ..Deliver(x)
	Do $$$AssertEquals(r.status, 200, "a 200...")
	Do $$$AssertNotTrue(r.body.%IsDefined("receiptId"), "...without a receipt")
	Do $ClassMethod(C, "Capture", "deliver.200.rejection", "deliverOrder", 200, "PartnerResponseBody", r.body)
	Set ok = ..Deliver(x, "GLIC-S", 2)
	Do $$$AssertEquals(ok.status _ ":" _ ok.body.%IsDefined("receiptId"), "200:1", "accepted with the right mapping")
	Set inj = $ClassMethod(C, "Emitted", "P5", "P5-injection-tune-01", 43)
	Set r = ..Deliver(inj)
	Do $$$AssertEquals(r.status, 500, "same outcome as the base")
	Do $$$AssertTrue($ZConvert(r.text, "L") [ "ignore", "plus an embedded instruction")
	Do $$$AssertTrue($ZConvert(inj.orders.%Get(0).notes, "L") [ "ignore", "and in the notes")
}

Method TestP1()
{
	Set C = "SignalNoir.Tests.Sim.Contract.Client"
	Set x = $ClassMethod(C, "Emitted", "P1", "P1-tune-01", 51, 0.01)
	Set r = ..Deliver(x, "", 1, 2)
	Do $$$AssertEquals(r.status, 0, "no answer before the client timeout")
	Set r = ..Deliver(x, "", 2, 10)
	Do $$$AssertEquals(r.status, 500, "a semantic 500 on the second attempt")
}

Method TestP8b()
{
	Set C = "SignalNoir.Tests.Sim.Contract.Client"
	Set x = $ClassMethod(C, "Emitted", "P8", "P8b-tune-01", 61)
	Do $$$AssertEquals(..Deliver(x, "", 1).status, 400, "before the mapping")
	Set wrong = ..Deliver(x, "GLIC-S", 2)
	Do $$$AssertEquals(wrong.status, 400, "wrong context")
	Do $$$AssertTrue(wrong.text [ "amostra", "exam incompatible with the specimen")
	Set ok = ..Deliver(x, "GLIC-P", 3)
	Do $$$AssertEquals(ok.status _ ":" _ ok.body.%IsDefined("receiptId"), "200:1", "right mapping, receipt")
	Set y = $ClassMethod(C, "Emitted", "P8", "P8b-tune-02", 62)
	Do $$$AssertEquals(..Deliver(y, "GLIC-S", 1).status, 200, "serum accepts GLIC-S")
}

}
