Class SignalNoir.Tests.Fakes.FakeValidator Extends SignalNoir.Core.Port.Validator
{

/// Configurable verdict (seam contract). Usable with no live provider.
Property Verdict As %String;

Property Reason As %String;

Property FailedPreconditions As %List;

Method %OnNew() As %Status
{
	Set ..Verdict = "valid"
	Set ..Reason = ""
	Set ..FailedPreconditions = $ListBuild()
	Return $$$OK
}

Method Validate(proposal As SignalNoir.Core.Dto.Proposal) As SignalNoir.Core.Dto.ValidatorVerdict
{
	Set v = ##class(SignalNoir.Core.Dto.ValidatorVerdict).%New()
	Set v.verdict = ..Verdict
	Set v.reason = ..Reason
	Set v.failedPreconditions = ..FailedPreconditions
	Return v
}

}
