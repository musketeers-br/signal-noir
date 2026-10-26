Class SignalNoir.Core.OperatorProposal Extends %RegisteredObject
{

/// The Proposal an Operator makes when resolving a review (spec 009 FR-008):
/// authored operator:<name>, the chosen catalog Action and its parameters,
/// a diagnosis that cites the Evidence the Dossier lists and, when the
/// Operator wrote a note, its operator.note Evidence (noteEvidenceId). Pure.
ClassMethod Build(action As %String, params As %DynamicObject, operatorName As %String, evidenceIds As %DynamicArray, note As %String = "", noteEvidenceId As %String = "") As SignalNoir.Core.Dto.Proposal
{
	Set p = ##class(SignalNoir.Core.Dto.Proposal).%New()
	Set p.origin = "operator:" _ operatorName
	Set cited = []
	If $IsObject(evidenceIds) {
		For i = 0 : 1 : evidenceIds.%Size() - 1 Do cited.%Push(evidenceIds.%Get(i))
	}
	If noteEvidenceId '= "" Do cited.%Push(noteEvidenceId)
	Set claims = []
	If cited.%Size() > 0 {
		Do claims.%Push({"text": ($Select(note '= "": "Operator decision: " _ note, 1: "Operator decision from the review dossier.")), "evidenceIds": (cited)})
	}
	Set p.diagnosis = {"summary": "Operator decision from the review dossier.", "claims": (claims), "hypotheses": [], "conflicts": []}
	Set p.action = action
	Set clean = {}
	If $IsObject(params) {
		Set it = params.%GetIterator()
		While it.%GetNext(.k, .v) {
			Do clean.%Set(k, v)
		}
	}
	Set p.params = clean
	Set p.scope = "single_case"
	; a human decision: the operator vouches for it
	Set p.confidence = "HIGH"
	Set pre = []
	If action = "APPLY_APPROVED_MAPPING" Do pre.%Push({"check": "MAPPING_VERSION_UNCHANGED", "expected": (clean.mappingVersion)})
	If ##class(SignalNoir.Core.ActionCatalog).ExternalEffect(action) Do pre.%Push({"check": "ORDER_ACTIVE_AT_ORIGIN", "expected": true})
	Set p.preconditions = pre
	Set p.versions = {"policy": "unloaded", "mapping": (##class(SignalNoir.Core.OperatorProposal).MappingVersion(clean)), "prompt": null, "model": null, "provider": null}
	Set p.metrics = {"toolCalls": 0}
	Return p
}

ClassMethod MappingVersion(params As %DynamicObject) As %String [ Private ]
{
	Set v = params.mappingVersion
	Return $Select(v = "": "unloaded", 1: v)
}

}
