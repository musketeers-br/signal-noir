Class SignalNoir.Core.Dto.Admission Extends %RegisteredObject
{

/// Answer of Validator.Admit(actor, run) (004): whether an actor may approve, and why not.
Property admissible As %Boolean;

/// human or automatic, when admissible
Property label As %String(MAXLEN = 16);

/// ACTOR_BENCHMARK_OUTSIDE_RUN or ACTOR_NOT_ALLOWED_TO_APPROVE, when not admissible
Property reason As %String(MAXLEN = 64);

ClassMethod FromJson(json As %DynamicObject) As SignalNoir.Core.Dto.Admission
{
	If '$IsObject(json) || 'json.%IsA("%Library.DynamicObject") Return ""
	Set a = ..%New()
	Set a.admissible = +json.%Get("admissible"), a.label = json.%Get("label"), a.reason = json.%Get("reason")
	Return a
}

Method ToJson() As %DynamicObject
{
	Set o = {}
	Do o.%Set("admissible", ..admissible, "boolean")
	If ..label '= "" Set o.label = ..label
	If ..reason '= "" Set o.reason = ..reason
	Return o
}

}
