Class SignalNoir.Core.Port.Proposer Extends %RegisteredObject [ Abstract ]
{

/// Propose(case) -> Result<Proposal>. A provider-unavailable proposer returns
/// a result value (code provider_unavailable) instead of raising; that value
/// is what drives ReviewRequired.

Method Propose(case As SignalNoir.Core.Dto.Case) As SignalNoir.Core.Result
{
	Return ##class(SignalNoir.Core.Result).Error("provider_unavailable", "Abstract port method - override in adapter or fake")
}

}
