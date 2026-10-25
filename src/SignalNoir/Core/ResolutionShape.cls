Class SignalNoir.Core.ResolutionShape Extends %RegisteredObject
{

/// Structural check of an operator resolution (contract ReviewResolutionRequest,
/// spec 009 FR-006, FR-012). A catalog Action with only its allowed
/// parameters, or a cancellation with a reason; nothing else. Pure.
/// Returns the ordered reasons; empty means well formed.
ClassMethod Check(request) As %ListOfDataTypes
{
	Set r = ##class(%ListOfDataTypes).%New()
	If '$IsObject(request) || 'request.%IsA("%DynamicObject") {
		Do r.Insert("body:not_an_object")
		Return r
	}
	Set kind = request.%Get("kind")
	If (kind '= "action") && (kind '= "cancel") {
		Do r.Insert("kind:invalid")
		Return r
	}
	Set allowed = $Select(kind = "action": $ListBuild("kind", "operator", "expectedCaseVersion", "action", "params", "note"), 1: $ListBuild("kind", "operator", "expectedCaseVersion", "reason"))
	Set it = request.%GetIterator()
	While it.%GetNext(.key, .value) {
		If '$ListFind(allowed, key) Do r.Insert("unknown_field:" _ key)
	}
	Set name = request.%Get("operator")
	If $IsObject(name) || (##class(SignalNoir.Core.Canon).Trim(name) = "") {
		Do r.Insert("operator:missing")
	} ElseIf (name [ ":") || ($Length(name) > 64) {
		Do r.Insert("operator:invalid")
	}
	If (request.%GetTypeOf("expectedCaseVersion") '= "number") || (request.expectedCaseVersion '? 1.N) Do r.Insert("expectedCaseVersion:invalid")
	If kind = "cancel" {
		Set reason = request.%Get("reason")
		If $IsObject(reason) || (##class(SignalNoir.Core.Canon).Trim(reason) = "") Do r.Insert("reason:missing")
		Return r
	}
	Set action = request.%Get("action")
	If $IsObject(action) || '##class(SignalNoir.Core.Vocab).IsAction(action) {
		Do r.Insert("action:not_in_catalog")
		Return r
	}
	If action = "REQUEST_REVIEW" Do r.Insert("action:already_in_review")
	Set params = request.%Get("params")
	If params = "" Set params = {}
	If '$IsObject(params) || 'params.%IsA("%DynamicObject") {
		Do r.Insert("params:not_an_object")
		Return r
	}
	Set names = ##class(SignalNoir.Core.ActionCatalog).AllowedParams(action)
	Set it = params.%GetIterator()
	While it.%GetNext(.key, .value) {
		If '$ListFind(names, key) {
			Do r.Insert("params." _ key _ ":not_allowed")
		} ElseIf $IsObject(value) {
			Do r.Insert("params." _ key _ ":not_text")
		}
	}
	Set note = request.%Get("note")
	If $IsObject(note) Do r.Insert("note:not_text")
	Return r
}

}
