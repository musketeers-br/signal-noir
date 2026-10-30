Class SignalNoir.Core.Dto.PreconditionResult Extends %RegisteredObject
{

/// One precondition checked again before an Execution (Revalidate, 004). The contract leaves
/// expected and observed untyped, so they are kept as JSON literals and a boolean stays a
/// boolean: true, "2026.10.1", null.
Property check As %String(MAXLEN = 64);

Property expectedLiteral As %String(MAXLEN = 4000) [ InitialExpression = "null" ];

Property observedLiteral As %String(MAXLEN = 4000) [ InitialExpression = "null" ];

Property passed As %Boolean;

Property evidenceId As %String(MAXLEN = 128);

ClassMethod FromJson(json As %DynamicObject) As SignalNoir.Core.Dto.PreconditionResult
{
	If '$IsObject(json) || 'json.%IsA("%Library.DynamicObject") Return ""
	Set r = ..%New()
	Set r.check = json.%Get("check"), r.passed = +json.%Get("passed"), r.evidenceId = json.%Get("evidenceId")
	Set r.expectedLiteral = ..Literal(json, "expected"), r.observedLiteral = ..Literal(json, "observed")
	Return r
}

Method ToJson() As %DynamicObject
{
	Set o = {}
	Set o.check = ..check
	Do ..Put(o, "expected", ..expectedLiteral), ..Put(o, "observed", ..observedLiteral)
	Do o.%Set("passed", ..passed, "boolean")
	If ..evidenceId = "" {
		Do o.%Set("evidenceId", "", "null")
	} Else {
		Set o.evidenceId = ..evidenceId
	}
	Return o
}

/// The JSON text of one member, null when absent
ClassMethod Literal(json As %DynamicObject, key As %String) As %String [ Private ]
{
	Set type = json.%GetTypeOf(key)
	If (type = "unassigned") || (type = "null") Return "null"
	Set wrapper = {}
	Do wrapper.%Set("v", json.%Get(key), type)
	Return $Extract(wrapper.%ToJSON(), 6, *-1)
}

ClassMethod Put(o As %DynamicObject, key As %String, literal As %String) [ Private ]
{
	Set wrapper = {}.%FromJSON("{""v"":" _ literal _ "}")
	Do o.%Set(key, wrapper.%Get("v"), wrapper.%GetTypeOf("v"))
}

}
