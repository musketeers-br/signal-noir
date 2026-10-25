Class SignalNoir.Proposers.Replay Extends SignalNoir.Core.Port.Proposer
{

/// Returns an answer recorded earlier for the same Order (Benchmark Replay,
/// feature 010). A Replay is never a real run (Constitution VIII); its
/// Proposal is authored "replay".
ClassMethod Record(orderId As %String, answerJson As %String) As %Status
{
	Set ^SignalNoir.Replay(orderId) = answerJson
	Return $$$OK
}

Method Propose(context As SignalNoir.Core.Dto.InvestigationContext) As SignalNoir.Core.Result
{
	Set json = $Get(^SignalNoir.Replay(context.case.orderId))
	If json = "" Return ##class(SignalNoir.Core.Result).Error("invalid_response", "no recorded answer for order " _ context.case.orderId)
	Set answer = ##class(SignalNoir.Core.ProposalShape).ParseText(json)
	If '$IsObject(answer) Return ##class(SignalNoir.Core.Result).Error("invalid_response", "recorded answer is not one JSON object")
	Set r = ##class(SignalNoir.Core.Result).OkObj(answer)
	Set r.details = {"provider": "replay", "model": "replay", "promptVersion": "replay"}
	Return r
}

}
