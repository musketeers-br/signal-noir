Class SignalNoir.Tests.Core.TestEffectKey Extends %UnitTest.TestCase
{

/// 008 T003 - the effect key identifies the effect (Order, Partner,
/// canonical payload), never the Proposal (research R3, API-Q11)
Method TestCanonical()
{
	Set a = {"b": 1, "a": {"y": [3, {"q": 1, "p": 2}], "x": "s"}}
	Do $$$AssertEquals(##class(SignalNoir.Core.EffectKey).Canonical(a), "{""a"":{""x"":""s"",""y"":[3,{""p"":2,""q"":1}]},""b"":1}", "keys sorted at every level, arrays in order")
	Do $$$AssertEquals(##class(SignalNoir.Core.EffectKey).Canonical({"t": true, "n": null, "f": 1.5}), "{""f"":1.5,""n"":null,""t"":true}", "JSON types kept")
}

Method TestDerive()
{
	Set p1 = {"orderId": "ORD-1", "exams": [{"code": "HEMO"}], "patient": {"name": "Ana", "patientId": "P1"}}
	Set p2 = {"patient": {"patientId": "P1", "name": "Ana"}, "exams": [{"code": "HEMO"}], "orderId": "ORD-1"}
	Set k1 = ##class(SignalNoir.Core.EffectKey).Derive("ORD-1", "labpartner-a", p1)
	Do $$$AssertEquals(k1, ##class(SignalNoir.Core.EffectKey).Derive("ORD-1", "labpartner-a", p2), "same payload, keys in another order")
	Do $$$AssertTrue(k1 '= ##class(SignalNoir.Core.EffectKey).Derive("ORD-1", "labpartner-a", {"orderId": "ORD-1", "exams": [{"code": "HEMO2"}]}), "another payload")
	Do $$$AssertTrue(k1 '= ##class(SignalNoir.Core.EffectKey).Derive("ORD-2", "labpartner-a", p1), "another Order")
	Do $$$AssertTrue(k1 '= ##class(SignalNoir.Core.EffectKey).Derive("ORD-1", "labpartner-b", p1), "another Partner")
	Do $$$AssertEquals($Extract(k1, 1, 4), "bek_", "prefix")
	Do $$$AssertTrue(($Length(k1) >= 8) && ($Length(k1) <= 128), "the Partner's key length")
}

}
