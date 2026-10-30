Class SignalNoir.Tests.Core.Validator.TestDtos Extends %UnitTest.TestCase
{

/// 004 T004 - the Validator port v2 DTOs (contracts/validation-input.md and the
/// contract's PreconditionResult). ValidatorVerdict v2 is an [edit] of a file
/// merged by 006/009 and is covered once Henry agrees (T002).
ClassMethod Example() As %DynamicObject
{
	Return {
		"proposal": {
			"proposalId": "prop_000045", "caseId": "case_000123", "origin": "agent",
			"action": "APPLY_APPROVED_MAPPING",
			"params": {"mappingId": "map_glicj_plasma", "mappingVersion": "2026.10.1"},
			"scope": "single_case", "confidence": "HIGH",
			"preconditions": [{"check": "ORDER_ACTIVE_AT_ORIGIN", "expected": true}, {"check": "MAPPING_VERSION_UNCHANGED", "expected": "2026.10.1"}],
			"versions": {"policy": "2026.10.1", "mapping": "2026.10.1"},
			"priorReceiptCandidate": null
		},
		"evidence": [{"evidenceId": "evid_1", "caseId": "case_000123", "kind": "fact", "source": "tool.policies"}],
		"order": {"orderId": "ord_1", "specimen": {"type": "plasma"}},
		"priorReceiptOrder": null,
		"attemptCount": 1,
		"run": {"inRun": false, "runId": null, "policyVersion": null, "mappingVersion": null},
		"reference": {"policyVersion": "2026.10.1", "mappingVersion": "2026.10.1", "policies": {"attempt": {"maxAttempts": 3}}, "mappings": [{"mappingId": "map_glicj_plasma"}], "synonyms": {"specimenType": {"SERUM": ["SERUM", "SORO"]}}},
		"observed": null,
		"now": "2026-10-29T13:02:11Z"
	}
}

Method TestValidationInputFromJson()
{
	Set in = ##class(SignalNoir.Core.Dto.ValidationInput).FromJson(..Example())
	Do $$$AssertTrue($IsObject(in), "built")
	Do $$$AssertEquals(in.proposal.proposalId _ ":" _ in.proposal.action _ ":" _ in.proposal.confidence, "prop_000045:APPLY_APPROVED_MAPPING:HIGH", "proposal")
	Do $$$AssertEquals(in.proposal.params.mappingId, "map_glicj_plasma", "params")
	Do $$$AssertEquals(in.proposal.preconditions.%Size(), 2, "preconditions")
	Do $$$AssertEquals(in.evidence.%Size(), 1, "evidence")
	Do $$$AssertEquals(in.order.orderId, "ord_1", "order")
	Do $$$AssertEquals(in.priorReceiptOrder, "", "no prior receipt order")
	Do $$$AssertEquals(in.attemptCount, 1, "attemptCount")
	Do $$$AssertEquals(in.run.inRun, 0, "not in a run")
	Do $$$AssertEquals(in.reference.policyVersion, "2026.10.1", "reference")
	Do $$$AssertEquals(in.observed, "", "no observed values")
	Do $$$AssertEquals(in.now, "2026-10-29T13:02:11Z", "now")
}

Method TestValidationInputHasNoIdentityField()
{
	Do $$$AssertTrue('##class(%Dictionary.CompiledProperty).%ExistsId("SignalNoir.Core.Dto.ValidationInput||identity"), "no identity property: the Validator derives it (Principle III)")
	Set in = ##class(SignalNoir.Core.Dto.ValidationInput).FromJson({"proposal": {}, "identity": {"collisions": []}, "now": "2026-10-29T13:02:11Z"})
	Do $$$AssertTrue($IsObject(in), "a caller-supplied identity is ignored, not an error")
	Do $$$AssertTrue('$IsObject(in.ToJson().%Get("identity")), "and never echoed back")
}

Method TestValidationInputRoundTrip()
{
	Set in = ##class(SignalNoir.Core.Dto.ValidationInput).FromJson(..Example())
	Set j = in.ToJson()
	Do $$$AssertEquals(j.proposal.action, "APPLY_APPROVED_MAPPING", "action")
	Do $$$AssertEquals(j.proposal.preconditions.%Get(0).expected, 1, "boolean expected kept")
	Do $$$AssertEquals(j.proposal.preconditions.%GetTypeOf(0), "object", "preconditions are objects")
	Do $$$AssertEquals(j.attemptCount, 1, "attemptCount")
	Do $$$AssertEquals(j.reference.synonyms.specimenType.SERUM.%Get(1), "SORO", "synonyms")
	Do $$$AssertEquals(j.%GetTypeOf("priorReceiptOrder"), "null", "null stays null")
	Do $$$AssertEquals(j.%GetTypeOf("observed"), "null", "observed null")
	Do $$$AssertEquals(j.now, "2026-10-29T13:02:11Z", "now")
}

Method TestPreconditionResult()
{
	Set r = ##class(SignalNoir.Core.Dto.PreconditionResult).FromJson({"check": "MAPPING_VERSION_UNCHANGED", "expected": "2026.10.1", "observed": "2026.10.2", "passed": false, "evidenceId": null})
	Do $$$AssertEquals(r.check, "MAPPING_VERSION_UNCHANGED", "check")
	Do $$$AssertEquals(r.passed, 0, "passed")
	Set j = r.ToJson()
	Do $$$AssertEquals(j.check _ ":" _ j.expected _ ":" _ j.observed, "MAPPING_VERSION_UNCHANGED:2026.10.1:2026.10.2", "values")
	Do $$$AssertEquals(j.%GetTypeOf("passed"), "boolean", "passed is a boolean")
	Do $$$AssertEquals(j.%GetTypeOf("evidenceId"), "null", "evidenceId null when absent")
	Set b = ##class(SignalNoir.Core.Dto.PreconditionResult).FromJson({"check": "ORDER_ACTIVE_AT_ORIGIN", "expected": true, "observed": true, "passed": true, "evidenceId": "evid_9"}).ToJson()
	Do $$$AssertEquals(b.%GetTypeOf("expected") _ ":" _ b.%GetTypeOf("observed"), "boolean:boolean", "booleans stay booleans")
	Do $$$AssertEquals(b.evidenceId, "evid_9", "evidenceId")
}

Method TestAdmission()
{
	Set a = ##class(SignalNoir.Core.Dto.Admission).FromJson({"admissible": true, "label": "human"})
	Do $$$AssertEquals(a.admissible, 1, "admissible")
	Set j = a.ToJson()
	Do $$$AssertEquals(j.%GetTypeOf("admissible") _ ":" _ j.label, "boolean:human", "admissible shape")
	Do $$$AssertEquals(j.%GetTypeOf("reason"), "unassigned", "no reason when admissible")
	Set n = ##class(SignalNoir.Core.Dto.Admission).FromJson({"admissible": false, "reason": "ACTOR_NOT_ALLOWED_TO_APPROVE"}).ToJson()
	Do $$$AssertEquals(n.admissible _ ":" _ n.reason, "0:ACTOR_NOT_ALLOWED_TO_APPROVE", "refusal")
}

Method TestReferenceData()
{
	Set ref = ##class(SignalNoir.Core.Dto.ReferenceData).FromJson(..Example().reference)
	Do $$$AssertEquals(ref.policyVersion _ ":" _ ref.mappingVersion, "2026.10.1:2026.10.1", "versions")
	Do $$$AssertEquals(ref.policies.attempt.maxAttempts, 3, "policies")
	Do $$$AssertEquals(ref.mappings.%Size(), 1, "mappings")
	Set j = ref.ToJson()
	Do $$$AssertEquals(j.mappings.%Get(0).mappingId, "map_glicj_plasma", "round trip")
	Do $$$AssertEquals(j.synonyms.specimenType.SERUM.%Size(), 2, "synonyms")
}

}
