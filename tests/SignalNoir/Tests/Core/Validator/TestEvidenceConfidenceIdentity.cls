Class SignalNoir.Tests.Core.Validator.TestEvidenceConfidenceIdentity Extends %UnitTest.TestCase
{

Parameter INPUTS = "SignalNoir.Tests.Core.Validator.Inputs";

/// 004 T026 - US3: minimum Evidence per Action, retry budget, confidence and identity
/// (FR-006..FR-010, FR-015). Evidence counts only when it is a fact of this Case, not
/// obsolete, not suspicious. A verdict lists every failed check in pipeline order; any block
/// makes it `blocked`, otherwise any review makes it `review`.
ClassMethod Validate(input) As SignalNoir.Core.Dto.ValidatorVerdict
{
	Return ##class(SignalNoir.Core.Validator).%New().Validate(input)
}

ClassMethod Codes(verdict As SignalNoir.Core.Dto.ValidatorVerdict) As %String
{
	Set out = ""
	For i = 1 : 1 : verdict.reasons.Count() Set out = out _ $Select(out = "": "", 1: ",") _ verdict.reasons.GetAt(i)
	Return out
}

/// verdict and codes in one string, for one-line assertions
ClassMethod Outcome(input) As %String
{
	Set v = ..Validate(input)
	Return v.verdict _ " " _ ..Codes(v)
}

ClassMethod Params(action As %String, mappingId As %String = "map_glicj_plasma") As %DynamicObject
{
	Return $Select(action = "APPLY_APPROVED_MAPPING": $ClassMethod(..#INPUTS, "MappingParams", mappingId), 1: "")
}

/// An input with the complete Evidence of the Action, minus the Evidence ids in `drop`
ClassMethod InputWithout(action As %String, drop As %String = "", order As %DynamicObject = "", mappingId As %String = "map_glicj_plasma") As SignalNoir.Core.Dto.ValidationInput
{
	Set kept = ##class(%ListOfObjects).%New()
	Set all = $ClassMethod(..#INPUTS, "EvidenceFor", action)
	For i = 1 : 1 : all.Count() {
		If $ListFind($ListFromString(drop, ","), all.GetAt(i).evidenceId) = 0 Do kept.Insert(all.GetAt(i))
	}
	Set proposal = $ClassMethod(..#INPUTS, "Proposal", action, ..Params(action, mappingId))
	Return $ClassMethod(..#INPUTS, "Input", proposal, kept, order)
}

/// The Evidence of an Action with one item changed by `how`: absence, obsolete, suspicious, other
ClassMethod InputSpoiling(action As %String, evidenceId As %String, how As %String) As SignalNoir.Core.Dto.ValidationInput
{
	Set input = ..InputWithout(action)
	For i = 1 : 1 : input.evidence.Count() {
		Set ev = input.evidence.GetAt(i)
		If ev.evidenceId '= evidenceId Continue
		If how = "absence" Set ev.kind = "absence"
		If how = "obsolete" Set ev.obsoletedBy = "evid_newer"
		If how = "suspicious" Set ev.suspicious = 1
		If how = "other" Set ev.caseId = "case_000999"
	}
	Return input
}

Method TestRetryWithItsEvidenceIsAccepted()
{
	Set input = ..InputWithout("RETRY")
	Do $$$AssertEquals(..Outcome(input), "accepted ACTION_IN_CATALOG,RETRY_BUDGET_AVAILABLE,REQUIRED_EVIDENCE_PRESENT", "AS1: the three items are in")
	Do $$$AssertTrue(..Validate(input).requiresApproval, "RETRY still needs Approval")
}

Method TestRetryMissingEachItem()
{
	Do $$$AssertEquals(..Outcome(..InputWithout("RETRY", "evid_hist")), "review EVIDENCE_MISSING_ATTEMPT_HISTORY", "AS2: attempt history")
	Do $$$AssertEquals(..Outcome(..InputWithout("RETRY", "evid_pol")), "review EVIDENCE_MISSING_POLICY", "AS2: attempt policy")
	Do $$$AssertEquals(..Outcome(..InputWithout("RETRY", "evid_health")), "review EVIDENCE_MISSING_PARTNER_HEALTH", "AS2: partner health")
	Do $$$AssertEquals(..Outcome(..InputWithout("RETRY", "evid_pol,evid_hist,evid_health")), "review EVIDENCE_MISSING_POLICY,EVIDENCE_MISSING_ATTEMPT_HISTORY,EVIDENCE_MISSING_PARTNER_HEALTH", "all three, in the catalog's order")
	Set input = ..InputWithout("RETRY")
	Set input.evidence = ##class(%ListOfObjects).%New()
	Do $$$AssertEquals(..Outcome(input), "review EVIDENCE_MISSING_POLICY,EVIDENCE_MISSING_ATTEMPT_HISTORY,EVIDENCE_MISSING_PARTNER_HEALTH", "no Evidence at all")
}

Method TestThePolicyEvidenceMustCarryTheItem()
{
	Set input = ..InputWithout("RETRY")
	Set input.evidence.GetAt(1).result = {"policyVersion": "2026.10.1", "substitution": {"enabled": true}}
	Do $$$AssertEquals(..Outcome(input), "review EVIDENCE_MISSING_POLICY", "tool.policies without `attempt` is not the attempt policy")
	Set input = ..InputWithout("APPLY_APPROVED_MAPPING")
	Set input.evidence.GetAt(1).result = {"policyVersion": "2026.10.1", "attempt": {"maxAttempts": 3}}
	Do $$$AssertEquals(..Outcome(input), "review EVIDENCE_MISSING_POLICY", "tool.policies without `substitution` is not the substitution policy")
}

Method TestMappingMissingEachItem()
{
	Set ok = ..InputWithout("APPLY_APPROVED_MAPPING")
	Do $$$AssertEquals(..Outcome(ok), "accepted ACTION_IN_CATALOG,PARAMS_VALID,MAPPING_CONDITION_MATCHES,REQUIRED_EVIDENCE_PRESENT", "the three items are in")
	Do $$$AssertEquals(..Outcome(..InputWithout("APPLY_APPROVED_MAPPING", "evid_pol")), "review EVIDENCE_MISSING_POLICY", "AS3: substitution policy")
	Do $$$AssertEquals(..Outcome(..InputWithout("APPLY_APPROVED_MAPPING", "evid_map")), "review EVIDENCE_MISSING_MAPPING", "AS3: the Mapping")
	Set input = ..InputWithout("APPLY_APPROVED_MAPPING")
	Set input.evidence.GetAt(2).result = {"mappingVersion": "2026.10.1", "items": [{"mappingId": "map_tsh_legacy", "mappingVersion": "2026.10.1"}], "synonyms": {}}
	Do $$$AssertEquals(..Outcome(input), "review EVIDENCE_MISSING_MAPPING", "a catalog that does not list this id and version is not Evidence of it")
	Set input = ..InputWithout("APPLY_APPROVED_MAPPING")
	Set input.evidence.GetAt(2).result = {"mappingVersion": "2026.10.1", "items": [{"mappingId": "map_glicj_plasma", "mappingVersion": "2026.10.0"}], "synonyms": {}}
	Do $$$AssertEquals(..Outcome(input), "review EVIDENCE_MISSING_MAPPING", "the version must be the Proposal's")
}

Method TestTheOrderFieldMustBeInTheOrder()
{
	Set order = $ClassMethod(..#INPUTS, "PlasmaOrder")
	Set order.specimen = {"specimenId": "SP-1"}
	Set v = ..Validate(..InputWithout("APPLY_APPROVED_MAPPING", "", order))
	Do $$$AssertEquals(v.verdict _ " " _ ..Codes(v), "blocked MAPPING_CONDITION_MISMATCH,EVIDENCE_MISSING_ORDER_FIELD", "AS3: the field is absent, so the condition does not match and the Evidence is missing")
	Set v = ..Validate(..InputWithout("APPLY_APPROVED_MAPPING", "", $ClassMethod(..#INPUTS, "LegacyTshOrder"), "map_tsh_legacy"))
	Do $$$AssertEquals(v.verdict _ " " _ ..Codes(v), "accepted ACTION_IN_CATALOG,PARAMS_VALID,REQUIRED_EVIDENCE_PRESENT", "a Mapping without conditions depends on no Order field")
}

Method TestAnAbsenceCountsAsMissing()
{
	Do $$$AssertEquals(..Outcome(..InputSpoiling("RETRY", "evid_hist", "absence")), "review EVIDENCE_MISSING_ATTEMPT_HISTORY", "AS3a: requested, but the source could not answer")
	Do $$$AssertEquals(..Outcome(..InputSpoiling("RETRY", "evid_health", "absence")), "review EVIDENCE_MISSING_PARTNER_HEALTH", "partner health recorded as an absence")
	Do $$$AssertEquals(..Outcome(..InputSpoiling("APPLY_APPROVED_MAPPING", "evid_map", "absence")), "review EVIDENCE_MISSING_MAPPING", "the Mapping Evidence recorded as an absence")
	Do $$$AssertEquals(..Outcome(..InputSpoiling("HOLD", "evid_health", "absence")), "review EVIDENCE_MISSING_HEALTH_OR_WINDOW", "HOLD with only an absence")
}

Method TestEvidenceThatDoesNotCount()
{
	For how = "obsolete", "suspicious", "other" {
		Do $$$AssertEquals(..Outcome(..InputSpoiling("RETRY", "evid_health", how)), "review EVIDENCE_MISSING_PARTNER_HEALTH", how _ " Evidence does not count")
		Do $$$AssertEquals(..Outcome(..InputSpoiling("APPLY_APPROVED_MAPPING", "evid_pol", how)), "review EVIDENCE_MISSING_POLICY", how _ " policy Evidence does not count")
	}
}

Method TestHoldNeedsHealthOrAMaintenanceWindow()
{
	Do $$$AssertEquals(..Outcome(..InputWithout("HOLD")), "accepted ACTION_IN_CATALOG,REQUIRED_EVIDENCE_PRESENT", "AS4: partner health alone")
	Do $$$AssertEquals(..Outcome(..InputWithout("HOLD", "evid_health")), "review EVIDENCE_MISSING_HEALTH_OR_WINDOW", "AS4: neither")
	Set input = ..InputWithout("HOLD", "evid_health")
	Set input.evidence = ##class(%ListOfObjects).%New()
	Do input.evidence.Insert($ClassMethod(..#INPUTS, "Evidence", "evid_pol", "tool.policies", $ClassMethod(..#INPUTS, "PoliciesResult")))
	Do $$$AssertEquals(..Outcome(input), "accepted ACTION_IN_CATALOG,REQUIRED_EVIDENCE_PRESENT", "AS4: the policy's maintenance window alone")
	Set input.evidence.GetAt(1).result = {"policyVersion": "2026.10.1", "attempt": {"maxAttempts": 3}}
	Do $$$AssertEquals(..Outcome(input), "review EVIDENCE_MISSING_HEALTH_OR_WINDOW", "a policy result without `maintenanceWindows` is not a window")
	Do $$$AssertTrue('..Validate(input).requiresApproval, "HOLD needs no Approval")
}

Method TestLowConfidenceGoesToReview()
{
	For action = "RETRY", "APPLY_APPROVED_MAPPING", "HOLD" {
		Set input = ..InputWithout(action)
		Set input.proposal.confidence = "LOW"
		Do $$$AssertEquals(..Validate(input).verdict _ " " _ ..Codes(..Validate(input)), "review CONFIDENCE_LOW", "AS5: " _ action)
		Set input.proposal.confidence = "MEDIUM"
		Do $$$AssertEquals(..Validate(input).verdict, "accepted", action _ " with MEDIUM")
	}
}

Method TestAmbiguousIdentityGoesToReview()
{
	For action = "RETRY", "APPLY_APPROVED_MAPPING", "HOLD" {
		Set input = ..InputWithout(action)
		Do input.evidence.Insert($ClassMethod(..#INPUTS, "CollidingEvidence"))
		Do $$$AssertEquals(..Outcome(input), "review IDENTITY_AMBIGUOUS_NO_AUTOMATIC_ACTION", "AS6: " _ action)
	}
	Set input = ..InputWithout("REQUEST_REVIEW")
	Do input.evidence.Insert($ClassMethod(..#INPUTS, "CollidingEvidence"))
	Do $$$AssertEquals(..Outcome(input), "accepted REVIEW_ALWAYS_ACCEPTED,IDENTITY_AMBIGUOUS_NO_AUTOMATIC_ACTION", "AS6: REQUEST_REVIEW is still accepted, and says why a person must look")
	Do $$$AssertTrue('..Validate(input).requiresApproval, "with no Approval")
}

Method TestNoInputFieldClearsTheAmbiguity()
{
	Set input = ..InputWithout("RETRY")
	Do input.evidence.Insert($ClassMethod(..#INPUTS, "CollidingEvidence"))
	Set input.proposal.origin = "operator:ana"
	Set input.observed = {"identity": "clear", "identityStatus": "UNAMBIGUOUS"}
	Set input.priorReceiptOrder = $ClassMethod(..#INPUTS, "PlasmaOrder")
	Set input.proposal.diagnosis = {"summary": "identity confirmed by phone"}
	Do $$$AssertEquals(..Outcome(input), "review IDENTITY_AMBIGUOUS_NO_AUTOMATIC_ACTION", "the caller says the identity is fine; the Evidence says otherwise")
	Set json = input.ToJson()
	Do $$$AssertTrue('json.%IsDefined("identity"), "the input has no identity field to set")
}

Method TestOnlyThisCasesEvidenceShowsACollision()
{
	Set other = $ClassMethod(..#INPUTS, "CollidingEvidence")
	Set other.caseId = "case_000999"
	Set input = ..InputWithout("RETRY")
	Do input.evidence.Insert(other)
	Do $$$AssertEquals(..Validate(input).verdict, "accepted", "a collision recorded on another Case is not this Case's")
	Set suspicious = $ClassMethod(..#INPUTS, "CollidingEvidence")
	Set suspicious.suspicious = 1
	Set input = ..InputWithout("RETRY")
	Do input.evidence.Insert(suspicious)
	Do $$$AssertEquals(..Outcome(input), "review IDENTITY_AMBIGUOUS_NO_AUTOMATIC_ACTION", "suspicious Evidence cannot be used to hide a collision")
}

Method TestRetryBudget()
{
	For n = 0, 1, 2 {
		Set input = ..InputWithout("RETRY")
		Set input.attemptCount = n
		Do $$$AssertEquals(..Outcome(input), "accepted ACTION_IN_CATALOG,RETRY_BUDGET_AVAILABLE,REQUIRED_EVIDENCE_PRESENT", "AS7: " _ n _ " of 3 attempts used")
	}
	For n = 3, 4, 10 {
		Set input = ..InputWithout("RETRY")
		Set input.attemptCount = n
		Do $$$AssertEquals(..Outcome(input), "blocked RETRY_BUDGET_EXHAUSTED", "AS7: " _ n _ " of 3 attempts used")
	}
	Set input = ..InputWithout("RETRY")
	Set input.attemptCount = 1
	Set input.reference.policies.attempt.maxAttempts = 1
	Do $$$AssertEquals(..Outcome(input), "blocked RETRY_BUDGET_EXHAUSTED", "the maximum is the snapshot's, not a constant")
	Set input = ..InputWithout("RETRY")
	Set input.reference.policies = {}
	Do $$$AssertEquals(..Outcome(input), "blocked RETRY_BUDGET_EXHAUSTED", "no attempt policy in the snapshot: the budget is not available")
	Set input = ..InputWithout("HOLD")
	Set input.attemptCount = 9
	Do $$$AssertEquals(..Validate(input).verdict, "accepted", "only RETRY spends the budget")
}

Method TestSeveralFailuresBlockedOverReviewInStepOrder()
{
	Set input = ..InputWithout("RETRY", "evid_hist")
	Do input.evidence.Insert($ClassMethod(..#INPUTS, "CollidingEvidence"))
	Set input.attemptCount = 3
	Set input.proposal.confidence = "LOW"
	Do $$$AssertEquals(..Outcome(input), "blocked RETRY_BUDGET_EXHAUSTED,IDENTITY_AMBIGUOUS_NO_AUTOMATIC_ACTION,EVIDENCE_MISSING_ATTEMPT_HISTORY,CONFIDENCE_LOW", "a block wins; every failed check is listed, in pipeline order")
	Set input.attemptCount = 0
	Do $$$AssertEquals(..Outcome(input), "review IDENTITY_AMBIGUOUS_NO_AUTOMATIC_ACTION,EVIDENCE_MISSING_ATTEMPT_HISTORY,CONFIDENCE_LOW", "without the block, a review")
	Set input = ..InputWithout("APPLY_APPROVED_MAPPING", "evid_pol", "", "map_glicj_soro")
	Do $$$AssertEquals(..Outcome(input), "blocked MAPPING_CONDITION_MISMATCH,EVIDENCE_MISSING_POLICY", "a Mapping block and a missing policy, in order")
}

}
