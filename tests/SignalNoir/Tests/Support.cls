Class SignalNoir.Tests.Support Extends %RegisteredObject
{

/// 003 test helpers: synthetic Origin Orders, Exceptions and walks through
/// the transition table. Test-only (not a TestCase).
ClassMethod Uid(tag As %String) As %String
{
	Return tag _ "-" _ $JOB _ "-" _ $Increment(^SignalNoir.TestSeq)
}

ClassMethod Snapshot(orderId As %String) As %DynamicObject
{
	Set o = ##class(SignalNoir.Tests.Core.TestOrderShape).ValidOrder()
	Set o.orderId = orderId
	Set o.patient.patientId = "P-" _ orderId
	Return o
}

ClassMethod Order(orderId As %String, transactionId As %String = "", runId As %String = "") As SignalNoir.Core.Dto.Order
{
	Set order = ##class(SignalNoir.Core.Dto.Order).%New()
	Set order.orderId = orderId
	Set order.snapshot = ..Snapshot(orderId)
	Set order.transactionId = $Select(transactionId = "": "tx-" _ orderId, 1: transactionId)
	Set order.runId = runId
	Set order.synthetic = 1
	If runId '= "" Do ..EnsureRun(runId)
	Return order
}

/// Feature 010: a Case keeps a run id only if the run exists and is running, so a
/// test that gives an Order a run id registers a running run for it (idempotent).
ClassMethod EnsureRun(runId As %String, mode As %String = "rules")
{
	If ##class(SignalNoir.Application.Model.BenchmarkRunRecord).%ExistsId(runId) Quit
	Set run = ##class(SignalNoir.Application.Model.BenchmarkRunRecord).%New()
	Set run.runId = runId, run.mode = mode, run.purpose = "benchmark", run.status = "running"
	$$$ThrowOnError(run.%Save())
}

ClassMethod Exception(kind As %String = "timeout", httpStatus As %String = "") As SignalNoir.Core.Dto.CaseException
{
	Set ex = ##class(SignalNoir.Core.Dto.CaseException).%New()
	Set ex.kind = kind
	Set ex.httpStatus = httpStatus
	If httpStatus '= "" Set ex.body = {"error": "validation", "detail": "unknown exam code"}
	Set ex.observedAt = ##class(SignalNoir.Application.SystemClock).%New().NowUtc()
	Set ex.attemptId = "att-1"
	Return ex
}

/// Accepts an Order and records its first Exception: returns the caseId (Open).
/// examCode, when given, is the one exam the Order holds (a Case a Mapping can be applied to).
ClassMethod OpenCase(svc As SignalNoir.Application.CaseService, orderId As %String, runId As %String = "", examCode As %String = "") As %String
{
	Set order = ..Order(orderId, , runId)
	If examCode '= "" Set order.snapshot.exams = [{"code": (examCode)}]
	Set a = svc.AcceptOrder(order)
	If 'a.ok Return ""
	Set r = svc.RecordException(orderId, ..Exception())
	Return $Select(r.ok: r.ref, 1: "")
}

ClassMethod Ev(reason As %String = "") As SignalNoir.Core.Dto.TimelineEvent
{
	Set event = ##class(SignalNoir.Core.Dto.TimelineEvent).%New()
	Set event.type = "StateChanged"
	Set event.payload = {"reason": (reason)}
	Return event
}

/// Walks a Case from Open to the target state through allowed transitions.
/// Returns "" on success or the code that stopped it.
ClassMethod DriveTo(svc As SignalNoir.Application.CaseService, caseId As %String, target As %String) As %String
{
	Set paths("Open") = ""
	Set paths("Investigating") = "Investigating:system"
	Set paths("DecisionProposed") = paths("Investigating") _ ",DecisionProposed:agent"
	Set paths("PendingApproval") = paths("DecisionProposed") _ ",PendingApproval:system"
	Set paths("Approved") = paths("PendingApproval") _ ",Approved:operator:ana"
	Set paths("Rejected") = paths("PendingApproval") _ ",Rejected:operator:ana"
	Set paths("Executing") = paths("Approved") _ ",Executing:system"
	Set paths("Held") = paths("Approved") _ ",Held:system"
	Set paths("Resolved") = paths("Executing") _ ",Resolved:system"
	Set paths("ReviewRequired") = "ReviewRequired:system"
	Set paths("Cancelled") = paths("ReviewRequired") _ ",Cancelled:operator:ana"
	Set path = $Get(paths(target), "?")
	If path = "?" Return "NO_PATH"
	For i = 1 : 1 : $Length(path, ",") {
		Set step = $Piece(path, ",", i)
		If step = "" Continue
		Set to = $Piece(step, ":", 1)
		Set actor = $Piece(step, ":", 2, 3)
		Set g = svc.GetCase(caseId)
		If 'g.ok Return g.code
		; a Case waits for approval on a Proposal; Approved and Rejected need a decision (007)
		If (to = "PendingApproval") && (g.obj.currentProposalId = "") Do ..FixtureProposal(caseId)
		If (to = "Approved") || (to = "Rejected") {
			Set t = ..Decide(svc, caseId, $Select(to = "Approved": "approved", 1: "denied"), $Piece(actor, ":", 2), "test walk")
		} Else {
			Set t = svc.Transition(caseId, g.obj.caseVersion, to, actor, ..Ev("test walk"))
		}
		If 't.ok Return t.code _ " at " _ to _ ": " _ t.message
	}
	Return ""
}

/// 007: a current Proposal for a Case that reached DecisionProposed by a
/// raw transition (test fixture written on the records). Returns its id.
ClassMethod FixtureProposal(caseId As %String, action As %String = "RETRY", params As %DynamicObject = "") As %String
{
	Set rec = ##class(SignalNoir.Application.Model.CaseRecord).%OpenId(caseId)
	If rec.currentProposalId '= "" {
		Set old = ##class(SignalNoir.Application.Model.ProposalRecord).%OpenId(rec.currentProposalId)
		If $IsObject(old) Set old.current = 0  Do old.%Save()
	}
	Set pr = ##class(SignalNoir.Application.Model.ProposalRecord).%New()
	Set pr.proposalId = ##class(SignalNoir.Application.IdFactory).%New().New("prop_")
	Set pr.caseId = caseId, pr.author = "agent", pr.action = action, pr.paramsJson = $Select($IsObject(params): params.%ToJSON(), 1: "{}"), pr.current = 1
	Set pr.createdAt = ##class(SignalNoir.Application.SystemClock).%New().NowUtc()
	; a contract-complete Proposal: the dev database keeps it and the live check reads it
	Set pr.diagnosisJson = {"summary": "fixture", "claims": [], "hypotheses": []}.%ToJSON()
	Set pr.confidence = "LOW", pr.preconditionsJson = "[]", pr.metricsJson = {"toolCalls": 0}.%ToJSON()
	Set pr.versionsJson = {"policy": "fixture", "mapping": "fixture", "prompt": null, "model": null, "provider": null}.%ToJSON()
	Do pr.%Save()
	Set rec.currentProposalId = pr.proposalId
	Do rec.%Save()
	Return pr.proposalId
}

/// One "State:actor" step of a test walk: a raw transition, or the decision
/// for Approved/Rejected (with a fixture Proposal when the Case has none)
ClassMethod Step(svc As SignalNoir.Application.CaseService, caseId As %String, step As %String) As SignalNoir.Core.Result
{
	Set to = $Piece(step, ":", 1), actor = $Piece(step, ":", 2, 3)
	Set g = svc.GetCase(caseId).obj
	If (to = "PendingApproval") && (g.currentProposalId = "") Do ..FixtureProposal(caseId)
	If (to = "Approved") || (to = "Rejected") Return ..Decide(svc, caseId, $Select(to = "Approved": "approved", 1: "denied"), $Piece(actor, ":", 2), "test walk")
	Return svc.Transition(caseId, g.caseVersion, to, actor, ..Ev("test walk"))
}

/// 007: a Case in PendingApproval with a current Proposal
ClassMethod PendingCase(svc As SignalNoir.Application.CaseService, tag As %String) As %String
{
	Set caseId = ..OpenCase(svc, ..Uid(tag))
	Do ..DriveTo(svc, caseId, "PendingApproval")
	Return caseId
}

/// 007: the Operator's decision on the Case's current Proposal at its
/// current version
ClassMethod Decide(svc As SignalNoir.Application.CaseService, caseId As %String, decision As %String = "approved", operator As %String = "ana", reason As %String = "") As SignalNoir.Core.Result
{
	Set c = svc.GetCase(caseId).obj
	Set request = {"decision": (decision), "operator": (operator), "expectedCaseVersion": (c.caseVersion)}
	If reason '= "" Set request.reason = reason
	Return svc.DecideProposal(caseId, c.currentProposalId, request)
}

/// Outbox rows of a Case: count by "type:status"
ClassMethod Outbox(caseId As %String, ByRef rows) As %Integer
{
	Kill rows
	Set n = 0
	Set rs = ##class(%SQL.Statement).%ExecDirect(, "SELECT commandId, type, status, caseVersionAfter, payloadJson FROM SignalNoir_Application_Model.OutboxRecord WHERE caseId = ? ORDER BY createdAt, commandId", caseId)
	While rs.%Next() {
		Set n = n + 1
		Set rows(n) = $ListBuild(rs.%Get("commandId"), rs.%Get("type"), rs.%Get("status"), rs.%Get("caseVersionAfter"), rs.%Get("payloadJson"))
	}
	Return n
}

ClassMethod Count(sql As %String, arg As %String) As %Integer
{
	Set rs = ##class(%SQL.Statement).%ExecDirect(, sql, arg)
	If rs.%Next() Return +rs.%GetData(1)
	Return -1
}

/// JOB worker for the concurrency tests: waits on the barrier, then tries
/// one transition and records ok or the error code.
ClassMethod RaceTransition(key As %String, caseId As %String, version As %Integer, toState As %String)
{
	For i = 1 : 1 : 500 {
		Quit:$Get(^SignalNoir.TestBarrier(key))
		Hang 0.01
	}
	Set svc = ##class(SignalNoir.Application.CaseService).Default()
	Set r = svc.Transition(caseId, version, toState, "system", ..Ev("race"))
	Set ^SignalNoir.TestRace(key, $JOB) = $Select(r.ok: "ok", 1: r.code)
}

/// JOB worker: reports an Exception after the barrier
ClassMethod RaceException(key As %String, orderId As %String)
{
	For i = 1 : 1 : 500 {
		Quit:$Get(^SignalNoir.TestBarrier(key))
		Hang 0.01
	}
	Set svc = ##class(SignalNoir.Application.CaseService).Default()
	Set r = svc.RecordException(orderId, ..Exception())
	Set ^SignalNoir.TestRace(key, $JOB) = $Select(r.ok: r.ref, 1: "ERR:" _ r.code _ ":" _ r.message)
}

/// JOB worker: appends an Annotation inside an outer transaction and holds
/// the commit for a while (a late confirmation)
ClassMethod SlowAppend(key As %String, caseId As %String, holdSeconds As %Numeric)
{
	Set svc = ##class(SignalNoir.Application.CaseService).Default()
	TSTART
	Set event = ##class(SignalNoir.Core.Dto.TimelineEvent).%New()
	Set event.type = "Annotation"
	Set event.actor = "system"
	Set event.payload = {"note": "late"}
	Set r = svc.Append(caseId, event)
	Set ^SignalNoir.TestRace(key, "appended") = $Select(r.ok: r.obj.seq, 1: "ERR:" _ r.code)
	Hang holdSeconds
	TCOMMIT
	Set ^SignalNoir.TestRace(key, "committed") = 1
}

/// Waits until n results are recorded under key (max ~20s)
ClassMethod WaitResults(key As %String, n As %Integer) As %Integer
{
	For i = 1 : 1 : 2000 {
		Set count = 0
		Set j = ""
		For {
			Set j = $Order(^SignalNoir.TestRace(key, j))
			Quit:j=""
			Set count = count + 1
		}
		If count >= n Return count
		Hang 0.01
	}
	Return count
}

/// 006: a Case in Investigating with its pending Investigate request.
/// Returns the caseId; cmdId is set by reference. mode sets the Case's
/// proposer mode (test fixture written directly on the record).
ClassMethod InvestigatingCase(svc As SignalNoir.Application.CaseService, tag As %String, mode As %String = "rules", ByRef cmdId As %String, specimenType As %String = "") As %String
{
	Set orderId = ..Uid(tag)
	Set order = ..Order(orderId)
	Set order.snapshot.exams = [{"code": "GLIC-J"}]
	If specimenType '= "" Set order.snapshot.specimen.type = specimenType
	Do svc.AcceptOrder(order)
	Set caseId = svc.RecordException(orderId, ..Exception("http_error", 500)).ref
	Set rec = ##class(SignalNoir.Application.Model.CaseRecord).%OpenId(caseId)
	Set rec.proposerMode = mode
	Do rec.%Save()
	Kill rec
	Do svc.Transition(caseId, 1, "Investigating", "system", ..Ev("routed"))
	Set rs = ##class(%SQL.Statement).%ExecDirect(, "SELECT commandId FROM SignalNoir_Application_Model.OutboxRecord WHERE caseId = ? AND type = 'Investigate' AND status = 'pending'", caseId)
	Set cmdId = $Select(rs.%Next(): rs.%Get("commandId"), 1: "")
	Return caseId
}

/// Test fixture: the Evidence an investigation would have recorded for a Case (policies,
/// attempt history, partner health, Mapping catalog, in the shapes of
/// contracts/validation-input.md), written directly on the Case. A Case that reaches a
/// Validator verdict without an investigation needs it: the minimum-Evidence rule of 004.
ClassMethod SeedEvidence(caseId As %String)
{
	Set inputs = "SignalNoir.Tests.Core.Validator.Inputs"
	Set now = ##class(SignalNoir.Application.SystemClock).%New().NowUtc()
	For spec = "tool.policies:PoliciesResult", "tool.partner_failure_history:HistoryResult", "tool.partner_health:HealthResult", "tool.mapping_catalog:CatalogResult" {
		Set row = ##class(SignalNoir.Application.Model.EvidenceRecord).%New()
		Set row.evidenceId = "evid_seed_" _ $Increment(^SignalNoir.TestSeq)
		Set row.caseId = caseId
		Set row.source = $Piece(spec, ":", 1)
		Set row.kind = "fact"
		Set row.calledBy = "system"
		Set row.resultJson = $ClassMethod(inputs, $Piece(spec, ":", 2)).%ToJSON()
		Set row.observedAt = now
		$$$ThrowOnError(row.%Save())
	}
}

/// Writes a test script entry for a Case
ClassMethod Script(caseId As %String, key As %String, value As %String)
{
	Set ^SignalNoir.TestScript(caseId, key) = value
}

ClassMethod ClearScript(caseId As %String)
{
	Kill ^SignalNoir.TestScript(caseId)
}

/// Runs the Investigation of a request with scripted doubles
ClassMethod Investigate(cmdId As %String, proposerClass As %String = "SignalNoir.Tests.Fakes.ScriptedProposer", budgetMs As %Integer = 20000) As SignalNoir.Core.Result
{
	Set inv = ##class(SignalNoir.Application.InvestigationService).%New()
	Set inv.ProposerClass = proposerClass
	Set inv.SourceClass = "SignalNoir.Tests.Fakes.ScriptedSource"
	Set inv.BudgetMs = budgetMs
	Return inv.Run(cmdId)
}

/// A P5-like answer: REQUEST_REVIEW citing the Exception and the history
ClassMethod P5Answer() As %String
{
	Return "{""diagnosis"":{""summary"":""Partner rejects the exam code; no applicable mapping identified"",""claims"":[{""text"":""HTTP 500 body reports a validation error"",""evidenceIds"":[""@ev:system.exception""]},{""text"":""History shows the same rejection"",""evidenceIds"":[""@ev:tool.partner_failure_history""]}],""hypotheses"":[{""text"":""Partner outage"",""status"":""discarded"",""reason"":""health is UP"",""evidenceIds"":[""@ev:tool.partner_health""]},{""text"":""Business error on the exam code"",""status"":""chosen""}]},""action"":""REQUEST_REVIEW"",""params"":{""reason"":""business error""},""confidence"":""MEDIUM"",""preconditions"":[{""check"":""ORDER_ACTIVE_AT_ORIGIN"",""expected"":true}]}"
}

/// A P8b-like answer: the serum mapping chosen by specimen type
ClassMethod P8bAnswer() As %String
{
	Return "{""diagnosis"":{""summary"":""Two approved mappings for GLIC-J; the Order is serum"",""claims"":[{""text"":""map_glicj_soro applies to SERUM"",""evidenceIds"":[""@ev:tool.mapping_catalog""]},{""text"":""Partner rejected GLIC-J"",""evidenceIds"":[""@ev:system.exception""]}],""hypotheses"":[{""text"":""map_glicj_plasma"",""status"":""discarded"",""reason"":""specimen is serum""},{""text"":""map_glicj_soro"",""status"":""chosen""}]},""action"":""APPLY_APPROVED_MAPPING"",""params"":{""mappingId"":""map_glicj_soro"",""mappingVersion"":""2026.10.1""},""confidence"":""HIGH"",""preconditions"":[{""check"":""MAPPING_VERSION_UNCHANGED"",""expected"":""2026.10.1""}]}"
}

/// Timeline event types of a Case, in order, as "type;type;..."
ClassMethod Types(svc As SignalNoir.Application.CaseService, caseId As %String) As %String
{
	Set out = ""
	Set tl = svc.GetTimeline(caseId, 0, 500).list
	For i = 1 : 1 : tl.Count() Set out = out _ tl.GetAt(i).type _ ";"
	Return out
}


/// 008: a Case in Approved on a current fixture Proposal of this action
ClassMethod ApprovedCase(svc As SignalNoir.Application.CaseService, tag As %String, action As %String = "RETRY") As %String
{
	Set caseId = ..OpenCase(svc, ..Uid(tag))
	Do ..DriveTo(svc, caseId, "DecisionProposed")
	Do ..FixtureProposal(caseId, action)
	Set g = svc.GetCase(caseId).obj
	Do svc.Transition(caseId, g.caseVersion, "PendingApproval", "system", ..Ev("test walk"))
	Do ..Decide(svc, caseId, "approved", "ana")
	Return caseId
}

/// 008: a Case in Executing on a HOLD Proposal (no approval needed)
ClassMethod HoldCase(svc As SignalNoir.Application.CaseService, tag As %String) As %String
{
	Set caseId = ..OpenCase(svc, ..Uid(tag))
	Do ..DriveTo(svc, caseId, "DecisionProposed")
	Do ..FixtureProposal(caseId, "HOLD")
	Set g = svc.GetCase(caseId).obj
	Do svc.Transition(caseId, g.caseVersion, "Executing", "system", ..Ev("validator accepted; no approval required"))
	Return caseId
}

/// 008: an execution path over the given Partner (default policy)
ClassMethod Executor(partner As SignalNoir.Core.Port.PartnerClient, svc As SignalNoir.Application.CaseService = "") As SignalNoir.Application.ExecutionService
{
	Set ex = ##class(SignalNoir.Application.ExecutionService).%New()
	Set ex.Service = $Select($IsObject(svc): svc, 1: ##class(SignalNoir.Application.CaseService).Default())
	Set ex.Partner = partner
	Set ex.Policy = ##class(SignalNoir.Core.ExecutionPolicy).%New()
	Return ex
}

/// 008: the entry point running executions on this path (no proposer)
ClassMethod ExecBus(executor As SignalNoir.Application.ExecutionService) As SignalNoir.Application.CommandBus
{
	Set bus = ##class(SignalNoir.Application.CommandBus).Default()
	Set bus.Investigations = "none", bus.Executor = executor
	Return bus
}

/// 008: delivers the Case's latest pending request of a type through the bus
ClassMethod DeliverLast(bus As SignalNoir.Application.CommandBus, caseId As %String, type As %String = "Execute") As SignalNoir.Core.Result
{
	Return bus.Deliver(##class(SignalNoir.Tests.Application.TestCommandBus).Last(caseId, type))
}

/// 008: the Case's executions as stored
ClassMethod Executions(caseId As %String) As %DynamicArray
{
	Return ##class(SignalNoir.Application.CaseService).Default().ListExecutions(caseId)
}

}
