Class SignalNoir.Core.Port.Proposer Extends %RegisteredObject [ Abstract ]
{

/// Propose(context) -> Result<ProposerAnswer> (seam v4, contract change 006).
/// Result.obj is the proposer's raw answer (data) in the contract Proposal
/// shape without ids; Core.ProposalShape converts it for every origin.
/// Result.details: provider, model, promptVersion, tokensIn, tokensOut,
/// estCostUsd when known. Failures are values: provider_unavailable,
/// invalid_response, refused, budget_exceeded.
Method Propose(context As SignalNoir.Core.Dto.InvestigationContext) As SignalNoir.Core.Result
{
	Return ##class(SignalNoir.Core.Result).Error("provider_unavailable", "Abstract port method - override in adapter or fake")
}

}
