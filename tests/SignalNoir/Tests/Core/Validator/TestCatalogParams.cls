Class SignalNoir.Tests.Core.Validator.TestCatalogParams Extends %UnitTest.TestCase
{

Parameter INPUTS = "SignalNoir.Tests.Core.Validator.Inputs";

/// 004 T016 - US1: the closed Action catalog, the parameters each Action allows and the
/// single-Case scope (FR-001..FR-003, FR-017). Steps 1-4 of the pipeline stop on failure, so a
/// blocked verdict here carries exactly one reason. An accepted verdict is checked by its
/// leading codes, because the steps added by later stories append their own pass codes.
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

/// An input for an Action with the Evidence and Order that suit it
ClassMethod InputOf(action As %String, params As %DynamicObject = "") As SignalNoir.Core.Dto.ValidationInput
{
	Return $ClassMethod(..#INPUTS, "Input", $ClassMethod(..#INPUTS, "Proposal", action, params))
}

/// True when the codes start with the expected ones
ClassMethod StartsWith(codes As %String, prefix As %String) As %Boolean
{
	Return ($Extract(codes, 1, $Length(prefix)) = prefix) && (($Length(codes) = $Length(prefix)) || ($Extract(codes, $Length(prefix) + 1) = ","))
}

Method AssertBlocked(input, code As %String, label As %String)
{
	Set v = ..Validate(input)
	Do $$$AssertEquals(v.verdict, "blocked", label _ ": blocked")
	Do $$$AssertEquals(..Codes(v), code, label _ ": the one reason")
}

Method TestEachActionWithValidParametersIsAccepted()
{
	Set v = ..Validate(..InputOf("RETRY"))
	Do $$$AssertEquals(v.verdict, "accepted", "RETRY takes no parameters")
	Do $$$AssertTrue(..StartsWith(..Codes(v), "ACTION_IN_CATALOG"), "RETRY starts with ACTION_IN_CATALOG: " _ ..Codes(v))
	Do $$$AssertTrue(v.requiresApproval, "RETRY has an external effect")

	Set v = ..Validate(..InputOf("HOLD"))
	Do $$$AssertEquals(v.verdict, "accepted", "HOLD without parameters")
	Do $$$AssertTrue(..StartsWith(..Codes(v), "ACTION_IN_CATALOG"), "HOLD starts with ACTION_IN_CATALOG: " _ ..Codes(v))
	Do $$$AssertTrue('v.requiresApproval, "HOLD needs no Approval")
	Set v = ..Validate(..InputOf("HOLD", {"reason": "partner is degrading"}))
	Do $$$AssertEquals(v.verdict, "accepted", "HOLD takes an optional reason")

	Set v = ..Validate(..InputOf("APPLY_APPROVED_MAPPING", $ClassMethod(..#INPUTS, "MappingParams")))
	Do $$$AssertEquals(v.verdict, "accepted", "APPLY_APPROVED_MAPPING with both mandatory parameters")
	Do $$$AssertTrue(..StartsWith(..Codes(v), "ACTION_IN_CATALOG,PARAMS_VALID"), "mapping parameters are reported valid: " _ ..Codes(v))
	Do $$$AssertTrue(v.requiresApproval, "a Mapping has an external effect")
}

Method TestAnActionOutsideTheCatalogIsBlocked()
{
	For action = "DELETE_ORDER", "CANCEL_ORDER", "retry", "RETRY ", "" {
		Do ..AssertBlocked(..InputOf(action), "ACTION_NOT_IN_CATALOG", "Action '" _ action _ "'")
	}
	Set v = ..Validate(..InputOf("DELETE_ORDER"))
	Do $$$AssertTrue('v.requiresApproval, "an Action that is not in the catalog has no effect to approve")
}

Method TestTheMappingParametersAreMandatory()
{
	Do ..AssertBlocked(..InputOf("APPLY_APPROVED_MAPPING"), "PARAMS_INVALID", "no parameters")
	Do ..AssertBlocked(..InputOf("APPLY_APPROVED_MAPPING", {"mappingId": "map_glicj_plasma"}), "PARAMS_INVALID", "no mappingVersion")
	Do ..AssertBlocked(..InputOf("APPLY_APPROVED_MAPPING", {"mappingVersion": "2026.10.1"}), "PARAMS_INVALID", "no mappingId")
	Do ..AssertBlocked(..InputOf("APPLY_APPROVED_MAPPING", {"mappingId": "", "mappingVersion": "2026.10.1"}), "PARAMS_INVALID", "empty mappingId")
	Do ..AssertBlocked(..InputOf("APPLY_APPROVED_MAPPING", {"mappingId": "map_glicj_plasma", "mappingVersion": ""}), "PARAMS_INVALID", "empty mappingVersion")
	Do ..AssertBlocked(..InputOf("APPLY_APPROVED_MAPPING", {"mappingId": 7, "mappingVersion": "2026.10.1"}), "PARAMS_INVALID", "mappingId that is not a string")
	Do ..AssertBlocked(..InputOf("APPLY_APPROVED_MAPPING", {"mappingId": "map_glicj_plasma", "mappingVersion": ["2026.10.1"]}), "PARAMS_INVALID", "mappingVersion that is not a string")
}

Method TestAParameterTheActionDoesNotDeclareIsInvalid()
{
	Do ..AssertBlocked(..InputOf("RETRY", {"reason": "try again"}), "PARAMS_INVALID", "RETRY with a reason")
	Do ..AssertBlocked(..InputOf("RETRY", {"delaySeconds": 30}), "PARAMS_INVALID", "RETRY with any parameter")
	Do ..AssertBlocked(..InputOf("HOLD", {"mappingId": "map_glicj_plasma"}), "PARAMS_INVALID", "HOLD with a mapping id")
	Do ..AssertBlocked(..InputOf("HOLD", {"reason": "x", "until": "tomorrow"}), "PARAMS_INVALID", "HOLD with an extra parameter beside reason")
	Do ..AssertBlocked(..InputOf("HOLD", {"reason": 5}), "PARAMS_INVALID", "HOLD with a reason that is not a string")
	Do ..AssertBlocked(..InputOf("REQUEST_REVIEW", {"mappingId": "map_glicj_plasma"}), "PARAMS_INVALID", "REQUEST_REVIEW with a mapping id")
	Do ..AssertBlocked(..InputOf("APPLY_APPROVED_MAPPING", {"mappingId": "map_glicj_plasma", "mappingVersion": "2026.10.1", "reason": "x"}), "PARAMS_INVALID", "APPLY_APPROVED_MAPPING with a reason")
	Do ..AssertBlocked(..InputOf("APPLY_APPROVED_MAPPING", {"mappingId": "map_glicj_plasma", "mappingVersion": "2026.10.1", "targetCode": "GLIC-S"}), "PARAMS_INVALID", "APPLY_APPROVED_MAPPING that tries to choose the target code")
}

Method TestOnlyASingleCaseScopeIsValid()
{
	For scope = "all_cases", "batch", "single_case ", "SINGLE_CASE", "" {
		Set input = ..InputOf("RETRY")
		Set input.proposal.scope = scope
		Do ..AssertBlocked(input, "SCOPE_INVALID", "scope '" _ scope _ "'")
	}
	Set input = ..InputOf("RETRY")
	Do $$$AssertEquals(..Validate(input).verdict, "accepted", "single_case is the one valid scope")
}

Method TestAReviewRequestIsAlwaysAccepted()
{
	Set v = ..Validate(..InputOf("REQUEST_REVIEW"))
	Do $$$AssertEquals(v.verdict, "accepted", "accepted")
	Do $$$AssertEquals(..Codes(v), "REVIEW_ALWAYS_ACCEPTED", "with its own reason and nothing else")
	Do $$$AssertTrue('v.requiresApproval, "it stops automation and has nothing to authorize")
	Set v = ..Validate(..InputOf("REQUEST_REVIEW", {"reason": "no safe action"}))
	Do $$$AssertEquals(v.verdict, "accepted", "with the optional reason")
	Set input = ..InputOf("REQUEST_REVIEW")
	Set input.evidence = ##class(%ListOfObjects).%New()
	Set input.proposal.confidence = "LOW"
	Do $$$AssertEquals(..Validate(input).verdict, "accepted", "no Evidence and low confidence do not hold it back")
}

Method TestTheSameInputGivesTheSameVerdict()
{
	For action = "RETRY", "HOLD", "REQUEST_REVIEW", "DELETE_ORDER" {
		Set a = ..Validate(..InputOf(action)).ToJson().%ToJSON()
		Set b = ..Validate(..InputOf(action)).ToJson().%ToJSON()
		Do $$$AssertEquals(a, b, action _ ": twice, identical, reasons and their order included")
	}
	Set input = ..InputOf("APPLY_APPROVED_MAPPING", $ClassMethod(..#INPUTS, "MappingParams"))
	Set first = ..Validate(input).ToJson()
	Set input.now = "2026-10-29T18:00:00Z"
	Set later = ..Validate(input).ToJson()
	Do $$$AssertEquals(later.at, "2026-10-29T18:00:00Z", "at is the clock the caller supplied")
	Set first.at = "", later.at = ""
	Do $$$AssertEquals(first.%ToJSON(), later.%ToJSON(), "a different clock changes nothing but at")
}

Method TestTheOriginDoesNotChangeTheVerdict()
{
	For action = "RETRY", "HOLD", "REQUEST_REVIEW", "APPLY_APPROVED_MAPPING", "DELETE_ORDER" {
		Set params = $Select(action = "APPLY_APPROVED_MAPPING": $ClassMethod(..#INPUTS, "MappingParams"), 1: "")
		Set expected = ""
		For origin = "agent", "rules", "operator:ana", "benchmark", "replay" {
			Set input = ..InputOf(action, params)
			Set input.proposal.origin = origin
			Set json = ..Validate(input).ToJson().%ToJSON()
			If expected = "" Set expected = json
			Do $$$AssertEquals(json, expected, action _ " from " _ origin _ ": same verdict as from the first origin")
		}
	}
}

Method TestAMissingPieceIsBlockedAndNeverAnException()
{
	Set input = ..InputOf("RETRY")
	Set input.proposal.confidence = ""
	Do ..AssertBlocked(input, "PARAMS_INVALID", "no confidence")
	Set input = ..InputOf("RETRY")
	Set input.proposal.confidence = "CERTAIN"
	Do ..AssertBlocked(input, "PARAMS_INVALID", "a confidence outside HIGH, MEDIUM and LOW")
	Set input = ..InputOf("RETRY")
	Set input.proposal.confidence = "LOW"
	Do $$$AssertNotEquals(..Validate(input).verdict, "blocked", "LOW is a valid confidence: it sends the Proposal to review later, it does not block it here")

	Set input = ..InputOf("RETRY")
	Set input.proposal.versions = ""
	Do ..AssertBlocked(input, "PARAMS_INVALID", "no versions")
	Set input = ..InputOf("RETRY")
	Set input.proposal.versions = {"policy": "2026.10.1"}
	Do ..AssertBlocked(input, "PARAMS_INVALID", "no mapping version")
	Set input = ..InputOf("RETRY")
	Set input.proposal.versions = {"policy": "", "mapping": "2026.10.1"}
	Do ..AssertBlocked(input, "PARAMS_INVALID", "an empty policy version")

	Set input = ..InputOf("RETRY")
	Set input.proposal.params = ""
	Do $$$AssertEquals(..Validate(input).verdict, "accepted", "a Proposal without a parameter object is a Proposal without parameters")
	Set input = ..InputOf("APPLY_APPROVED_MAPPING")
	Set input.proposal.params = ""
	Do ..AssertBlocked(input, "PARAMS_INVALID", "a Mapping Proposal without a parameter object")

	Set input = ..InputOf("RETRY")
	Set input.proposal = ""
	Do ..AssertBlocked(input, "ACTION_NOT_IN_CATALOG", "no Proposal at all")
}

Method TestWithoutReferenceDataNothingPasses()
{
	For action = "RETRY", "HOLD", "REQUEST_REVIEW", "DELETE_ORDER" {
		Set input = ..InputOf(action)
		Set input.reference = ""
		Do ..AssertBlocked(input, "REFERENCE_DATA_UNAVAILABLE", action _ " without a reference snapshot")
	}
	Set input = ..InputOf("RETRY")
	Set input.reference.policyVersion = ""
	Do ..AssertBlocked(input, "REFERENCE_DATA_UNAVAILABLE", "no policy version in force")
	Set input = ..InputOf("RETRY")
	Set input.reference.mappingVersion = ""
	Do ..AssertBlocked(input, "REFERENCE_DATA_UNAVAILABLE", "no mapping version in force")
	Set v = ..Validate("")
	Do $$$AssertEquals(v.verdict, "blocked", "no input at all is blocked, not an exception")
	Do $$$AssertEquals(..Codes(v), "REFERENCE_DATA_UNAVAILABLE", "for lack of reference data")
	Set input = ..InputOf("RETRY")
	Set input.reference = ""
	Do $$$AssertEquals(..Validate(input).ToJson().versions.%Get("policy"), "", "a verdict without reference data names no version")
}

Method TestTheFirstFailingStepStopsThePipeline()
{
	Set input = ..InputOf("DELETE_ORDER", {"anything": 1})
	Set input.proposal.scope = "batch"
	Set input.reference = ""
	Do ..AssertBlocked(input, "REFERENCE_DATA_UNAVAILABLE", "reference data first")
	Set input.reference = $ClassMethod(..#INPUTS, "Reference")
	Do ..AssertBlocked(input, "ACTION_NOT_IN_CATALOG", "then the catalog")
	Set input.proposal.action = "RETRY"
	Do ..AssertBlocked(input, "SCOPE_INVALID", "then the scope")
	Set input.proposal.scope = "single_case"
	Do ..AssertBlocked(input, "PARAMS_INVALID", "then the parameters")
}

Method TestApprovalAndVersionsAreTheCatalogsAndTheSnapshots()
{
	For action = "RETRY", "HOLD", "REQUEST_REVIEW", "APPLY_APPROVED_MAPPING" {
		Set params = $Select(action = "APPLY_APPROVED_MAPPING": $ClassMethod(..#INPUTS, "MappingParams"), 1: "")
		Set v = ..Validate(..InputOf(action, params))
		Do $$$AssertEquals(+v.requiresApproval, +##class(SignalNoir.Core.ActionCatalog).RequiresApproval(action), action _ ": requiresApproval is the catalog's value")
		Do $$$AssertEquals(v.versions.%Get("policy") _ ":" _ v.versions.%Get("mapping"), "2026.10.1:2026.10.1", action _ ": the versions of the snapshot")
		Do $$$AssertEquals(v.at, $Parameter(..#INPUTS, "NOW"), action _ ": at is the supplied clock")
	}
	Set input = ..InputOf("RETRY", {"reason": "x"})
	Set v = ..Validate(input)
	Do $$$AssertEquals(v.verdict, "blocked", "a blocked verdict")
	Do $$$AssertEquals(v.versions.%Get("policy"), "2026.10.1", "still names the versions it was computed with")
	Do $$$AssertTrue(v.requiresApproval, "and still states requiresApproval from the catalog")
}

}
