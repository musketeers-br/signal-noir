Class SignalNoir.Tests.Core.Validator.TestConditions Extends %UnitTest.TestCase
{

Parameter C = "SignalNoir.Core.Conditions";

Parameter INPUTS = "SignalNoir.Tests.Core.Validator.Inputs";

/// 004 T021 - canonical condition matching (FR-005, research D7): values are compared after
/// trim, upper-case and the synonym list of the reference data; a condition on an absent Order
/// field never matches.
ClassMethod Synonyms() As %DynamicObject
{
	Return $ClassMethod(..#INPUTS, "Reference").synonyms
}

ClassMethod Matches(conditions, order) As %Boolean
{
	Return $ClassMethod(..#C, "Matches", conditions, order, ..Synonyms())
}

ClassMethod OrderWith(type As %String = "", unit As %String = "") As %DynamicObject
{
	Set order = $ClassMethod(..#INPUTS, "PlasmaOrder")
	Set order.specimen = {"specimenId": "SP-1"}
	If type '= "" Set order.specimen.type = type
	If unit '= "" Set order.specimen.unit = unit
	Return order
}

Method TestSpecimenTypeIsComparedCanonically()
{
	Set cond = {"specimenType": "PLASMA"}
	For type = "plasma", "PLASMA", "Plasma", "  plasma ", "pLaSmA" {
		Do $$$AssertTrue(..Matches(cond, ..OrderWith(type)), "'" _ type _ "' is PLASMA")
	}
	Set cond = {"specimenType": "SERUM"}
	For type = "soro", "SORO", "Soro", " soro  ", "serum", "SERUM" {
		Do $$$AssertTrue(..Matches(cond, ..OrderWith(type)), "'" _ type _ "' is SERUM")
	}
	Do $$$AssertTrue('..Matches({"specimenType": "PLASMA"}, ..OrderWith("soro")), "serum is not plasma")
	Do $$$AssertTrue('..Matches({"specimenType": "SERUM"}, ..OrderWith("plasma")), "plasma is not serum")
	Do $$$AssertTrue('..Matches({"specimenType": "PLASMA"}, ..OrderWith("sangue total")), "an unknown type matches nothing")
}

Method TestTheConditionValueIsCanonicalToo()
{
	Do $$$AssertTrue(..Matches({"specimenType": "soro"}, ..OrderWith("SERUM")), "a Mapping written with the synonym")
	Do $$$AssertTrue(..Matches({"specimenType": " serum "}, ..OrderWith("Soro")), "spaces and case on both sides")
}

Method TestCanonicalValue()
{
	Set syn = ..Synonyms()
	Do $$$AssertEquals($ClassMethod(..#C, "Canonical", "specimenType", " soro ", syn), "SERUM", "synonym to canonical")
	Do $$$AssertEquals($ClassMethod(..#C, "Canonical", "specimenType", "plasma", syn), "PLASMA", "case")
	Do $$$AssertEquals($ClassMethod(..#C, "Canonical", "specimenType", "urina", syn), "URINA", "no synonym: trimmed and upper-cased")
	Do $$$AssertEquals($ClassMethod(..#C, "Canonical", "specimenUnit", "soro", syn), "SORO", "synonyms are per field")
	Do $$$AssertEquals($ClassMethod(..#C, "Canonical", "specimenType", "soro", ""), "SORO", "without synonyms the value is only normalised")
}

Method TestSpecimenUnit()
{
	Do $$$AssertTrue(..Matches({"specimenUnit": "mg/dL"}, ..OrderWith("plasma", "MG/DL")), "unit compared case-insensitively")
	Do $$$AssertTrue('..Matches({"specimenUnit": "mg/dL"}, ..OrderWith("plasma", "mmol/L")), "a different unit does not match")
	Do $$$AssertTrue('..Matches({"specimenUnit": "mg/dL"}, ..OrderWith("plasma")), "an Order without the unit does not match")
}

Method TestEmptyConditionsAlwaysMatch()
{
	Do $$$AssertTrue(..Matches({}, $ClassMethod(..#INPUTS, "PlasmaOrder")), "no conditions")
	Do $$$AssertTrue(..Matches({}, {}), "no conditions on an empty Order")
	Do $$$AssertTrue(..Matches("", $ClassMethod(..#INPUTS, "PlasmaOrder")), "absent conditions")
}

Method TestAnAbsentOrderFieldNeverMatches()
{
	Do $$$AssertTrue('..Matches({"specimenType": "PLASMA"}, ..OrderWith()), "the Order has no specimen type")
	Do $$$AssertTrue('..Matches({"specimenType": "PLASMA"}, {"orderId": "ORD-1"}), "the Order has no specimen")
	Do $$$AssertTrue('..Matches({"specimenType": "PLASMA"}, ""), "no Order")
	Set order = $ClassMethod(..#INPUTS, "PlasmaOrder")
	Set order.specimen.type = ""
	Do $$$AssertTrue('..Matches({"specimenType": "PLASMA"}, order), "an empty specimen type is absent")
	Set order.specimen.type = 5
	Do $$$AssertTrue('..Matches({"specimenType": "PLASMA"}, order), "a specimen type that is not text")
}

Method TestEveryConditionMustMatch()
{
	Set cond = {"specimenType": "PLASMA", "specimenUnit": "mg/dL"}
	Do $$$AssertTrue(..Matches(cond, ..OrderWith("plasma", "mg/dl")), "both match")
	Do $$$AssertTrue('..Matches(cond, ..OrderWith("plasma", "mmol/L")), "one fails")
	Do $$$AssertTrue('..Matches(cond, ..OrderWith("soro", "mg/dl")), "the other fails")
}

Method TestAFieldTheOrderContractDoesNotDefineNeverMatches()
{
	Do $$$AssertTrue('..Matches({"colour": "RED"}, ..OrderWith("plasma")), "unknown condition field")
	Do $$$AssertTrue('..Matches({"specimenType": ["PLASMA"]}, ..OrderWith("plasma")), "a condition value that is not text")
}

Method TestTheSourceCodeIsAmongTheExamCodes()
{
	Set order = $ClassMethod(..#INPUTS, "PlasmaOrder")
	Do $$$AssertTrue($ClassMethod(..#C, "HasSourceCode", order, "GLIC-J"), "exact")
	Do $$$AssertTrue($ClassMethod(..#C, "HasSourceCode", order, "glic-j"), "case-insensitive")
	Do $$$AssertTrue($ClassMethod(..#C, "HasSourceCode", order, " GLIC-J "), "trimmed")
	Do $$$AssertTrue('$ClassMethod(..#C, "HasSourceCode", order, "TSH-OLD"), "another code")
	Do $$$AssertTrue('$ClassMethod(..#C, "HasSourceCode", order, ""), "an empty code is never found")
	Set order.exams = [{"code": "tsh"}, {"code": "glic-j"}, {"name": "no code"}]
	Do $$$AssertTrue($ClassMethod(..#C, "HasSourceCode", order, "GLIC-J"), "among several exams")
	Do $$$AssertTrue('$ClassMethod(..#C, "HasSourceCode", {"orderId": "x"}, "GLIC-J"), "an Order without exams")
	Do $$$AssertTrue('$ClassMethod(..#C, "HasSourceCode", "", "GLIC-J"), "no Order")
}

}
