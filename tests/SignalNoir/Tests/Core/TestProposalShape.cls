Class SignalNoir.Tests.Core.TestProposalShape Extends %UnitTest.TestCase
{

/// 006 T010 - every origin's answer is converted the same way
ClassMethod Answer() As %DynamicObject
{
	Return {
		"diagnosis": {
			"summary": "Partner rejects exam code GLICJ for serum; an approved mapping exists",
			"claims": [{"text": "HTTP 500 body says unknown exam code", "evidenceIds": ["evid_1"]}, {"text": "Mapping MAP-GLI v3 applies to soro", "evidenceIds": ["evid_2", "evid_1"]}],
			"hypotheses": [{"text": "Partner outage", "status": "discarded", "reason": "health UP and no timeouts", "evidenceIds": ["evid_3"]}, {"text": "Code mapping", "status": "chosen"}]
		},
		"action": "APPLY_APPROVED_MAPPING",
		"params": {"mappingId": "MAP-GLI", "mappingVersion": "3"},
		"confidence": "HIGH",
		"preconditions": [{"check": "MAPPING_VERSION_UNCHANGED", "expected": "3"}, {"check": "PARTNER_HEALTHY_WINDOW", "expected": true}]
	}
}

ClassMethod Ids() As %ListOfDataTypes
{
	Set ids = ##class(%ListOfDataTypes).%New()
	For id = "evid_1", "evid_2", "evid_3" Do ids.Insert(id)
	Return ids
}

Method TestWellFormed()
{
	Set r = ##class(SignalNoir.Core.ProposalShape).Convert(..Answer(), ..Ids(), "agent", {"policy": "p1", "mapping": "m1", "prompt": "v1", "model": "m", "provider": "x"}, {"toolCalls": 5})
	Do $$$AssertTrue(r.ok, "converted")
	Set p = r.obj
	Do $$$AssertEquals(p.origin, "agent", "author")
	Do $$$AssertEquals(p.scope, "single_case", "scope")
	Do $$$AssertEquals(p.action, "APPLY_APPROVED_MAPPING", "action")
	Do $$$AssertEquals(p.params.mappingVersion, "3", "params")
	Do $$$AssertEquals(p.diagnosis.claims.%Size(), 2, "claims")
	Do $$$AssertEquals(p.diagnosis.hypotheses.%Get(0).reason, "health UP and no timeouts", "discard reason")
	Do $$$AssertEquals(p.preconditions.%Size(), 2, "preconditions")
	Do $$$AssertEquals(p.versions.prompt, "v1", "versions")
	Do $$$AssertEquals(p.metrics.toolCalls, 5, "metrics")
}

Method TestRefusals()
{
	Set cases = [
		["action", "SEND_EMAIL", "action:not_in_catalog:SEND_EMAIL"],
		["confidence", "VERY_HIGH", "confidence:invalid"],
		["params", {"mappingId": "MAP-GLI"}, "params.mappingVersion:missing"],
		["params", {"mappingId": "x", "mappingVersion": "1", "payload": "{}"}, "params.payload:unknown"],
		["preconditions", [{"check": "ALWAYS_TRUE", "expected": true}], "preconditions[0].check:unknown"],
		["scope", "batch", "scope:invalid"]
	]
	For i = 0 : 1 : cases.%Size() - 1 {
		Set c = cases.%Get(i)
		Set a = ..Answer()
		Do a.%Set(c.%Get(0), c.%Get(1))
		Set r = ##class(SignalNoir.Core.ProposalShape).Convert(a, ..Ids(), "rules", {}, {})
		Do $$$AssertEquals(r.ok, 0, "refused: " _ c.%Get(2))
		Do $$$AssertEquals(r.code, "invalid_response", "code")
		Do $$$AssertEquals(..Has(r.details.reasons, c.%Get(2)), 1, "reason " _ c.%Get(2))
	}
}

Method TestClaimsMustCiteCaseEvidence()
{
	Set a = ..Answer()
	Do a.diagnosis.claims.%Get(0).%Set("evidenceIds", ["evid_999"])
	Set r = ##class(SignalNoir.Core.ProposalShape).Convert(a, ..Ids(), "agent", {}, {})
	Do $$$AssertEquals(..Has(r.details.reasons, "diagnosis.claims[0].evidenceIds:unknown:evid_999"), 1, "unknown Evidence")
	Set a = ..Answer()
	Do a.diagnosis.claims.%Get(1).%Set("evidenceIds", [])
	Set r = ##class(SignalNoir.Core.ProposalShape).Convert(a, ..Ids(), "agent", {}, {})
	Do $$$AssertEquals(..Has(r.details.reasons, "diagnosis.claims[1].evidenceIds:missing"), 1, "claim without Evidence")
	Set a = ..Answer()
	Do a.diagnosis.hypotheses.%Get(0).%Remove("reason")
	Set r = ##class(SignalNoir.Core.ProposalShape).Convert(a, ..Ids(), "agent", {}, {})
	Do $$$AssertEquals(..Has(r.details.reasons, "diagnosis.hypotheses[0].reason:missing"), 1, "discarded without reason")
}

Method TestNotAnObjectAndText()
{
	Do $$$AssertEquals(##class(SignalNoir.Core.ProposalShape).Convert("RETRY", ..Ids(), "agent", {}, {}).code, "invalid_response", "text answer")
	Set obj = ##class(SignalNoir.Core.ProposalShape).ParseText("```json"_$C(10)_..Answer().%ToJSON()_$C(10)_"```")
	Do $$$AssertTrue($IsObject(obj), "fenced JSON parsed")
	Do $$$AssertEquals(obj.action, "APPLY_APPROVED_MAPPING", "content")
	Do $$$AssertEquals(##class(SignalNoir.Core.ProposalShape).ParseText("I cannot help with that."), "", "refusal prose")
	Do $$$AssertEquals(##class(SignalNoir.Core.ProposalShape).ParseText("{broken"), "", "broken JSON")
}

ClassMethod Has(arr As %DynamicArray, text As %String) As %Boolean
{
	For i = 0 : 1 : arr.%Size() - 1 {
		If arr.%Get(i) = text Return 1
	}
	Return 0
}

}
