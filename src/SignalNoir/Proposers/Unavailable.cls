Class SignalNoir.Proposers.Unavailable Extends SignalNoir.Core.Port.Proposer
{

/// Provider-unavailable Proposer stub: returns a result value meaning
/// "provider unavailable" instead of raising, and never calls a model.
/// That value is what drives the Case to ReviewRequired (FR-004, FR-016).

Method Propose(case As SignalNoir.Core.Dto.Case) As SignalNoir.Core.Result
{
	Return ##class(SignalNoir.Core.Result).Error("provider_unavailable", "AI provider is not configured")
}

}
