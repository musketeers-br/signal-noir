Class SignalNoir.Core.MappingEffect Extends %RegisteredObject
{

/// The Order an approved Mapping sends (features 004 and 008): a copy of the snapshot whose exams
/// with the Mapping's source code (trimmed, case insensitive) carry its target code. Everything
/// else is sent as received. Pure; the snapshot is not changed. The Validator already checked
/// that the Mapping applies; an Order with no exam of the source code is refused, never guessed.
ClassMethod Payload(snapshot As %DynamicObject, mapping As %DynamicObject) As SignalNoir.Core.Result
{
	If '$IsObject(snapshot) || '$IsObject(mapping) Return ##class(SignalNoir.Core.Result).Error("", "mapping unavailable: no Order or no Mapping")
	If (mapping.%Get("sourceCode") = "") || (mapping.%Get("targetCode") = "") Return ##class(SignalNoir.Core.Result).Error("", "mapping unavailable: " _ mapping.%Get("mappingId") _ " has no source or target code")
	Set out = {}.%FromJSON(snapshot.%ToJSON()), replaced = 0
	If out.%GetTypeOf("exams") = "array" {
		For i = 0 : 1 : out.exams.%Size() - 1 {
			Set exam = out.exams.%Get(i)
			If '$IsObject(exam) || (exam.%GetTypeOf("code") '= "string") Continue
			If ..Normal(exam.code) '= ..Normal(mapping.sourceCode) Continue
			Set exam.code = mapping.targetCode, replaced = replaced + 1
		}
	}
	If 'replaced Return ##class(SignalNoir.Core.Result).Error("", "mapping unavailable: the Order has no exam " _ mapping.sourceCode)
	Return ##class(SignalNoir.Core.Result).OkObj(out)
}

ClassMethod Normal(value As %String) As %String [ Private ]
{
	Return $ZConvert($ZStrip(value, "<>W"), "U")
}

}
