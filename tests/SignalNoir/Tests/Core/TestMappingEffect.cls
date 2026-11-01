Class SignalNoir.Tests.Core.TestMappingEffect Extends %UnitTest.TestCase
{

/// 004/008 - the Order an approved Mapping sends: the source code becomes the target code, the
/// rest is sent as received, and nothing is guessed
ClassMethod Glic() As %DynamicObject
{
	Return {"mappingId": "map_glicj_soro", "mappingVersion": "2026.10.1", "sourceCode": "GLIC-J", "targetCode": "GLIC-S", "conditions": {"specimenType": "SERUM"}}
}

Method TestTheSourceCodeBecomesTheTargetCode()
{
	Set snapshot = {"orderId": "ORD-1", "exams": [{"code": " glic-j "}, {"code": "HEMO"}], "specimen": {"type": "soro"}}
	Set r = ##class(SignalNoir.Core.MappingEffect).Payload(snapshot, ..Glic())
	Do $$$AssertTrue(r.ok, r.message)
	Do $$$AssertEquals(r.obj.exams.%Get(0).code, "GLIC-S", "trimmed, case insensitive")
	Do $$$AssertEquals(r.obj.exams.%Get(1).code, "HEMO", "other exams as received")
	Do $$$AssertEquals(r.obj.specimen.type _ " " _ r.obj.orderId, "soro ORD-1", "the rest as received")
	Do $$$AssertEquals(snapshot.exams.%Get(0).code, " glic-j ", "the snapshot is not changed")
}

Method TestAnOrderWithoutTheSourceCodeIsRefused()
{
	Set r = ##class(SignalNoir.Core.MappingEffect).Payload({"exams": [{"code": "HEMO"}]}, ..Glic())
	Do $$$AssertNotTrue(r.ok, "refused")
	Do $$$AssertTrue(r.message [ "mapping unavailable: the Order has no exam GLIC-J", r.message)
}

Method TestAMappingWithoutCodesIsRefused()
{
	Set m = ..Glic()
	Do m.%Remove("targetCode")
	Set r = ##class(SignalNoir.Core.MappingEffect).Payload({"exams": [{"code": "GLIC-J"}]}, m)
	Do $$$AssertNotTrue(r.ok, "refused")
	Do $$$AssertTrue(r.message [ "mapping unavailable", r.message)
}

}
