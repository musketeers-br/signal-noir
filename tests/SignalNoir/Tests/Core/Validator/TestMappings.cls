Class SignalNoir.Tests.Core.Validator.TestMappings Extends %UnitTest.TestCase
{

Parameter INPUTS = "SignalNoir.Tests.Core.Validator.Inputs";

/// 004 T023 - US2: an approved Mapping is applied only when that exact id and version exist in
/// the reference data in force, its source code is among the Order's exams and every condition
/// matches the Order (FR-004, FR-005, SC-006).
ClassMethod Validate(mappingId As %String, version As %String, order As %DynamicObject) As SignalNoir.Core.Dto.ValidatorVerdict
{
	Set proposal = $ClassMethod(..#INPUTS, "Proposal", "APPLY_APPROVED_MAPPING", $ClassMethod(..#INPUTS, "MappingParams", mappingId, version))
	Set input = $ClassMethod(..#INPUTS, "Input", proposal, "", order)
	Return ##class(SignalNoir.Core.Validator).%New().Validate(input)
}

ClassMethod Codes(verdict As SignalNoir.Core.Dto.ValidatorVerdict) As %String
{
	Set out = ""
	For i = 1 : 1 : verdict.reasons.Count() Set out = out _ $Select(out = "": "", 1: ",") _ verdict.reasons.GetAt(i)
	Return out
}

Method TestThePlasmaMappingAppliesToAPlasmaOrder()
{
	Set v = ..Validate("map_glicj_plasma", "2026.10.1", $ClassMethod(..#INPUTS, "PlasmaOrder"))
	Do $$$AssertEquals(v.verdict, "accepted", "accepted")
	Set lead = "ACTION_IN_CATALOG,PARAMS_VALID,MAPPING_CONDITION_MATCHES"
	Do $$$AssertEquals($Extract(..Codes(v), 1, $Length(lead)), lead, "the Mapping condition is among the reasons: " _ ..Codes(v))
	Do $$$AssertTrue(v.requiresApproval, "a Mapping has an external effect")
}

Method TestTheSerumMappingDoesNotApplyToAPlasmaOrder()
{
	Set v = ..Validate("map_glicj_soro", "2026.10.1", $ClassMethod(..#INPUTS, "PlasmaOrder"))
	Do $$$AssertEquals(v.verdict, "blocked", "blocked")
	Do $$$AssertEquals(..Codes(v), "MAPPING_CONDITION_MISMATCH", "the condition does not match")
	Do $$$AssertTrue(v.requiresApproval, "requiresApproval stays the catalog's")
}

Method TestAMappingThatIsNotInForceIsNotFound()
{
	Set order = $ClassMethod(..#INPUTS, "PlasmaOrder")
	Set v = ..Validate("map_does_not_exist", "2026.10.1", order)
	Do $$$AssertEquals(v.verdict _ " " _ ..Codes(v), "blocked MAPPING_NOT_FOUND", "an unknown id")
	Set v = ..Validate("map_glicj_plasma", "2026.10.9", order)
	Do $$$AssertEquals(v.verdict _ " " _ ..Codes(v), "blocked MAPPING_NOT_FOUND", "a known id with a version that does not exist")
	Set v = ..Validate("MAP_GLICJ_PLASMA", "2026.10.1", order)
	Do $$$AssertEquals(v.verdict _ " " _ ..Codes(v), "blocked MAPPING_NOT_FOUND", "ids are exact, not case-insensitive")
}

Method TestTheSourceCodeMustBeInTheOrder()
{
	Set v = ..Validate("map_tsh_legacy", "2026.10.1", $ClassMethod(..#INPUTS, "PlasmaOrder"))
	Do $$$AssertEquals(v.verdict _ " " _ ..Codes(v), "blocked MAPPING_SOURCE_CODE_ABSENT", "the Order has GLIC-J, not TSH-OLD")
	Set order = $ClassMethod(..#INPUTS, "PlasmaOrder")
	Set order.exams = [{"code": "glic-j"}]
	Set v = ..Validate("map_glicj_plasma", "2026.10.1", order)
	Do $$$AssertEquals(v.verdict, "accepted", "the code is compared case-insensitively")
}

Method TestTheSpecimenTypeIsComparedCanonically()
{
	For type = "plasma", "PLASMA", "Plasma", "  plasma  " {
		Set order = $ClassMethod(..#INPUTS, "PlasmaOrder")
		Set order.specimen.type = type
		Set v = ..Validate("map_glicj_plasma", "2026.10.1", order)
		Do $$$AssertEquals(v.verdict, "accepted", "'" _ type _ "' is plasma")
	}
	For type = "soro", "SERUM", "Serum", " SORO " {
		Set order = $ClassMethod(..#INPUTS, "SerumOrder")
		Set order.specimen.type = type
		Set v = ..Validate("map_glicj_soro", "2026.10.1", order)
		Do $$$AssertEquals(v.verdict, "accepted", "'" _ type _ "' is serum")
		Set v = ..Validate("map_glicj_plasma", "2026.10.1", order)
		Do $$$AssertEquals(..Codes(v), "MAPPING_CONDITION_MISMATCH", "'" _ type _ "' is not plasma")
	}
}

Method TestAMappingWithoutConditionsAppliesToAnyOrderWithItsCode()
{
	Set v = ..Validate("map_tsh_legacy", "2026.10.1", $ClassMethod(..#INPUTS, "LegacyTshOrder"))
	Do $$$AssertEquals(v.verdict, "accepted", "accepted")
	Do $$$AssertEquals(..Codes(v), "ACTION_IN_CATALOG,PARAMS_VALID,REQUIRED_EVIDENCE_PRESENT", "no condition reason, because there is no condition")
	Set order = $ClassMethod(..#INPUTS, "LegacyTshOrder")
	Set order.specimen = {}
	Set v = ..Validate("map_tsh_legacy", "2026.10.1", order)
	Do $$$AssertEquals(v.verdict, "accepted", "even when the Order has no specimen data")
}

Method TestAConditionOnAnAbsentOrderFieldDoesNotMatch()
{
	Set order = $ClassMethod(..#INPUTS, "PlasmaOrder")
	Set order.specimen = {"specimenId": "SP-1"}
	Set v = ..Validate("map_glicj_plasma", "2026.10.1", order)
	Do $$$AssertEquals(v.verdict _ " " _ ..Codes(v), "blocked MAPPING_CONDITION_MISMATCH,EVIDENCE_MISSING_ORDER_FIELD", "no specimen type in the Order: no match, and the Order-field Evidence is missing")
}

Method TestExactlyOneOfTheTwoGlicjMappingsAppliesToEachOrder()
{
	For name = "PlasmaOrder", "SerumOrder" {
		Set order = $ClassMethod(..#INPUTS, name)
		Set accepted = 0
		For id = "map_glicj_plasma", "map_glicj_soro" {
			If ..Validate(id, "2026.10.1", order).verdict = "accepted" Set accepted = accepted + 1
		}
		Do $$$AssertEquals(accepted, 1, name _ ": exactly one of the two Mappings for GLIC-J is accepted")
	}
}

Method TestTheMappingsComeFromTheSnapshotOfTheRun()
{
	Set proposal = $ClassMethod(..#INPUTS, "Proposal", "APPLY_APPROVED_MAPPING", $ClassMethod(..#INPUTS, "MappingParams", "map_glicj_soro"))
	Set input = $ClassMethod(..#INPUTS, "Input", proposal, "", $ClassMethod(..#INPUTS, "SerumOrder"))
	Set thin = []
	Set it = input.reference.mappings.%GetIterator()
	While it.%GetNext(.k, .item) {
		If item.mappingId '= "map_glicj_soro" Do thin.%Push(item)
	}
	Set input.reference.mappings = thin
	Set v = ##class(SignalNoir.Core.Validator).%New().Validate(input)
	Do $$$AssertEquals(v.verdict _ " " _ ..Codes(v), "blocked MAPPING_NOT_FOUND", "a snapshot without the Mapping does not know it")
}

Method TestTheSynonymsComeFromTheSnapshotToo()
{
	Set proposal = $ClassMethod(..#INPUTS, "Proposal", "APPLY_APPROVED_MAPPING", $ClassMethod(..#INPUTS, "MappingParams", "map_glicj_soro"))
	Set input = $ClassMethod(..#INPUTS, "Input", proposal, "", $ClassMethod(..#INPUTS, "SerumOrder"))
	Set input.reference.synonyms = {}
	Set v = ##class(SignalNoir.Core.Validator).%New().Validate(input)
	Do $$$AssertEquals(v.verdict _ " " _ ..Codes(v), "blocked MAPPING_CONDITION_MISMATCH", "without the synonym list, 'soro' is not SERUM")
}

Method TestTheOriginDoesNotChangeAMappingVerdict()
{
	Set expected = ""
	For origin = "agent", "rules", "operator:ana", "benchmark" {
		Set proposal = $ClassMethod(..#INPUTS, "Proposal", "APPLY_APPROVED_MAPPING", $ClassMethod(..#INPUTS, "MappingParams", "map_glicj_soro"))
		Set proposal.origin = origin
		Set input = $ClassMethod(..#INPUTS, "Input", proposal, "", $ClassMethod(..#INPUTS, "PlasmaOrder"))
		Set json = ##class(SignalNoir.Core.Validator).%New().Validate(input).ToJson().%ToJSON()
		If expected = "" Set expected = json
		Do $$$AssertEquals(json, expected, origin _ ": the same blocked verdict")
	}
}

}
