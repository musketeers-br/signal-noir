Class SignalNoir.Tests.Core.TestDecisionAnswer Extends %UnitTest.TestCase
{

/// 013 T006/T009 - a typed answer becomes a Proposal only when it is decisive
ClassMethod Evidence() As %DynamicArray
{
	Return [{"evidenceId": "evid_1", "source": "tool.partner_health"}, {"evidenceId": "evid_2", "source": "system.exception"}, {"evidenceId": "evid_3", "source": "tool.mapping_catalog"}]
}

ClassMethod Response(value, probs As %DynamicArray, confidence = 0.85, predicates As %DynamicArray = "") As %DynamicObject
{
	Set answers = [{"type": "choice", "name": "action", "choice": (value), "probabilities": (probs), "confidence": (confidence)}]
	If $IsObject(predicates) {
		Set it = predicates.%GetIterator()
		While it.%GetNext(, .p) { Do answers.%Push(p) }
	}
	Return {"answers": (answers)}
}

ClassMethod Convert(response, candidates = "") As SignalNoir.Core.Result
{
	Return ##class(SignalNoir.Core.DecisionAnswer).Convert(response, ..Evidence(), $Select($IsObject(candidates): candidates, 1: []))
}

Method TestDecisiveHold()
{
	Set preds = [{"type": "predicate", "name": "ev:evid_1", "probability": 0.95}, {"type": "predicate", "name": "ev:evid_2", "probability": 0.4}, {"type": "predicate", "name": "ev:evid_99", "probability": 0.99}]
	Set r = ..Convert(..Response("HOLD", [{"value": "HOLD", "probability": 0.8}, {"value": "RETRY", "probability": 0.1}], 0.82, preds))
	Do $$$AssertTrue(r.ok, "decisive")
	Set a = r.obj
	Do $$$AssertEquals(a.action, "HOLD", "action")
	Do $$$AssertEquals(a.confidence, "HIGH", "confidence level")
	Do $$$AssertEquals(a.preconditions.%Get(0).check, "PARTNER_HEALTHY_WINDOW", "precondition")
	Do $$$AssertEquals(a.diagnosis.claims.%Size(), 1, "one claim: only the known Evidence above threshold")
	Do $$$AssertEquals(a.diagnosis.claims.%Get(0).evidenceIds.%Get(0), "evid_1", "cites evid_1")
	Do $$$AssertNotTrue(a.%ToJSON() [ "evid_99", "unknown id never cited")
	Do $$$AssertTrue(a.diagnosis.summary [ "probability 0.80", "summary states the probability")
}

Method TestMappingAndFallbackClaim()
{
	Set cand = [{"mappingId": "map_glicj_soro", "mappingVersion": "v3", "sourceCode": "GLIC-J", "targetCode": "GLU"}]
	Set r = ..Convert(..Response("APPLY_APPROVED_MAPPING:map_glicj_soro", [{"value": "APPLY_APPROVED_MAPPING:map_glicj_soro", "probability": 0.7}, {"value": "RETRY", "probability": 0.2}], 0.6), cand)
	Do $$$AssertTrue(r.ok, "mapping")
	Do $$$AssertEquals(r.obj.action, "APPLY_APPROVED_MAPPING", "catalog action")
	Do $$$AssertEquals(r.obj.params.mappingId, "map_glicj_soro", "mapping id")
	Do $$$AssertEquals(r.obj.params.mappingVersion, "v3", "mapping version from the candidate")
	Do $$$AssertEquals(r.obj.confidence, "MEDIUM", "medium")
	Do $$$AssertEquals(r.obj.diagnosis.claims.%Get(0).evidenceIds.%Get(0), "evid_2", "no predicate passes: the exception is cited")
	Set r = ..Convert(..Response("APPLY_APPROVED_MAPPING:map_other", [{"value": "APPLY_APPROVED_MAPPING:map_other", "probability": 0.9}]), cand)
	Do $$$AssertEquals(r.code, "invalid_response", "a mapping not offered")
}

Method TestIndecisive()
{
	Set cases = []
	Do cases.%Push([(..Response("RETRY", [{"value": "RETRY", "probability": 0.45}, {"value": "HOLD", "probability": 0.2}])), "uncertain", "proposer uncertain: below threshold"])
	Do cases.%Push([(..Response("RETRY", [{"value": "RETRY", "probability": 0.52}, {"value": "HOLD", "probability": 0.48}])), "uncertain", "proposer uncertain: tie"])
	Do cases.%Push([(..Response("other", [{"value": "other", "probability": 0.9}])), "uncertain", "proposer uncertain: other"])
	Do cases.%Push([{"answers": [{"type": "refusal", "name": "action"}]}, "refused", "refusal on action"])
	Do cases.%Push([{"answers": []}, "refused", "no answer"])
	Do cases.%Push([(..Response("DELETE_ORDER", [{"value": "DELETE_ORDER", "probability": 0.99}])), "invalid_response", ""])
	Do cases.%Push([{"answers": [{"type": "choice", "name": "action", "choice": "RETRY"}, {"type": "choice", "name": "action", "choice": "HOLD"}]}, "invalid_response", ""])
	For i = 0 : 1 : cases.%Size() - 1 {
		Set c = cases.%Get(i)
		Set r = ..Convert(c.%Get(0))
		Do $$$AssertNotTrue(r.ok, "no Proposal " _ i)
		Do $$$AssertEquals(r.code, c.%Get(1), "code " _ i)
		If c.%Get(2) '= "" Do $$$AssertEquals(r.message, c.%Get(2), "reason " _ i)
		If r.code = "uncertain" Set messages(r.message) = ""
	}
	Set n = 0, m = ""
	For { Set m = $Order(messages(m)) Quit:m=""  Set n = n + 1 }
	Do $$$AssertEquals(n, 3, "three distinct uncertainty reasons")
}

}
