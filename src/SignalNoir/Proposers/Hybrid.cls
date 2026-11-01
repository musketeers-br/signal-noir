Class SignalNoir.Proposers.Hybrid Extends SignalNoir.Core.Port.Proposer
{

/// The hybrid proposer (feature 016): the Decisions API answers first, with
/// a quarter of the budget (at most 10 s); a decisive typed answer is the
/// Proposal. Any other outcome (uncertain, refused, invalid, unavailable)
/// hands the same context to the AI Hub Agent, which decides on the
/// Evidence alone. details.author names the proposer that produced the
/// answer; details.cascade records the route for the Timeline.
Property First As SignalNoir.Core.Port.Proposer;

Property Fallback As SignalNoir.Core.Port.Proposer;

/// Upper bound of the Decisions share of the budget
Parameter FIRSTMAXMS = 10000;

Method %OnNew() As %Status
{
	Set ..First = ##class(SignalNoir.Proposers.Decisions).%New()
	Set ..Fallback = ##class(SignalNoir.Proposers.Agent).%New()
	Return $$$OK
}

Method Propose(context As SignalNoir.Core.Dto.InvestigationContext) As SignalNoir.Core.Result
{
	Set budget = context.budgetMs
	Set context.budgetMs = $Select(+budget > 0: ..FirstShare(budget), 1: ..#FIRSTMAXMS)
	Set first = ..First.Propose(context)
	Set context.budgetMs = budget
	Set cascade = {"kind": "proposer_cascade", "decisions": ($Select(first.ok: "decisive", 1: first.code)), "reason": ($Select(first.ok: "", 1: first.message))}
	If $IsObject(first.details) {
		If first.details.choice '= "" Do cascade.%Set("choice", first.details.choice)
		If first.details.probability '= "" Do cascade.%Set("probability", +first.details.probability)
		If first.details.tokensIn '= "" Do cascade.%Set("decisionsTokensIn", +first.details.tokensIn)
	}
	If first.ok {
		Do cascade.%Set("decidedBy", "decisions")
		Return ..Tag(first, "decisions", cascade)
	}
	Set second = ..Fallback.Propose(context)
	Do cascade.%Set("decidedBy", $Select(second.ok: "agent", 1: "none"))
	If 'second.ok Do cascade.%Set("agent", second.code)
	Return ..Tag(second, $Select(second.ok: "agent", 1: ""), cascade)
}

/// The Decisions share: a quarter of the budget, at most FIRSTMAXMS
ClassMethod FirstShare(budgetMs As %Integer) As %Integer
{
	Set share = budgetMs \ 4
	Return $Select(share > ..#FIRSTMAXMS: ..#FIRSTMAXMS, 1: share)
}

ClassMethod Tag(r As SignalNoir.Core.Result, author As %String, cascade As %DynamicObject) As SignalNoir.Core.Result [ Private ]
{
	If '$IsObject(r.details) Set r.details = {}
	If author '= "" Do r.details.%Set("author", author)
	Do r.details.%Set("cascade", cascade)
	Return r
}

}
