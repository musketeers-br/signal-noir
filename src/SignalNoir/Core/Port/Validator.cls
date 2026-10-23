Class SignalNoir.Core.Port.Validator Extends %RegisteredObject [ Abstract ]
{

/// Deterministic and origin-blind (seam contract)

Method Validate(proposal As SignalNoir.Core.Dto.Proposal) As SignalNoir.Core.Dto.ValidatorVerdict
{
	Set v = ##class(SignalNoir.Core.Dto.ValidatorVerdict).%New()
	Set v.verdict = "invalid"
	Set v.reason = "Abstract port method - override in adapter or fake"
	Set v.failedPreconditions = $ListBuild()
	Return v
}

}
