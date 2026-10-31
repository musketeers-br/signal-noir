Class SignalNoir.Proposers.Decisions Extends SignalNoir.Core.Port.Proposer
{

/// The Decisions proposer (feature 013): asks the OpenAI Decisions API for
/// typed answers over the pre-collected Evidence (one choice over the
/// catalog, one predicate per Evidence item) and converts them in the core.
/// It only proposes: the answer goes through ProposalShape and the single
/// Validator like every other origin. Not through AI Hub: build 154 has no
/// decisions route (research R0); the runtime is a direct HTTP client.
Parameter PROVIDER = "openai-decisions";

Property Runtime As SignalNoir.Core.Port.DecisionsRuntime;

/// The last request body, kept for tests and the Timeline (never the key)
Property LastRequest As %DynamicObject;

Method %OnNew() As %Status
{
	Set ..Runtime = ##class(SignalNoir.Proposers.DecisionsHttp).%New()
	Return $$$OK
}

Method Propose(context As SignalNoir.Core.Dto.InvestigationContext) As SignalNoir.Core.Result
{
	Set evidence = [], refs = []
	Set catalog = ""
	For i = 1 : 1 : context.evidence.Count() {
		Set ev = context.evidence.GetAt(i)
		Do evidence.%Push({"evidenceId": (ev.evidenceId), "source": (ev.source), "kind": (ev.kind), "suspicious": (+ev.suspicious), "result": (ev.result)})
		Do refs.%Push({"evidenceId": (ev.evidenceId), "source": (ev.source)})
		If (ev.source = "tool.mapping_catalog") && (ev.kind = "fact") && $IsObject(ev.result) && ev.result.%IsA("%DynamicObject") Set catalog = ev.result
	}
	Set snapshot = $Select($IsObject(context.order) && $IsObject(context.order.snapshot): context.order.snapshot, 1: "")
	Set candidates = ##class(SignalNoir.Core.MappingMatch).Candidates(snapshot, $Select($IsObject(catalog): catalog.items, 1: ""))
	Set caseInfo = {"caseId": (context.case.caseId), "orderId": (context.case.orderId), "partnerId": (context.case.partnerId)}
	Set body = ##class(SignalNoir.Core.DecisionQuestions).Build(caseInfo, snapshot, evidence, candidates)
	Set ..LastRequest = body
	; never past the Investigation's budget
	Set timeout = $Select(+context.budgetMs > 0: (context.budgetMs \ 1000) + 1, 1: 20)
	Set call = ..Runtime.Decide(body, timeout)
	Set details = {"provider": (..#PROVIDER), "promptVersion": (##class(SignalNoir.Core.DecisionQuestions).#VERSION)}
	If 'call.ok {
		Set call.details = details
		Return call
	}
	Set response = call.details.answer
	Do details.%Set("model", $Select($IsObject(response) && (response.model '= ""): response.model, 1: call.details.model))
	Do ..Usage(response, details)
	Set converted = ##class(SignalNoir.Core.DecisionAnswer).Convert(response, refs, candidates)
	If 'converted.ok {
		Set converted.details = details
		Return converted
	}
	Set r = ##class(SignalNoir.Core.Result).OkObj(converted.obj)
	Do details.%Set("choice", converted.details.choice)
	Do details.%Set("probability", converted.details.probability)
	Do details.%Set("decisionConfidence", converted.details.confidence)
	Set r.details = details
	Return r
}

/// Token usage (FR-010): input tokens include cached ones; output tokens
/// are not charged
ClassMethod Usage(response As %DynamicObject, details As %DynamicObject) [ Private ]
{
	If '$IsObject(response) || '$IsObject(response.usage) Quit
	Set usage = response.usage
	If usage.%Get("input_tokens") '= "" Do details.%Set("tokensIn", +usage.%Get("input_tokens"))
	If usage.%Get("output_tokens") '= "" Do details.%Set("tokensOut", +usage.%Get("output_tokens"))
	Set more = usage.%Get("input_tokens_details")
	If $IsObject(more) && (more.%Get("cached_tokens") '= "") Do details.%Set("tokensCached", +more.%Get("cached_tokens"))
}

}
