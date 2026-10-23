Class SignalNoir.Core.Validator Extends SignalNoir.Core.Port.Validator
{

/// Deterministic, origin-blind, minimal rule set (Constitution III).
/// Declares the five preconditions but evaluates only what this slice needs:
/// closed-action membership and the mapping-parameter rule of the frozen
/// contract (APPLY_APPROVED_MAPPING requires mappingId and mappingVersion).

ClassMethod Preconditions() As %ListOfDataTypes
{
	Return ##class(SignalNoir.Core.Vocab).Preconditions()
}

Method Validate(proposal As SignalNoir.Core.Dto.Proposal) As SignalNoir.Core.Dto.ValidatorVerdict
{
	Set verdict = ##class(SignalNoir.Core.Dto.ValidatorVerdict).%New()
	Set failed = ""
	Set reason = ""
	If '$IsObject(proposal) {
		Set verdict.verdict = "invalid"
		Set verdict.reason = "proposal is required"
		Set verdict.failedPreconditions = $ListBuild()
		Return verdict
	}
	Set action = proposal.action
	If '##class(SignalNoir.Core.Vocab).IsAction(action) {
		Set verdict.verdict = "invalid"
		Set verdict.reason = "unknown action: " _ action
		Set verdict.failedPreconditions = $ListBuild()
		Return verdict
	}
	If action = "APPLY_APPROVED_MAPPING" {
		Set mappingId = ""
		Set mappingVersion = ""
		If $IsObject(proposal.params) {
			Set mappingId = proposal.params.mappingId
			Set mappingVersion = proposal.params.mappingVersion
		}
		If (mappingId = "") || (mappingVersion = "") {
			Set failed = "MAPPING_VERSION_UNCHANGED"
			Set reason = "APPLY_APPROVED_MAPPING requires mappingId and mappingVersion"
		}
	}
	Set verdict.verdict = $Select(failed = "" : "valid", 1 : "invalid")
	Set verdict.reason = reason
	Set verdict.failedPreconditions = $ListBuild(failed)
	Return verdict
}

}
