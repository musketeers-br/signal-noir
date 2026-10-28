Class SignalNoir.Tests.Sim.Core.TestDeterminism Extends %UnitTest.TestCase
{

/// 002 T020 - same seed, same sequence; never the same ids (FR-006..FR-008)
Method OnBeforeAllTests() As %Status
{
	Return ##class(SignalNoir.Sim.Setup).EnsureWebApplication()
}

ClassMethod Strip(order As %DynamicObject) As %String
{
	Set o = {}.%FromJSON(order.%ToJSON())
	Do o.%Remove("orderId")
	Return o.%ToJSON()
}

Method TestSameSeed()
{
	Set C = "SignalNoir.Tests.Sim.Contract.Client"
	Set a = $ClassMethod(C, "Emitted", "P8", "P8b-tune-01", 501)
	Set b = $ClassMethod(C, "Emitted", "P8", "P8b-tune-01", 501)
	Set c = $ClassMethod(C, "Emitted", "P8", "P8b-tune-01", 502)
	Do $$$AssertEquals(..Strip(a.orders.%Get(0)), ..Strip(b.orders.%Get(0)), "same content")
	Do $$$AssertTrue(a.orders.%Get(0).orderId '= b.orders.%Get(0).orderId, "different orderIds")
	Do $$$AssertTrue(..Strip(a.orders.%Get(0)) '= ..Strip(c.orders.%Get(0)), "another seed changes the content")
	; the same calls give the same answers
	Set C = "SignalNoir.Tests.Sim.Contract.Client"
	For code = "", "GLIC-S", "GLIC-P" {
		Set ra = ..Answer(a, code), rb = ..Answer(b, code)
		Do $$$AssertEquals(ra, rb, "same answer for " _ $Select(code = "": "the raw Order", 1: code))
	}
}

/// Status and body of a delivery, without the per-instance ids and times
ClassMethod Answer(x As %DynamicObject, code As %String) As %String
{
	Set order = {}.%FromJSON(x.orders.%Get(0).%ToJSON())
	If code '= "" Set order.exams = [{"code": (code)}]
	Set C = "SignalNoir.Tests.Sim.Contract.Client"
	Set r = $ClassMethod(C, "Call", "POST", "/partners/" _ x.partnerId _ "/orders", $ClassMethod(C, "Delivery", x.sci, order, "idk_det_" _ code _ $Extract(x.sci, 5, 25)))
	Set text = r.text
	For f = x.orders.%Get(0).orderId, x.sci, $Extract(x.sci, 5, *) Set text = $Replace(text, f, "")
	If $IsObject(r.body) && r.body.%IsDefined("receiptId") Set text = "receipt"
	Return r.status _ " " _ text
}

Method TestConcurrentInstances()
{
	For i = 1 : 1 : 4 Job ##class(SignalNoir.Tests.Sim.Core.TestDeterminism).Make(i)
	For i = 1 : 1 : 200 {
		Quit:($Get(^SignalNoir.Tests.Sim.Det("done")) >= 4)
		Hang 0.1
	}
	Kill ids
	Set dup = 0, k = ""
	For {
		Set k = $Order(^SignalNoir.Tests.Sim.Det("ids", k))
		Quit:k=""
		Set id = ""
		For {
			Set id = $Order(^SignalNoir.Tests.Sim.Det("ids", k, id))
			Quit:id=""
			If $Data(ids(id)) Set dup = dup + 1
			Set ids(id) = ""
		}
	}
	Do $$$AssertEquals($Get(^SignalNoir.Tests.Sim.Det("done")), 4, "four instances")
	Do $$$AssertEquals(dup, 0, "no shared ids")
	Kill ^SignalNoir.Tests.Sim.Det
}

ClassMethod Make(n As %Integer)
{
	Set x = ##class(SignalNoir.Tests.Sim.Contract.Client).Emitted("clean", "clean-success-tune-01", 7)
	Set ^SignalNoir.Tests.Sim.Det("ids", n, x.sci) = ""
	Set ^SignalNoir.Tests.Sim.Det("ids", n, x.orders.%Get(0).orderId) = ""
	If $Increment(^SignalNoir.Tests.Sim.Det("done"))
}

}
