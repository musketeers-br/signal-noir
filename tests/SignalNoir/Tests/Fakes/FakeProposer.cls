Class SignalNoir.Tests.Fakes.FakeProposer Extends SignalNoir.Core.Port.Proposer
{

/// Configurable proposal or provider-unavailable result (seam contract).
/// Usable with no live provider.

Property Available As %Boolean;

Property Proposal As SignalNoir.Core.Dto.Proposal;

Property ProviderName As %String;

Method %OnNew() As %Status
{
	Set ..Available = 0
	Set ..ProviderName = "fake-provider"
	Return $$$OK
}

Method Propose(case As SignalNoir.Core.Dto.Case) As SignalNoir.Core.Result
{
	If '..Available {
		Return ##class(SignalNoir.Core.Result).Error("provider_unavailable", "AI provider is not available")
	}
	If '$IsObject(..Proposal) {
		Return ##class(SignalNoir.Core.Result).Error("VALIDATION_FAILED", "no proposal configured")
	}
	Return ##class(SignalNoir.Core.Result).OkObj(..Proposal)
}

}
