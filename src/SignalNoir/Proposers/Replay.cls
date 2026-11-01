Class SignalNoir.Proposers.Replay Extends SignalNoir.Core.Port.Proposer
{

/// Returns an answer recorded earlier (Benchmark Replay, feature 010). A Replay is never a real
/// run (Constitution VIII); its Proposal is authored "replay". An answer is found by the reference
/// case of the Case being replayed (family/variant/repetition, through the BenchmarkRun item whose
/// scenario instance produced the Order) in the published reference result; a scenario instance has
/// a new Order id every time, so the Order id cannot be the key. The older recording by Order id
/// (006) is still honoured and wins. Evidence references in a recorded answer are written
/// "@ev:<source>" and resolved here to the Evidence of the Case being replayed.
Property Reference As %DynamicObject;

ClassMethod Record(orderId As %String, answerJson As %String) As %Status
{
	Set ^SignalNoir.Replay(orderId) = answerJson
	Return $$$OK
}

Method Propose(context As SignalNoir.Core.Dto.InvestigationContext) As SignalNoir.Core.Result
{
	; a recording by Order id (006) is played as it is; a reference-case recording (010) cites its
	; Evidence by source and gets the ids of the Case being replayed
	Set json = $Get(^SignalNoir.Replay(context.case.orderId))
	If json = "" {
		Set json = ..ByReferenceCase(context.case.orderId)
		If json '= "" Set json = ..Resolve(json, context.evidence)
	}
	If json = "" Return ##class(SignalNoir.Core.Result).Error("invalid_response", "no recorded answer for order " _ context.case.orderId)
	Set answer = ##class(SignalNoir.Core.ProposalShape).ParseText(json)
	If '$IsObject(answer) Return ##class(SignalNoir.Core.Result).Error("invalid_response", "recorded answer is not one JSON object")
	Set r = ##class(SignalNoir.Core.Result).OkObj(answer)
	Set r.details = {"provider": "replay", "model": "replay", "promptVersion": "replay"}
	Return r
}

/// The recorded answer (as JSON text) for the Order's reference case, or "": the exact repetition
/// if recorded, else the variant's first recording
Method ByReferenceCase(orderId As %String) As %String [ Private ]
{
	Set order = ##class(SignalNoir.Application.Model.OrderRecord).%OpenId(orderId)
	If '$IsObject(order) || (order.scenarioInstanceId = "") Return ""
	Set rs = ##class(%SQL.Statement).%ExecDirect(, "SELECT TOP 1 variant, repetition FROM SignalNoir_Application_Model.BenchmarkItemRecord WHERE scenarioInstanceId = ?", order.scenarioInstanceId)
	If 'rs.%Next() Return ""
	Set variant = rs.%Get("variant"), repetition = rs.%Get("repetition")
	Set record = $Select($IsObject(..Reference) && ..Reference.%IsDefined("cases"): ..Reference, 1: ##class(SignalNoir.Benchmark.Data.ReferenceResult).Load("Record"))
	If '$IsObject(record) || (record.%GetTypeOf("cases") '= "array") Return ""
	Set fallback = ""
	For i = 0 : 1 : record.cases.%Size() - 1 {
		Set c = record.cases.%Get(i)
		If (c.variant '= variant) || (c.%GetTypeOf("answer") '= "object") Continue
		If c.repetition = repetition Return c.answer.%ToJSON()
		If fallback = "" Set fallback = c.answer.%ToJSON()
	}
	Return fallback
}

/// "@ev:<source>" becomes the id of the Case's first Evidence from that source
ClassMethod Resolve(json As %String, evidence As %ListOfObjects) As %String
{
	For i = 1 : 1 : evidence.Count() {
		Set ev = evidence.GetAt(i)
		If '$Data(ids(ev.source)) Set ids(ev.source) = ev.evidenceId
	}
	Set source = ""
	For {
		Set source = $Order(ids(source))
		Quit:source=""
		Set json = $Replace(json, """@ev:" _ source _ """", """" _ ids(source) _ """")
	}
	Return json
}

}
