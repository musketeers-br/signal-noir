Class SignalNoir.Core.Validator Extends SignalNoir.Core.Port.Validator
{

/// Deterministic, origin-blind, minimal rule set (Constitution III).
/// Seam v2 shape; the rules are still the slice-1 set (closed-action membership and the
/// mapping-parameter rule of the frozen contract) until 004 T017 brings the pipeline.
ClassMethod Preconditions() As %ListOfDataTypes
{
	Return ##class(SignalNoir.Core.Vocab).Preconditions()
}

Method Validate(input As SignalNoir.Core.Dto.ValidationInput) As SignalNoir.Core.Dto.ValidatorVerdict
{
	Set verdict = ##class(SignalNoir.Core.Dto.ValidatorVerdict).%New()
	Set proposal = $Select($IsObject(input): input.proposal, 1: "")
	If $IsObject(input) {
		Set verdict.at = input.now
		If $IsObject(input.reference) Set verdict.versions = {"policy": (input.reference.policyVersion), "mapping": (input.reference.mappingVersion)}
	}
	Set action = $Select($IsObject(proposal): proposal.action, 1: "")
	Set verdict.requiresApproval = ##class(SignalNoir.Core.ActionCatalog).RequiresApproval(action)
	If '##class(SignalNoir.Core.Vocab).IsAction(action) {
		Set verdict.verdict = "blocked"
		Do verdict.reasons.Insert("ACTION_NOT_IN_CATALOG")
		Return verdict
	}
	Do verdict.reasons.Insert("ACTION_IN_CATALOG")
	If action = "APPLY_APPROVED_MAPPING" {
		Set mappingId = "", mappingVersion = ""
		If $IsObject(proposal.params) {
			Set mappingId = proposal.params.mappingId
			Set mappingVersion = proposal.params.mappingVersion
		}
		If (mappingId = "") || (mappingVersion = "") {
			Set verdict.verdict = "blocked"
			Do verdict.reasons.Clear()
			Do verdict.reasons.Insert("PARAMS_INVALID")
			Return verdict
		}
	}
	Do verdict.reasons.Insert("PARAMS_VALID")
	Set verdict.verdict = "accepted"
	Return verdict
}

}
