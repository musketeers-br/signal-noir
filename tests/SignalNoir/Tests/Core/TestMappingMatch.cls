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

/// 010 T053 - with the synonyms the comparison is the Validator's (Core.Conditions)
Method TestCandidatesWithSynonyms()
{
	Set items = [{"mappingId": "plasma", "sourceCode": "GLIC-J", "conditions": {"specimenType": "PLASMA"}}, {"mappingId": "serum", "sourceCode": "GLIC-J", "conditions": {"specimenType": "SERUM"}}, {"mappingId": "unit", "sourceCode": "GLIC-J", "conditions": {"specimenUnit": "ML"}}, {"mappingId": "free", "sourceCode": "HBA1C-L", "conditions": {}}]
	Set synonyms = {"specimenType": {"PLASMA": ["PLASMA"], "SERUM": ["SERUM", "SORO"]}}
	Set order = {"exams": [{"code": " glic-j "}, {"code": "hba1c-l"}], "specimen": {"type": "soro"}}
	Do $$$AssertEquals(..Ids(##class(SignalNoir.Core.MappingMatch).Candidates(order, items, synonyms)), "serum,free", "soro is SERUM; a condition on an absent field never matches")
	Do $$$AssertEquals(..Ids(##class(SignalNoir.Core.MappingMatch).Candidates(order, items)), "free", "without synonyms soro is not SERUM (Decisions unchanged)")
	Do $$$AssertEquals(..Ids(##class(SignalNoir.Core.MappingMatch).Candidates(order, items, {})), "free", "empty synonyms: exact comparison")
}

ClassMethod Ids(out As %DynamicArray) As %String
{
	Set ids = ""
	Set it = out.%GetIterator()
	While it.%GetNext(, .m) { Set ids = ids _ $Select(ids = "": "", 1: ",") _ m.mappingId }
	Return ids
}

}
