Class SignalNoir.Api.Dispatch Extends %CSP.REST
{

/// Product API dispatch for /signalnoir/api/v1 (AD-16). Read views of
/// feature 003: GET /cases (cursor, direction, filters), GET /cases/{caseId}
/// (CaseDetail) and GET /cases/{caseId}/timeline (TimelinePage). Errors use
/// the closed envelope { "error": { "code", "message", "details" } }.
XData UrlMap [ XMLNamespace = "http://www.intersystems.com/urlmap" ]
{
<Routes>
<Route Url="/health" Method="GET" Call="Health"/>
<Route Url="/cases" Method="GET" Call="ListCases"/>
<Route Url="/cases/:caseid" Method="GET" Call="GetCase"/>
<Route Url="/cases/:caseid/timeline" Method="GET" Call="GetTimeline"/>
<Route Url="/cases/:caseid/precedents" Method="GET" Call="GetPrecedents"/>
<Route Url="/cases/:caseid/resolution" Method="POST" Call="Resolve"/>
<Route Url="/cases/:caseid/proposals/:proposalid/decision" Method="POST" Call="Decide"/>
<Route Url="/reference/action-catalog" Method="GET" Call="ActionCatalog"/>
<Route Url="/reference/mappings" Method="GET" Call="Mappings"/>
</Routes>
}

ClassMethod Health() As %Status
{
	Set %response.ContentType = "application/json"
	Write ##class(SignalNoir.Api.Health).Payload().%ToJSON()
	Return $$$OK
}

ClassMethod ListCases() As %Status
{
	Set %response.ContentType = "application/json"
	Set filters = {}
	Set states = []
	Set i = ""
	For {
		Set i = $Order(%request.Data("state", i), 1, st)
		Quit:i=""
		Do states.%Push(st)
	}
	If states.%Size() > 0 Do filters.%Set("state", states)
	Set status = $Get(%request.Data("status", 1))
	If status '= "" Do filters.%Set("status", status)
	For name = "pendingApproval", "includeBenchmark" {
		Set raw = $Get(%request.Data(name, 1))
		If raw = "" Continue
		If (raw '= "true") && (raw '= "false") Return ..WriteError(##class(SignalNoir.Core.Result).Error("VALIDATION_FAILED", name _ " must be true or false"))
		Do filters.%Set(name, (raw = "true"), "boolean")
	}
	Set runId = $Get(%request.Data("runId", 1))
	If runId '= "" Do filters.%Set("runId", runId)
	Set limit = $Get(%request.Data("limit", 1), 50)
	Set svc = ##class(SignalNoir.Application.CaseService).Default()
	Set r = svc.ListCases($Get(%request.Data("cursor", 1)), $Get(%request.Data("direction", 1), "older"), limit, filters)
	If 'r.ok Return ..WriteError(r)
	Write ..ListPayload(r).%ToJSON()
	Return $$$OK
}

ClassMethod GetCase(caseid As %String) As %Status
{
	Set %response.ContentType = "application/json"
	Set r = ##class(SignalNoir.Application.CaseService).Default().GetCase(caseid)
	If 'r.ok Return ..WriteError(r)
	Write ..CasePayload(r.obj).%ToJSON()
	Return $$$OK
}

ClassMethod GetTimeline(caseid As %String) As %Status
{
	Set %response.ContentType = "application/json"
	Set r = ##class(SignalNoir.Application.CaseService).Default().GetTimeline(caseid, $Get(%request.Data("sinceSeq", 1), 0), $Get(%request.Data("limit", 1), 200))
	If 'r.ok Return ..WriteError(r)
	Write ..TimelinePayload(caseid, r).%ToJSON()
	Return $$$OK
}

/// GET /cases/{caseId}/precedents (feature 015, contract getCasePrecedents):
/// similar closed Cases, never Evidence. A search failure is a status in the
/// 200 body, so the console always opens the Case.
ClassMethod GetPrecedents(caseid As %String) As %Status
{
	Set %response.ContentType = "application/json"
	Set r = ##class(SignalNoir.Application.PrecedentService).Default().Search(caseid, $Get(%request.Data("k", 1)), "console")
	If 'r.ok Return ..WriteError(r)
	Write ..PrecedentsPayload(r).%ToJSON()
	Return $$$OK
}

/// The contract PrecedentSearch
ClassMethod PrecedentsPayload(r As SignalNoir.Core.Result) As %DynamicObject
{
	Set p = r.details
	Do p.%Set("recorded", ''p.recorded, "boolean")
	If 'p.%IsDefined("reason") || (p.reason = "") Do p.%Remove("reason")
	Return p
}

/// POST /cases/{caseId}/resolution (feature 009, contract resolveReview)
ClassMethod Resolve(caseid As %String) As %Status
{
	Set %response.ContentType = "application/json"
	Set body = ""
	Try {
		Set body = ##class(%DynamicAbstractObject).%FromJSON(%request.Content)
	}
	Catch {
		Set body = ""
	}
	Set svc = ##class(SignalNoir.Application.CaseService).Default()
	Set r = svc.ResolveReview(caseid, body)
	If 'r.ok {
		; a validator refusal is 422 with the verdict; a shape refusal is 400
		If (r.code = "VALIDATION_FAILED") && $IsObject(r.details) && $IsObject(r.details.verdict) {
			Set %response.Status = "422 Unprocessable Entity"
			Write ..ErrorPayload(r.code, r.message, r.details).%ToJSON()
			Return $$$OK
		}
		Return ..WriteError(r)
	}
	Set %response.Status = "201 Created"
	Write ..ResolutionPayload(svc, r.details).%ToJSON()
	Return $$$OK
}

/// POST /cases/{caseId}/proposals/{proposalId}/decision (feature 007,
/// contract decideProposal): 201 decision recorded, 200 replay. The request
/// the decision queued is delivered after the commit, in the background.
ClassMethod Decide(caseid As %String, proposalid As %String) As %Status
{
	Set %response.ContentType = "application/json"
	Set body = ""
	Try {
		Set body = ##class(%DynamicAbstractObject).%FromJSON(%request.Content)
	}
	Catch {
		Set body = ""
	}
	Set svc = ##class(SignalNoir.Application.CaseService).Default()
	Set r = svc.DecideProposal(caseid, proposalid, body)
	If 'r.ok Return ..WriteError(r)
	If r.details.commandId '= "" Job ##class(SignalNoir.Application.CommandBus).DeliverJob(r.details.commandId)
	Set %response.Status = ..DecisionStatus(r)
	Write ..DecisionPayload(svc, r.details).%ToJSON()
	Return $$$OK
}

ClassMethod DecisionStatus(r As SignalNoir.Core.Result) As %String
{
	Return $Select(r.details.replay: "200 OK", 1: "201 Created")
}

/// ProposalDecisionResult: approval, idempotentReplay, case (CommandAck)
ClassMethod DecisionPayload(svc As SignalNoir.Application.CaseService, d As %DynamicObject) As %DynamicObject
{
	Set payload = {"approval": (svc.ApprovalJson(d.approvalId))}
	Do payload.%Set("idempotentReplay", d.replay, "boolean")
	Set ack = {"caseId": (d.caseId), "state": (d.state), "caseVersion": (+d.caseVersion), "lastEventSeq": (+d.lastEventSeq), "serverTime": (d.serverTime)}
	Do ack.%Set("commandId", d.commandId, $Select(d.commandId = "": "null", 1: "string"))
	Do payload.%Set("case", ack)
	Return payload
}

/// ReviewResolutionResult: kind, proposal, approval, case (CommandAck)
ClassMethod ResolutionPayload(svc As SignalNoir.Application.CaseService, d As %DynamicObject) As %DynamicObject
{
	Set payload = {"kind": (d.kind)}
	If d.proposalId '= "" {
		Set p = ..ProposalPayload(svc.ProposalById(d.proposalId))
		Do p.%Set("validatorVerdict", svc.VerdictOf(d.proposalId))
		Do payload.%Set("proposal", p)
	} Else {
		Do payload.%Set("proposal", "", "null")
	}
	If d.approvalId '= "" {
		Do payload.%Set("approval", svc.ApprovalJson(d.approvalId))
	} Else {
		Do payload.%Set("approval", "", "null")
	}
	Set ack = {"caseId": (d.caseId), "state": (d.state), "caseVersion": (+d.caseVersion), "lastEventSeq": (+d.lastEventSeq), "serverTime": (d.serverTime)}
	Do ack.%Set("commandId", d.commandId, $Select(d.commandId = "": "null", 1: "string"))
	Do payload.%Set("case", ack)
	Return payload
}

/// GET /reference/action-catalog: the closed catalog compiled in the core
ClassMethod ActionCatalog() As %Status
{
	Set %response.ContentType = "application/json"
	Write {"items": (##class(SignalNoir.Core.ActionCatalog).Entries()), "serverTime": (..ServerTime())}.%ToJSON()
	Return $$$OK
}

/// GET /reference/mappings: approved mappings are reference data of feature
/// 004; until it is integrated none is loaded, and the list says so
ClassMethod Mappings() As %Status
{
	Set %response.ContentType = "application/json"
	Write {"mappingVersion": "unloaded", "items": [], "serverTime": (..ServerTime())}.%ToJSON()
	Return $$$OK
}

/// CaseListPage: items, nextCursor, headCursor and serverTime.
ClassMethod ListPayload(r As SignalNoir.Core.Result) As %DynamicObject
{
	Set items = []
	If $IsObject(r.list) {
		For i = 1 : 1 : r.list.Count() {
			Do items.%Push(..SummaryPayload(r.list.GetAt(i)))
		}
	}
	Set payload = {"items": (items)}
	Set next = "", head = ""
	If $IsObject(r.details) {
		Set next = r.details.nextCursor
		Set head = r.details.headCursor
	}
	Do payload.%Set("nextCursor", next, $Select(next = "": "null", 1: "string"))
	Do payload.%Set("headCursor", head)
	Do payload.%Set("serverTime", ..ServerTime())
	Return payload
}

/// CaseDetail: the CaseHeader, the Order view, the Exceptions and the layers
/// later features fill (empty or null until then).
ClassMethod CasePayload(dto As SignalNoir.Core.Dto.Case) As %DynamicObject
{
	Set payload = ..HeaderPayload(dto.caseId, dto.orderId, dto.partnerId, dto.state, dto.synthetic, dto.replay, dto.createdAt, dto.lastEventAt, dto.caseVersion, dto.lastEventSeq, dto.proposerMode, dto.runId)
	Do payload.%Set("updatedAt", dto.updatedAt)
	If $IsObject(dto.order) Do payload.%Set("order", ..OrderPayload(dto.order))
	Do payload.%Set("visualTraceUrl", "", "null")
	Set exceptions = []
	For i = 1 : 1 : dto.exceptions.Count() {
		Do exceptions.%Push(..ExceptionPayload(dto.exceptions.GetAt(i)))
	}
	Do payload.%Set("exceptions", exceptions)
	Set evidence = []
	For i = 1 : 1 : dto.evidence.Count() {
		Do evidence.%Push(..EvidencePayload(dto.evidence.GetAt(i)))
	}
	Do payload.%Set("evidence", evidence)
	Set proposals = []
	Set diagnosis = ""
	For i = 1 : 1 : dto.proposals.Count() {
		Set pr = dto.proposals.GetAt(i)
		Do proposals.%Push(..ProposalPayload(pr))
		If pr.proposalId = dto.currentProposalId Set diagnosis = pr.diagnosis
	}
	If $IsObject(diagnosis) {
		Do payload.%Set("diagnosis", diagnosis)
	} Else {
		Do payload.%Set("diagnosis", "", "null")
	}
	Do payload.%Set("currentProposalId", dto.currentProposalId, $Select(dto.currentProposalId = "": "null", 1: "string"))
	Do payload.%Set("proposals", proposals)
	Do payload.%Set("approvals", $Select($IsObject(dto.approvals): dto.approvals, 1: []))
	Do payload.%Set("denialCount", +dto.denialCount)
	Do payload.%Set("executions", $Select($IsObject(dto.executions): dto.executions, 1: []))
	If $IsObject(dto.receipt) && (dto.receipt.%Size() > 0) {
		Do payload.%Set("receipt", dto.receipt)
	} Else {
		Do payload.%Set("receipt", "", "null")
	}
	; an unset %DynamicObject property reads as {}: only a recorded Dossier counts
	If $IsObject(dto.dossier) && (dto.dossier.%Size() > 0) && ##class(SignalNoir.Api.Dispatch).ShowsDossier(dto) {
		Do payload.%Set("dossier", dto.dossier)
	} Else {
		Do payload.%Set("dossier", "", "null")
	}
	Do payload.%Set("metrics", $Select($IsObject(dto.metrics): dto.metrics, 1: {}))
	If dto.reviewReason '= "" Do payload.%Set("reviewReason", dto.reviewReason)
	If dto.previousCaseId '= "" Do payload.%Set("previousCaseId", dto.previousCaseId)
	Return payload
}

/// CaseSummary (list item)
ClassMethod SummaryPayload(dto As SignalNoir.Core.Dto.CaseSummary) As %DynamicObject
{
	Set payload = ..HeaderPayload(dto.caseId, dto.orderId, dto.partnerId, dto.state, dto.synthetic, dto.replay, dto.createdAt, dto.lastEventAt, dto.caseVersion, dto.lastEventSeq, dto.proposerMode, dto.runId)
	Do payload.%Set("pendingApproval", (dto.state = "PendingApproval"), "boolean")
	Do payload.%Set("approvalDeadline", "", "null")
	If dto.currentProposalId '= "" {
		Do payload.%Set("currentProposal", {"proposalId": (dto.currentProposalId), "action": (dto.currentAction), "confidence": (dto.currentConfidence)})
	} Else {
		Do payload.%Set("currentProposal", "", "null")
	}
	Do payload.%Set("exceptionCount", +dto.exceptionCount)
	If dto.lastExceptionSummary '= "" Do payload.%Set("lastExceptionSummary", dto.lastExceptionSummary)
	Do payload.%Set("executionOutcome", dto.executionOutcome, $Select(dto.executionOutcome = "": "null", 1: "string"))
	Return payload
}

/// TimelinePage: CaseVersioning + caseId, state, events, hasMore, nextSinceSeq
ClassMethod TimelinePayload(caseId As %String, r As SignalNoir.Core.Result) As %DynamicObject
{
	Set events = []
	For i = 1 : 1 : r.list.Count() {
		Set ev = r.list.GetAt(i)
		Set item = {"seq": (+ev.seq), "at": (ev.at), "type": (ev.type), "actor": (ev.actor)}
		Do item.%Set("refId", ev.refId, $Select(ev.refId = "": "null", 1: "string"))
		Do item.%Set("payload", $Select($IsObject(ev.payload): ev.payload, 1: {}))
		Do events.%Push(item)
	}
	Set payload = {"caseId": (caseId), "state": (r.details.state), "events": (events)}
	Do payload.%Set("hasMore", r.details.hasMore, "boolean")
	Do payload.%Set("nextSinceSeq", +r.details.nextSinceSeq)
	Do payload.%Set("caseVersion", +r.details.caseVersion)
	Do payload.%Set("lastEventSeq", +r.details.lastEventSeq)
	Do payload.%Set("serverTime", ..ServerTime())
	Return payload
}

ClassMethod HeaderPayload(caseId, orderId, partnerId, state, synthetic, replay, createdAt, lastEventAt, caseVersion, lastEventSeq, proposerMode, runId) As %DynamicObject [ Private ]
{
	Set payload = {"caseId": (caseId), "orderId": (orderId), "partnerId": (partnerId), "state": (state)}
	Set labels = {}
	Do labels.%Set("synthetic", ''synthetic, "boolean")
	Do labels.%Set("replay", ''replay, "boolean")
	Do payload.%Set("labels", labels)
	If proposerMode '= "" Do payload.%Set("proposerMode", proposerMode)
	If runId = "" {
		Do payload.%Set("benchmark", "", "null")
	} Else {
		Do payload.%Set("benchmark", {"runId": (runId), "mode": ($Select(proposerMode = "": "agent", 1: proposerMode))})
	}
	Do payload.%Set("createdAt", createdAt)
	Do payload.%Set("lastEventAt", lastEventAt)
	Do payload.%Set("caseVersion", +caseVersion)
	Do payload.%Set("lastEventSeq", +lastEventSeq)
	Do payload.%Set("serverTime", ..ServerTime())
	Return payload
}

/// OrderView: correlation ids, the immutable snapshot and the key parts
ClassMethod OrderPayload(order As SignalNoir.Core.Dto.Order) As %DynamicObject [ Private ]
{
	Set ids = []
	For i = 1 : 1 : order.transactionIds.Count() {
		Do ids.%Push(order.transactionIds.GetAt(i))
	}
	Set payload = {"orderId": (order.orderId), "correlationId": (order.correlationId), "transactionIds": (ids)}
	Do payload.%Set("snapshot", $Select($IsObject(order.snapshot): order.snapshot, 1: {}))
	Do payload.%Set("equivalenceKey", ##class(SignalNoir.Core.Canon).Parts(order.equivalenceKey))
	Do payload.%Set("transformed", "", "null")
	Return payload
}

/// Evidence (contract Evidence): the raw result by value
ClassMethod EvidencePayload(ev As SignalNoir.Core.Dto.Evidence) As %DynamicObject [ Private ]
{
	Set payload = {"evidenceId": (ev.evidenceId), "source": (ev.source)}
	If ##class(SignalNoir.Core.Vocab).IsActor(ev.calledBy) Do payload.%Set("calledBy", ev.calledBy)
	Do payload.%Set("params", $Select($IsObject(ev.params): ev.params, 1: {}))
	If $IsObject(ev.result) {
		Do payload.%Set("result", ev.result)
	} Else {
		Do payload.%Set("result", "", "null")
	}
	Do payload.%Set("observedAt", ev.observedAt)
	If ev.durationMs '= "" Do payload.%Set("durationMs", +ev.durationMs)
	Do payload.%Set("suspicious", ''ev.suspicious, "boolean")
	Set excerpts = []
	For i = 1 : 1 : ev.suspiciousExcerpts.Count() Do excerpts.%Push(ev.suspiciousExcerpts.GetAt(i))
	If excerpts.%Size() > 0 Do payload.%Set("suspiciousExcerpts", excerpts)
	Do payload.%Set("obsoletedBy", ev.obsoletedBy, $Select(ev.obsoletedBy = "": "null", 1: "string"))
	Return payload
}

/// Proposal (contract Proposal)
ClassMethod ProposalPayload(p As SignalNoir.Core.Dto.Proposal) As %DynamicObject
{
	Set payload = {"proposalId": (p.proposalId), "author": (p.origin), "createdAt": (p.createdAt)}
	Do payload.%Set("current", ''p.current, "boolean")
	Do payload.%Set("supersededBy", p.supersededBy, $Select(p.supersededBy = "": "null", 1: "string"))
	Do payload.%Set("diagnosis", $Select($IsObject(p.diagnosis): p.diagnosis, 1: {}))
	Do payload.%Set("action", p.action)
	Do payload.%Set("params", $Select($IsObject(p.params): p.params, 1: {}))
	Do payload.%Set("scope", p.scope)
	Do payload.%Set("confidence", p.confidence)
	Do payload.%Set("preconditions", $Select($IsObject(p.preconditions): p.preconditions, 1: []))
	Do payload.%Set("versions", $Select($IsObject(p.versions): p.versions, 1: {}))
	Do payload.%Set("metrics", $Select($IsObject(p.metrics): p.metrics, 1: {}))
	; an unset %DynamicObject property reads as {}: only a real candidate counts
	If $IsObject(p.priorReceiptCandidate) && (p.priorReceiptCandidate.%Size() > 0) {
		Do payload.%Set("priorReceiptCandidate", p.priorReceiptCandidate)
	} Else {
		Do payload.%Set("priorReceiptCandidate", "", "null")
	}
	Do payload.%Set("validatorVerdict", "", "null")
	Return payload
}

ClassMethod ExceptionPayload(ex As SignalNoir.Core.Dto.CaseException) As %DynamicObject [ Private ]
{
	Set payload = {"exceptionId": (ex.exceptionId), "kind": (ex.kind)}
	Do payload.%Set("httpStatus", ex.httpStatus, $Select(ex.httpStatus = "": "null", 1: "number"))
	If $IsObject(ex.body) {
		Do payload.%Set("body", ex.body)
	} ElseIf ex.bodyText '= "" {
		Do payload.%Set("body", ex.bodyText)
	} Else {
		Do payload.%Set("body", "", "null")
	}
	If ex.responseClass '= "" Do payload.%Set("responseClass", ex.responseClass)
	Do payload.%Set("observedAt", ex.observedAt)
	Do payload.%Set("attemptId", ex.attemptId, $Select(ex.attemptId = "": "null", 1: "string"))
	Do payload.%Set("duringExecution", ''ex.duringExecution, "boolean")
	Return payload
}

/// The Dossier is part of the detail in review and once the Case is closed
/// after one (the console keeps it at the bottom, collapsed)
ClassMethod ShowsDossier(dto As SignalNoir.Core.Dto.Case) As %Boolean
{
	If dto.state = "ReviewRequired" Return 1
	Return ##class(SignalNoir.Core.Vocab).IsTerminal(dto.state)
}

/// HTTP status of a closed error code (contract responses)
ClassMethod HttpStatus(code As %String) As %String
{
	If code = "VALIDATION_FAILED" Return "400 Bad Request"
	If code = "NOT_FOUND" Return "404 Not Found"
	If code = "INVALID_ACTOR" Return "403 Forbidden"
	If (code = "STALE_VERSION") || (code = "INVALID_TRANSITION") Return "409 Conflict"
	Return "500 Internal Server Error"
}

ClassMethod WriteError(r As SignalNoir.Core.Result) As %Status [ Private ]
{
	Set %response.Status = ..HttpStatus(r.code)
	Set code = r.code
	; an internal failure is not a contract code: report it without inventing one
	If code = "" Set code = "VALIDATION_FAILED"
	Write ..ErrorPayload(code, r.message, r.details).%ToJSON()
	Return $$$OK
}

/// The closed error envelope.
ClassMethod ErrorPayload(code As %String, message As %String, details As %DynamicObject = "") As %DynamicObject
{
	If '$IsObject(details) Set details = {}
	Return {"error": {"code": (code), "message": (message), "details": (details)}}
}

ClassMethod ServerTime() As %String [ Private ]
{
	Return ##class(SignalNoir.Application.SystemClock).%New().NowUtc()
}

}
