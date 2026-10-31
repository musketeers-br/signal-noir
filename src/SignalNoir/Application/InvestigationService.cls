Class SignalNoir.Application.InvestigationService Extends %RegisteredObject
{

/// Runs one Investigate request (feature 006). The coordinator (Run) claims
/// the request, collects the base Evidence package through the read-only
/// gateway, starts the proposer in a worker process (Work) and closes the
/// Investigation when the time budget passes. Completion and closure both
/// require the Investigation to be open under the Case lock, so a late
/// answer can never change a closed Investigation.
Property Service As SignalNoir.Application.CaseService;

/// Overrides for tests; empty means Proposers.Factory and Tools.Sources
Property ProposerClass As %String;

Property SourceClass As %String;

Property BudgetMs As %Integer [ InitialExpression = {##class(SignalNoir.Core.Budget).#MAXMILLIS} ];

Method %OnNew() As %Status
{
	Set ..Service = ##class(SignalNoir.Application.CaseService).Default()
	Return $$$OK
}

/// Runs the Investigation of one request. Result.ref = investigationId;
/// details.status = proposed, review, discarded.
Method Run(commandId As %String) As SignalNoir.Core.Result
{
	Set outbox = ##class(SignalNoir.Application.Model.OutboxRecord).%OpenId(commandId)
	If '$IsObject(outbox) Return ##class(SignalNoir.Core.Result).Error("NOT_FOUND", "investigation request not found: " _ commandId)
	Set caseRec = ##class(SignalNoir.Application.Model.CaseRecord).%OpenId(outbox.caseId)
	If '$IsObject(caseRec) Return ##class(SignalNoir.Core.Result).Error("NOT_FOUND", "case not found: " _ outbox.caseId)
	Set proposerClass = $Select(..ProposerClass '= "": ..ProposerClass, 1: ##class(SignalNoir.Proposers.Factory).ClassFor(caseRec.proposerMode))
	Set sourceClass = $Select(..SourceClass '= "": ..SourceClass, 1: "SignalNoir.Tools.Sources")
	Set started = ..Service.StartInvestigation(commandId, proposerClass, sourceClass, ..BudgetMs)
	If 'started.ok Return started
	If started.details.discarded {
		Set r = ##class(SignalNoir.Core.Result).OkRef("")
		Set r.details = {"status": "discarded", "reason": (started.details.reason)}
		Return r
	}
	Set investigationId = started.ref
	; base Evidence package, through the same gateway every proposer uses
	Set gateway = ..Gateway(investigationId, "system")
	Set base = ##class(SignalNoir.Core.ToolCatalog).BasePackage()
	For i = 1 : 1 : $ListLength(base) {
		Set call = gateway.Invoke($ListGet(base, i), {})
		If 'call.ok && ((call.code = "budget_exceeded") || (call.code = "closed")) Quit
	}
	If ..Status(investigationId) = "open" {
		Job ##class(SignalNoir.Application.InvestigationService).Work(investigationId)::5
		If '$Test Do ..Service.CloseInvestigation(investigationId, "proposer worker did not start")
	}
	; wait for the worker, never past the budget
	Set inv = ##class(SignalNoir.Application.Model.InvestigationRecord).%OpenId(investigationId)
	For {
		Do inv.%Reload()
		Quit:inv.status'="open"
		If (##class(SignalNoir.Application.CaseService).NowMs() - inv.startedMs) >= inv.budgetMs {
			Do ..Service.CloseInvestigation(investigationId, ##class(SignalNoir.Core.Budget).Reason("time"))
			Continue
		}
		Hang 0.05
	}
	Set r = ##class(SignalNoir.Core.Result).OkRef(investigationId)
	Set r.details = {"status": (inv.status), "reason": (inv.outcomeReason), "proposalId": (inv.proposalId)}
	Return r
}

/// Runs up to max pending Investigate requests (for the command entry point
/// of feature 007). Result.ref = number run.
Method RunPending(max As %Integer = 10) As SignalNoir.Core.Result
{
	Set n = 0
	Set rs = ##class(%SQL.Statement).%ExecDirect(, "SELECT TOP " _ (+max) _ " commandId FROM SignalNoir_Application_Model.OutboxRecord WHERE type = 'Investigate' AND status = 'pending' ORDER BY createdAt, commandId")
	While rs.%Next() {
		Do ..Run(rs.%Get("commandId"))
		Set n = n + 1
	}
	Return ##class(SignalNoir.Core.Result).OkRef(n)
}

/// Worker entry (separate process): rebuilds the proposer, runs it with the
/// Investigation context, converts the answer in the core and completes or
/// closes the Investigation. A closed Investigation discards the answer.
ClassMethod Work(investigationId As %String)
{
	Set svc = ##class(SignalNoir.Application.CaseService).Default()
	Set inv = ##class(SignalNoir.Application.Model.InvestigationRecord).%OpenId(investigationId)
	If '$IsObject(inv) Quit
	Set meta = {}
	Try {
		Set service = ..%New()
		Set service.Service = svc
		Set g = svc.GetCase(inv.caseId)
		Set context = ##class(SignalNoir.Core.Dto.InvestigationContext).%New()
		Set context.investigationId = investigationId
		Set context.case = g.obj
		Set context.order = g.obj.order
		For i = 1 : 1 : g.obj.evidence.Count() Do context.evidence.Insert(g.obj.evidence.GetAt(i))
		Set context.tools = service.Gateway(investigationId, inv.mode, inv.sourceClass)
		Set context.maxToolCalls = ##class(SignalNoir.Core.Budget).#MAXTOOLCALLS
		Set context.budgetMs = inv.budgetMs
		Set context.startedAt = inv.startedAt
		Set context.precedents = ..Precedents(inv.caseId)
		Set meta = ..Versions(svc, inv.caseId)
		Set proposer = $ClassMethod(inv.proposerClass, "%New")
		Set answer = proposer.Propose(context)
		If $IsObject(answer.details) {
			For key = "provider", "model", "promptVersion", "tokensIn", "tokensOut", "estCostUsd" {
				If answer.details.%Get(key) '= "" Do meta.%Set(key, answer.details.%Get(key))
			}
		}
		If 'answer.ok {
			Do ..CloseOrDiscard(svc, investigationId, ..FailureReason(answer), meta)
			Quit
		}
		Do inv.%Reload()
		Set ids = ##class(%ListOfDataTypes).%New()
		Set all = svc.ListEvidence(inv.caseId)
		For i = 1 : 1 : all.Count() Do ids.Insert(all.GetAt(i).evidenceId)
		Set versions = {"policy": (meta.policyVersion), "mapping": (meta.mappingVersion)}
		For key = "prompt:promptVersion", "model:model", "provider:provider" {
			Set v = meta.%Get($Piece(key, ":", 2))
			Do versions.%Set($Piece(key, ":", 1), v, $Select(v = "": "null", 1: "string"))
		}
		Set metrics = {"durationMs": (##class(SignalNoir.Application.CaseService).NowMs() - inv.startedMs), "toolCalls": (+inv.toolCalls)}
		For key = "tokensIn", "tokensOut", "estCostUsd" {
			If meta.%Get(key) '= "" Do metrics.%Set(key, +meta.%Get(key))
		}
		Set converted = ##class(SignalNoir.Core.ProposalShape).Convert(answer.obj, ids, inv.mode, versions, metrics)
		If 'converted.ok {
			Do ..CloseOrDiscard(svc, investigationId, "invalid proposer response", meta)
			Quit
		}
		Set done = svc.CompleteInvestigation(investigationId, converted.obj, meta)
		If 'done.ok && (done.code = "closed") Do svc.DiscardAnswer(investigationId, "late proposer answer discarded: " _ done.message)
	}
	Catch ex {
		Do ..CloseOrDiscard(svc, investigationId, "proposer failed: " _ ex.Name, meta)
	}
}

/// The optional precedents for the proposer (015 US6): "" unless
/// SN_PRECEDENTS_AGENT=1. Not a Tool call (the base package spends the
/// budget), never Evidence; the search leaves its own Timeline record.
/// Benchmark Cases are never precedents, so a run never sees its own Cases.
ClassMethod Precedents(caseId As %String, service As SignalNoir.Application.PrecedentService = "") As %DynamicArray
{
	If '$IsObject(service) {
		If '##class(SignalNoir.Application.PrecedentService).AgentEnabled() Return ""
		Set service = ##class(SignalNoir.Application.PrecedentService).Default()
	}
	Set r = service.Search(caseId, , "agent")
	If 'r.ok || (r.details.status '= "results") Return ""
	Return r.details.items
}

/// The gateway an Investigation's calls go through
Method Gateway(investigationId As %String, caller As %String, sourceClass As %String = "") As SignalNoir.Application.ToolGateway
{
	Set inv = ##class(SignalNoir.Application.Model.InvestigationRecord).%OpenId(investigationId)
	If sourceClass = "" Set sourceClass = inv.sourceClass
	Set gateway = ##class(SignalNoir.Application.ToolGateway).%New()
	Set gateway.Service = ..Service
	Set gateway.InvestigationId = investigationId
	Set gateway.Caller = caller
	Set gateway.Source = $ClassMethod(sourceClass, "%New")
	Set defaults = {"caseId": (inv.caseId)}
	Set caseRec = ##class(SignalNoir.Application.Model.CaseRecord).%OpenId(inv.caseId)
	Set orderRec = ##class(SignalNoir.Application.Model.OrderRecord).%OpenId(caseRec.orderId)
	Do defaults.%Set("orderId", caseRec.orderId)
	Do defaults.%Set("partnerId", caseRec.partnerId)
	If $IsObject(orderRec) {
		Do defaults.%Set("scenarioInstanceId", orderRec.scenarioInstanceId)
		Set snapshot = {}.%FromJSON(orderRec.snapshotJson)
		If $IsObject(snapshot.patient) Do defaults.%Set("patientId", snapshot.patient.patientId)
	}
	Set gateway.Defaults = defaults
	Return gateway
}

Method Status(investigationId As %String) As %String [ Private ]
{
	Set inv = ##class(SignalNoir.Application.Model.InvestigationRecord).%OpenId(investigationId)
	Do inv.%Reload()
	Return inv.status
}

/// Policy and mapping versions as reported by the reference-data Evidence
ClassMethod Versions(svc As SignalNoir.Application.CaseService, caseId As %String) As %DynamicObject [ Private ]
{
	Set meta = {"policyVersion": "unloaded", "mappingVersion": "unloaded"}
	Set all = svc.ListEvidence(caseId)
	For i = 1 : 1 : all.Count() {
		Set ev = all.GetAt(i)
		If (ev.kind '= "fact") || '$IsObject(ev.result) || 'ev.result.%IsA("%DynamicObject") Continue
		If (ev.source = "tool.policies") && (ev.result.policyVersion '= "") Do meta.%Set("policyVersion", ev.result.policyVersion)
		If (ev.source = "tool.policies") && (ev.result.policyVersion = "") && (ev.result.version '= "") Do meta.%Set("policyVersion", ev.result.version)
		If (ev.source = "tool.mapping_catalog") && (ev.result.mappingVersion '= "") Do meta.%Set("mappingVersion", ev.result.mappingVersion)
	}
	Return meta
}

/// The reason recorded on the Case for a proposer failure (006 FR-018)
ClassMethod FailureReason(r As SignalNoir.Core.Result) As %String
{
	If r.code = "provider_unavailable" Return "provider unavailable: " _ r.message
	If (r.code = "invalid_response") || (r.code = "refused") Return "invalid proposer response"
	If r.code = "budget_exceeded" Return r.message
	Return "proposer failed: " _ r.message
}

ClassMethod CloseOrDiscard(svc As SignalNoir.Application.CaseService, investigationId As %String, reason As %String, meta As %DynamicObject) [ Private ]
{
	Set closed = svc.CloseInvestigation(investigationId, reason, meta)
	If 'closed.ok && (closed.code = "closed") Do svc.DiscardAnswer(investigationId, "late proposer outcome discarded: " _ reason)
}

}
