Class SignalNoir.Core.DecisionShape Extends %RegisteredObject
{

/// Structural check of an Operator's decision on a Proposal (contract
/// ProposalDecisionRequest, spec 007 FR-001, FR-006). approved or denied,
/// the Operator's name, the version they saw, and a reason when denying;
/// nothing else. Pure. Returns the ordered reasons; empty means well formed.
ClassMethod Check(request) As %ListOfDataTypes
{
	Set r = ##class(%ListOfDataTypes).%New()
	If '$IsObject(request) || 'request.%IsA("%DynamicObject") {
		Do r.Insert("body:not_an_object")
		Return r
	}
	Set it = request.%GetIterator()
	While it.%GetNext(.key, .value) {
		If '$ListFind($ListBuild("decision", "operator", "expectedCaseVersion", "reason"), key) Do r.Insert("unknown_field:" _ key)
	}
	Set decision = request.%Get("decision")
	If (request.%GetTypeOf("decision") '= "string") || ((decision '= "approved") && (decision '= "denied")) Do r.Insert("decision:invalid")
	Set name = request.%Get("operator"), nameType = request.%GetTypeOf("operator")
	If (nameType = "unassigned") || (nameType = "null") || ((nameType = "string") && (##class(SignalNoir.Core.Canon).Trim(name) = "")) {
		Do r.Insert("operator:missing")
	} ElseIf (nameType '= "string") || (name [ ":") || ($Length(name) > 64) {
		Do r.Insert("operator:invalid")
	}
	If (request.%GetTypeOf("expectedCaseVersion") '= "number") || (request.expectedCaseVersion '? 1.N) Do r.Insert("expectedCaseVersion:invalid")
	Set reasonType = request.%GetTypeOf("reason")
	If (reasonType '= "unassigned") && (reasonType '= "null") && (reasonType '= "string") {
		Do r.Insert("reason:not_text")
	} ElseIf (decision = "denied") && (##class(SignalNoir.Core.Canon).Trim(request.%Get("reason")) = "") {
		Do r.Insert("reason:required_on_denial")
	}
	Return r
}

}
