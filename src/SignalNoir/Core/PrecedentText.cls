Class SignalNoir.Core.PrecedentText Extends %RegisteredObject
{

/// The short description of a Case that is embedded as a precedent (feature
/// 015, research R4). Built only from allow-listed structured facts, in a
/// fixed order; a value that is not a code is dropped, so free text from an
/// Order, a partner, an Operator or the Agent can never reach a vector.
/// Fields, in order (facts key:label). The query form of an open Case omits
/// the outcome fields (the Case has none yet).
Parameter FIELDS = "partner:partner,examCodes:exam,exceptionKind:exception,httpStatus:http,responseClass:response,reviewReason:review,action:action,mappingId:mapping,executionOutcome:outcome,finalState:final,closeSeconds:close";

Parameter OUTCOMEFIELDS = "action,mappingId,executionOutcome,finalState,closeSeconds";

Parameter MAXLENGTH = 512;

Parameter CUTMARK = " [cut]";

/// Returns {"text", "dropped", "cut"}: text is "label=value" tokens joined by
/// spaces; dropped counts values refused by the code pattern
ClassMethod Build(facts As %DynamicObject, query As %Boolean = 0) As %DynamicObject
{
	Set text = "", dropped = 0
	Set fields = $ListFromString(..#FIELDS, ",")
	For i = 1 : 1 : $ListLength(fields) {
		Set key = $Piece($ListGet(fields, i), ":", 1), label = $Piece($ListGet(fields, i), ":", 2)
		If query && $ListFind($ListFromString(..#OUTCOMEFIELDS, ","), key) Continue
		If '$IsObject(facts) || 'facts.%IsDefined(key) Continue
		Set value = facts.%Get(key)
		If value = "" Continue
		If key = "examCodes" {
			Set codes = ..SortedCodes(value, .dropped)
			For j = 1 : 1 : $ListLength(codes) Set text = text _ $Select(text = "": "", 1: " ") _ label _ "=" _ $ListGet(codes, j)
			Continue
		}
		If key = "closeSeconds" Set value = ..CloseBucket(value)
		If '..IsCode(value) {
			Set dropped = dropped + 1
			Continue
		}
		Set text = text _ $Select(text = "": "", 1: " ") _ label _ "=" _ value
	}
	Set cut = 0
	If $Length(text) > ..#MAXLENGTH {
		Set text = $Extract(text, 1, ..#MAXLENGTH - $Length(..#CUTMARK)) _ ..#CUTMARK
		Set cut = 1
	}
	Return {"text": (text), "dropped": (dropped), "cut": (cut)}
}

/// A code: letters, digits and _ . : - only, 1 to 64 characters
ClassMethod IsCode(value As %String) As %Boolean
{
	If $IsObject(value) Return 0
	Return $Match(value, "[A-Za-z0-9_.:\-]{1,64}")
}

/// Time to close as a coarse bucket, so durations group Cases instead of
/// separating them
ClassMethod CloseBucket(seconds As %Integer) As %String
{
	Set seconds = +seconds
	If seconds < 300 Return "lt5m"
	If seconds < 3600 Return "lt1h"
	If seconds < 86400 Return "lt1d"
	Return "ge1d"
}

ClassMethod SortedCodes(value, ByRef dropped As %Integer) As %List [ Private ]
{
	Set out = ""
	If '$IsObject(value) {
		Set arr = []
		Do arr.%Push(value)
		Set value = arr
	}
	Set it = value.%GetIterator()
	While it.%GetNext(, .code) {
		If '..IsCode(code) {
			Set dropped = dropped + 1
			Continue
		}
		Set sorted(code) = ""
	}
	Set code = ""
	For {
		Set code = $Order(sorted(code))
		Quit:code=""
		Set out = out _ $ListBuild(code)
	}
	Return out
}

}
