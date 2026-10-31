Class SignalNoir.Core.Conditions Extends %RegisteredObject
{

/// Canonical condition matching of 004 (FR-005, research D7). Pure: the Validator, the Rules
/// proposer and the tools use the same comparison, so they cannot disagree about a Mapping.
/// Values are compared after trim, upper-case and the synonym list of the reference data;
/// a condition on an Order field that is absent never matches.
/// The Order path of a condition field; "" for a field the Order contract does not define
ClassMethod Path(field As %String) As %List
{
	If field = "specimenType" Return $ListBuild("specimen", "type")
	If field = "specimenUnit" Return $ListBuild("specimen", "unit")
	Return ""
}

/// The text the Order holds at the path of a condition field; "" when absent or not text
ClassMethod OrderValue(order, field As %String) As %String
{
	Set path = ..Path(field)
	If (path = "") || '$IsObject(order) Return ""
	Set node = order
	For i = 1 : 1 : $ListLength(path) {
		Set key = $List(path, i)
		If '$IsObject(node) || 'node.%IsA("%Library.DynamicObject") || (node.%GetTypeOf(key) = "unassigned") Return ""
		If i = $ListLength(path) Return $Select(node.%GetTypeOf(key) = "string": node.%Get(key), 1: "")
		Set node = node.%Get(key)
	}
	Return ""
}

/// Trimmed, upper-case value, or the canonical name the synonym list gives it:
/// {"specimenType": {"SERUM": ["SERUM", "SORO"]}} turns "soro" into "SERUM"
ClassMethod Canonical(field As %String, value As %String, synonyms) As %String
{
	Set normal = ..Normal(value)
	If '$IsObject(synonyms) || (synonyms.%GetTypeOf(field) '= "object") Return normal
	Set canonicals = synonyms.%Get(field).%GetIterator()
	While canonicals.%GetNext(.canonical, .variants) {
		If '$IsObject(variants) || 'variants.%IsA("%Library.DynamicArray") Continue
		Set each = variants.%GetIterator()
		While each.%GetNext(.index, .variant) {
			If ..Normal(variant) = normal Return ..Normal(canonical)
		}
	}
	Return normal
}

ClassMethod Normal(value) As %String [ Private ]
{
	If $IsObject(value) Return ""
	Return $ZConvert($ZStrip(value, "<>W"), "U")
}

/// True when every condition matches the Order. No conditions (or none declared) always match.
ClassMethod Matches(conditions, order, synonyms) As %Boolean
{
	If '$IsObject(conditions) Return 1
	Set each = conditions.%GetIterator()
	While each.%GetNext(.field, .expected) {
		If (..Path(field) = "") || (conditions.%GetTypeOf(field) '= "string") Return 0
		Set actual = ..OrderValue(order, field)
		If actual = "" Return 0
		If ..Canonical(field, actual, synonyms) '= ..Canonical(field, expected, synonyms) Return 0
	}
	Return 1
}

/// How many conditions a Mapping declares
ClassMethod Count(conditions) As %Integer
{
	If '$IsObject(conditions) Return 0
	Set n = 0, each = conditions.%GetIterator()
	While each.%GetNext(.field, .value) {
		Set n = n + 1
	}
	Return n
}

/// True when the code is among the Order's exam codes (trim, case-insensitive)
ClassMethod HasSourceCode(order, code As %String) As %Boolean
{
	Set wanted = ..Normal(code)
	If (wanted = "") || '$IsObject(order) || (order.%GetTypeOf("exams") '= "array") Return 0
	Set each = order.exams.%GetIterator()
	While each.%GetNext(.index, .exam) {
		If $IsObject(exam) && exam.%IsA("%Library.DynamicObject") && (exam.%GetTypeOf("code") = "string") && (..Normal(exam.code) = wanted) Return 1
	}
	Return 0
}

}
