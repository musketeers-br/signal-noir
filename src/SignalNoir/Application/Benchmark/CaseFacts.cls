Class SignalNoir.Application.Benchmark.CaseFacts Extends %RegisteredObject
{

/// The facts the evaluator is given about one item of a run (feature 010, contracts/scoring.md),
/// read from the persisted Case and nothing else. Read only: it opens records, never saves one.
/// Returns {replay, touchedByPerson, notDecidedReason, finalState, effect, proposals}, where
/// effect is {action, params} for what was sent (or null) and each proposal is
/// {action, params, verdict} in the order recorded.
ClassMethod For(item As SignalNoir.Application.Model.BenchmarkItemRecord) As %DynamicObject
{
	Set facts = {"proposals": []}
	Do facts.%Set("replay", 0, "boolean")
	Do facts.%Set("touchedByPerson", 0, "boolean")
	Do facts.%Set("notDecidedReason", item.notDecidedReason, $Select(item.notDecidedReason = "": "null", 1: "string"))
	Do facts.%Set("effect", "", "null")
	If item.caseId = "" {
		Set facts.finalState = "NoCase"
		Return facts
	}
	Set case = ##class(SignalNoir.Application.Model.CaseRecord).%OpenId(item.caseId)
	If '$IsObject(case) {
		Set facts.finalState = "NoCase"
		Return facts
	}
	Set facts.finalState = case.state
	Do facts.%Set("replay", case.replay, "boolean")
	Do facts.%Set("touchedByPerson", ..Touched(case.caseId), "boolean")
	Set rs = ##class(%SQL.Statement).%ExecDirect(, "SELECT proposalId, action, paramsJson, verdictJson FROM SignalNoir_Application_Model.ProposalRecord WHERE caseId = ? ORDER BY createdAt, proposalId", case.caseId)
	While rs.%Next() {
		Set params = $Select(rs.%Get("paramsJson") = "": {}, 1: {}.%FromJSON(rs.%Get("paramsJson")))
		Set verdict = $Select(rs.%Get("verdictJson") = "": "", 1: {}.%FromJSON(rs.%Get("verdictJson")).verdict)
		Do facts.proposals.%Push({"proposalId": (rs.%Get("proposalId")), "action": (rs.%Get("action")), "params": (params), "verdict": (verdict)})
	}
	If (facts.%GetTypeOf("notDecidedReason") = "null") && (case.state = "ReviewRequired") && (..DossierReason(case.caseId) = "provider_unavailable") {
		Set facts.notDecidedReason = "provider_unavailable"
	}
	Set effect = ..Effect(case)
	If $IsObject(effect) Set facts.effect = effect
	Return facts
}

/// What was sent to the Partner for this Case: the executed Proposal's Action and
/// parameters when it was executed (resolved, or failed after the send), or the HOLD when
/// the Case holds on a HOLD. An Action held by a failed Revalidation was not sent.
ClassMethod Effect(case As SignalNoir.Application.Model.CaseRecord) As %DynamicObject
{
	If (case.state = "Resolved") || (case.state = "ResolvedByPriorReceipt") || (case.state = "Failed") {
		Set rs = ##class(%SQL.Statement).%ExecDirect(, "SELECT TOP 1 proposalId FROM SignalNoir_Application_Model.ExecutionRecord WHERE caseId = ? ORDER BY authorizedAt DESC, executionId DESC", case.caseId)
		If 'rs.%Next() Return ""
		Return ..Sent(rs.%Get("proposalId"))
	}
	If case.state = "Held" {
		Set sent = ..Sent(case.currentProposalId)
		If $IsObject(sent) && (sent.action = "HOLD") Return sent
	}
	Return ""
}

ClassMethod Sent(proposalId As %String) As %DynamicObject
{
	Set p = $Select(proposalId = "": "", 1: ##class(SignalNoir.Application.Model.ProposalRecord).%OpenId(proposalId))
	If '$IsObject(p) Return ""
	Return {"action": (p.action), "params": ($Select(p.paramsJson = "": {}, 1: {}.%FromJSON(p.paramsJson)))}
}

/// True when an Operator (a person) acted on the Case; the system, the proposers, the
/// sweeper and the benchmark actor are not people
ClassMethod Touched(caseId As %String) As %Boolean
{
	Set rs = ##class(%SQL.Statement).%ExecDirect(, "SELECT COUNT(*) AS n FROM SignalNoir_Application_Model.CaseEventRecord WHERE caseId = ? AND actor LIKE 'operator:%'", caseId)
	Do rs.%Next()
	Return (rs.%Get("n") > 0)
}

/// The coded reason of the Case's latest Dossier (Core.DossierReason), or ""
ClassMethod DossierReason(caseId As %String) As %String
{
	Set rs = ##class(%SQL.Statement).%ExecDirect(, "SELECT TOP 1 reason FROM SignalNoir_Application_Model.DossierRecord WHERE caseId = ? ORDER BY createdAt DESC", caseId)
	Return $Select(rs.%Next(): rs.%Get("reason"), 1: "")
}

}
