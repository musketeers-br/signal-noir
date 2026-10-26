Class SignalNoir.Tests.Fakes.FakeProposer Extends SignalNoir.Core.Port.Proposer
{

/// Configurable answer or provider-unavailable result (seam v4).
/// Usable with no live provider.
Property Available As %Boolean;

/// The raw answer to return (contract Proposal shape without ids)
Property Answer As %DynamicObject;

Property ProviderName As %String;

Method %OnNew() As %Status
{
	Set ..Available = 0
	Set ..ProviderName = "fake-provider"
	Return $$$OK
}

Method Propose(context As SignalNoir.Core.Dto.InvestigationContext) As SignalNoir.Core.Result
{
	If '..Available {
		Return ##class(SignalNoir.Core.Result).Error("provider_unavailable", "AI provider is not available")
	}
	If '$IsObject(..Answer) {
		Return ##class(SignalNoir.Core.Result).Error("invalid_response", "no answer configured")
	}
	Set r = ##class(SignalNoir.Core.Result).OkObj(..Answer)
	Set r.details = {"provider": (..ProviderName), "model": "fake-model"}
	Return r
}

}
