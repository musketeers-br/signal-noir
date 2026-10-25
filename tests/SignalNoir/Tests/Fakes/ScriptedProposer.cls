Class SignalNoir.Tests.Fakes.ScriptedProposer Extends SignalNoir.Core.Port.Proposer
{

/// Test-only proposer driven by ^SignalNoir.TestScript(caseId, key):
/// "tools" (comma list called through the gateway first), "sleep" (seconds),
/// "fail" (failure code:message), "answer" (JSON; the token "@ev:<source>"
/// in an evidenceIds array is replaced by the id of that source's Evidence).
Method Propose(context As SignalNoir.Core.Dto.InvestigationContext) As SignalNoir.Core.Result
{
	Set caseId = context.case.caseId
	Set ^SignalNoir.TestScript(caseId, "proposed") = $Get(^SignalNoir.TestScript(caseId, "proposed")) + 1
	Set tools = $Get(^SignalNoir.TestScript(caseId, "tools"))
	For i = 1 : 1 : $Length(tools, ",") {
		Set tool = $Piece(tools, ",", i)
		If tool = "" Continue
		Set r = context.tools.Invoke(tool, {})
		Set ^SignalNoir.TestScript(caseId, "toolResult", i) = $Select(r.ok: "ok:" _ r.obj.evidenceId, 1: r.code)
		If 'r.ok && (r.code = "budget_exceeded") Return r
		If r.ok Do context.evidence.Insert(r.obj)
	}
	Set sleep = $Get(^SignalNoir.TestScript(caseId, "sleep"))
	If sleep Hang sleep
	Set fail = $Get(^SignalNoir.TestScript(caseId, "fail"))
	If fail '= "" Return ##class(SignalNoir.Core.Result).Error($Piece(fail, ":", 1), $Piece(fail, ":", 2, *))
	Set json = $Get(^SignalNoir.TestScript(caseId, "answer"))
	For i = 1 : 1 : context.evidence.Count() {
		Set ev = context.evidence.GetAt(i)
		Set json = $Replace(json, """@ev:" _ ev.source _ """", """" _ ev.evidenceId _ """")
	}
	Set answer = ##class(SignalNoir.Core.ProposalShape).ParseText(json)
	If '$IsObject(answer) Return ##class(SignalNoir.Core.Result).Error("invalid_response", "scripted answer is not JSON")
	Set r = ##class(SignalNoir.Core.Result).OkObj(answer)
	Set r.details = {"provider": "scripted", "model": "scripted-1", "promptVersion": "script-v1", "tokensIn": 120, "tokensOut": 80, "estCostUsd": 0.0004}
	Return r
}

}
