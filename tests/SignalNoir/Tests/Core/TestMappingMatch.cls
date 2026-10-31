Class SignalNoir.Tests.Core.TestMappingMatch Extends %UnitTest.TestCase
{

/// 013 T002 - candidate mappings shared by Rules and Decisions
Method TestCandidates()
{
	Set items = [{"mappingId": "a", "sourceCode": "GLIC-J", "conditions": {"specimenType": "SORO"}}, {"mappingId": "b", "sourceCode": "glic-j", "conditions": {"specimenType": "PLASMA"}}, {"mappingId": "c", "sourceCode": "HB"}, {"mappingId": "d", "sourceCode": "TSH"}]
	Set order = {"exams": [{"code": "GLIC-J"}, {"code": "hb"}], "specimen": {"type": "soro"}}
	Set out = ##class(SignalNoir.Core.MappingMatch).Candidates(order, items)
	Set ids = ""
	Set it = out.%GetIterator()
	While it.%GetNext(, .m) { Set ids = ids _ m.mappingId }
	Do $$$AssertEquals(ids, "ac", "exam and specimen condition, case-insensitive")
	Do $$$AssertEquals(##class(SignalNoir.Core.MappingMatch).Candidates("", items).%Size(), 0, "no order")
	Do $$$AssertEquals(##class(SignalNoir.Core.MappingMatch).Candidates(order, "").%Size(), 0, "no catalog")
}

}
