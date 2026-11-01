Class SignalNoir.Application.ExecutionService Extends %RegisteredObject
{

/// The single execution path (AD-5, feature 008). Execute: observe the
/// Partner and the Origin, revalidate (policy port), authorize in one CAS,
/// look for a Receipt by Order, then send attempts with the effect key and
/// classify each answer (Core.ResponseClass). Reconcile: take the lease
/// over, query Receipts by key and by Order, settle or send again with the
/// same key. All I/O happens here, through the Partner port, outside any
/// transaction; every write is a CaseService command.
Property Service As SignalNoir.Application.CaseService;

Property Partner As SignalNoir.Core.Port.PartnerClient;

Property Policy As SignalNoir.Core.Port.ExecutionPolicy;

/// Lease owner of the writes this worker makes
Property Owner As %String [ InitialExpression = {"job:" _ $Job} ];

ClassMethod Default() As SignalNoir.Application.ExecutionService
{
	Set svc = ..%New()
	Set svc.Service = ##class(SignalNoir.Application.CaseService).Default()
	Set svc.Partner = ##class(SignalNoir.Interop.PartnerHttp).%New()
	Set policy = ##class(SignalNoir.Application.ReferenceExecutionPolicy).%New()
	Set policy.Lease = ##class(SignalNoir.Interop.Bootstrap).EnvSeconds("SN_AI_LEASE_SECONDS", ##class(SignalNoir.Interop.Bootstrap).#LEASESECONDS)
	Set svc.Policy = policy
	Return svc
}

/// Processes an Execute request. details.status as AuthorizeExecution, or
/// the final status of the send (resolved, reconciling, failed, ...).
Method Execute(commandId As %String) As SignalNoir.Core.Result
{
	Set outbox = ##class(SignalNoir.Application.Model.OutboxRecord).%OpenId(commandId)
	If '$IsObject(outbox) || (outbox.type '= "Execute") Return ##class(SignalNoir.Core.Result).Error("NOT_FOUND", "execute request not found: " _ commandId)
	Set rec = ##class(SignalNoir.Application.Model.CaseRecord).%OpenId(outbox.caseId)
	Do rec.%Reload()
	Set proposal = ..Service.ProposalById(rec.currentProposalId)
	If '$IsObject(proposal) Return ..Service.AuthorizeExecution(commandId, {})
	; HOLD has no effect on the Partner: nothing to observe (FR-022)
	If proposal.action = "HOLD" Return ..Service.AuthorizeExecution(commandId, {"owner": (..Owner)})
	Set orderRec = ##class(SignalNoir.Application.Model.OrderRecord).%OpenId(rec.orderId)
	Set snapshot = {}.%FromJSON(orderRec.snapshotJson)
	Set payload = ..Policy.EffectPayload(proposal.action, proposal.params, snapshot)
	Set health = ..Partner.Health(rec.partnerId, orderRec.scenarioInstanceId)
	Set origin = ..Partner.OriginStatus(rec.orderId)
	Set approval = ..Service.ApprovalJson(rec.currentApprovalId)
	Set input = {"now": (..Service.Clock.NowUtc()), "versions": ($Select($IsObject(proposal.versions): proposal.versions, 1: {})), "current": (..Policy.CurrentVersions())}
	Do input.%Set("health", $Select(health.ok: health.obj, 1: ""), $Select(health.ok: "", 1: "null"))
	Do input.%Set("origin", $Select(origin.ok: origin.obj, 1: ""), $Select(origin.ok: "", 1: "null"))
	Set input.approval = {"required": true, "status": ($Select($IsObject(approval): approval.status, 1: "missing")), "expiresAt": ($Select($IsObject(approval): approval.expiresAt, 1: ""))}
	Set input.payloadError = $Select(payload.ok: "", 1: payload.message)
	Set rv = ..Policy.Revalidate(input)
	Set plan = {"revalidation": (rv), "owner": (..Owner), "leaseSeconds": (..Policy.LeaseSeconds())}
	If payload.ok {
		Set plan.payload = payload.obj
		Set plan.idempotencyKey = ##class(SignalNoir.Core.EffectKey).Derive(rec.orderId, rec.partnerId, payload.obj)
		If proposal.action = "APPLY_APPROVED_MAPPING" Set plan.mappingRef = {"mappingId": (proposal.params.mappingId), "mappingVersion": (proposal.params.mappingVersion)}
	}
	Set auth = ..Service.AuthorizeExecution(commandId, plan)
	If 'auth.ok || (auth.details.status '= "authorized") Return auth
	Return ..Run(auth.details.executionId, auth.details.generation, 1)
}

/// Processes a Reconcile request (research R6)
Method Reconcile(commandId As %String) As SignalNoir.Core.Result
{
	Set take = ..Service.TakeOverExecution(commandId, ..Owner, ..Policy.LeaseSeconds())
	If 'take.ok || (take.details.status '= "taken") Return take
	Set executionId = take.details.executionId, gen = take.details.generation
	Set ex = ..Row(executionId)
	Set trigger = take.details.trigger
	; by key first: it names this exact effect
	Set q = ..Partner.SearchReceipts({"idempotencyKey": (ex.idempotencyKey)})
	If 'q.ok Return ..Service.RecordReconciliation(executionId, gen, {"trigger": (trigger), "queriedBy": "idempotencyKey", "found": false, "unreadable": true, "reason": (q.message)}, "reconciling")
	Set receipt = ..Match(q.obj, ex.orderId, ex.idempotencyKey)
	If $IsObject(receipt) Return ..Service.RecordReconciliation(executionId, gen, {"trigger": (trigger), "queriedBy": "idempotencyKey", "found": true, "receipt": (receipt)})
	Set r = ..Service.RecordReconciliation(executionId, gen, {"trigger": (trigger), "queriedBy": "idempotencyKey", "found": false})
	If 'r.ok || (r.details.status '= "recorded") Return r
	; then by Order: another key may already have delivered it (research R4)
	Set q = ..Partner.SearchReceipts({"orderId": (ex.orderId)})
	If 'q.ok Return ..Service.RecordReconciliation(executionId, gen, {"trigger": (trigger), "queriedBy": "orderId", "found": false, "unreadable": true, "reason": (q.message)}, "reconciling")
	Set receipt = ..Match(q.obj, ex.orderId, "")
	If $IsObject(receipt) Return ..Service.RecordReconciliation(executionId, gen, {"trigger": (trigger), "queriedBy": "orderId", "found": true, "receipt": (receipt)})
	Set attempts = {}.%FromJSON(ex.attemptsJson).%Size()
	Set then = $Select(attempts < ..Policy.MaxAttempts(): "resume", 1: "fail")
	Set r = ..Service.RecordReconciliation(executionId, gen, {"trigger": (trigger), "queriedBy": "orderId", "found": false}, then)
	If 'r.ok || (r.details.status '= "resumed") Return r
	; nothing found: the same key and payload may go again (the Partner deduplicates)
	Return ..Run(executionId, gen, 0)
}

/// The prior check (when asked) and the attempt loop of an authorized execution
Method Run(executionId As %String, generation As %Integer, priorCheck As %Boolean) As SignalNoir.Core.Result
{
	Set ex = ..Row(executionId)
	If priorCheck {
		Set q = ..Partner.SearchReceipts({"orderId": (ex.orderId)})
		If 'q.ok Return ..Service.RecordReconciliation(executionId, generation, {"trigger": "prior_check", "queriedBy": "orderId", "found": false, "unreadable": true, "reason": (q.message)}, "reconciling")
		Set receipt = ..Match(q.obj, ex.orderId, "")
		Set r = ..Service.RecordReconciliation(executionId, generation, {"trigger": "prior_check", "queriedBy": "orderId", "found": ($IsObject(receipt)), "receipt": (receipt)})
		If 'r.ok || (r.details.status '= "recorded") Return r
	}
	Set payload = {}.%FromJSON(ex.payloadJson)
	Set mappingRef = $Select(ex.mappingRefJson '= "": {}.%FromJSON(ex.mappingRefJson), 1: "")
	For {
		Set s = ..Service.StartAttempt(executionId, generation, ..Owner, ..Policy.LeaseSeconds())
		If 's.ok Return s
		If s.details.status = "discarded" Return s
		Set request = {"idempotencyKey": (ex.idempotencyKey), "transactionId": (s.details.transactionId), "scenarioInstanceId": (ex.scenarioInstanceId), "order": (payload)}
		Do request.%Set("runId", ex.runId, $Select(ex.runId = "": "null", 1: "string"))
		Do request.%Set("mappingRef", mappingRef, $Select($IsObject(mappingRef): "", 1: "null"))
		Set answer = ..Partner.Deliver(ex.partnerId, request)
		Set classified = ##class(SignalNoir.Core.ResponseClass).Classify(answer, ex.orderId, ex.idempotencyKey)
		Set f = ..Service.FinishAttempt(executionId, generation, s.details.n, answer, classified, ..Policy.MaxAttempts())
		If 'f.ok Return f
		If f.details.status = "retry" Continue
		If (f.details.status = "failed") && (classified.class = "business_error") Do ..Report(ex, s.details.attemptId, answer, classified, f)
		Return f
	}
}

/// A Partner refusal becomes a new Exception of the Order (research R9),
/// which opens a related Case; its Investigate request is handed back to
/// the entry point (details.commandId) so it is delivered next
Method Report(ex As SignalNoir.Application.Model.ExecutionRecord, attemptId As %String, answer As %DynamicObject, classified As %DynamicObject, result As SignalNoir.Core.Result) [ Private ]
{
	Set exc = ##class(SignalNoir.Core.Dto.CaseException).%New()
	Set exc.kind = classified.kind, exc.httpStatus = answer.status, exc.responseClass = classified.class
	Set exc.attemptId = attemptId, exc.observedAt = ..Service.Clock.NowUtc()
	If $IsObject(answer.%Get("json")) {
		Set exc.body = answer.json
	} Else {
		Set exc.bodyText = answer.%Get("text")
	}
	Set opened = ..Service.ProcessException(ex.orderId, exc)
	Set result.details.relatedCaseId = $Select(opened.ok: opened.ref, 1: "")
	If 'opened.ok {
		Set result.details.reportError = opened.message
		Quit
	}
	Set rs = ##class(%SQL.Statement).%ExecDirect(, "SELECT commandId FROM SignalNoir_Application_Model.OutboxRecord WHERE caseId = ? AND type = 'Investigate' AND status = 'pending'", opened.ref)
	If rs.%Next() Set result.details.commandId = rs.%Get("commandId")
}

/// A Receipt in a search result that settles this effect: same Order and,
/// when given, the same key ("" when none)
ClassMethod Match(page As %DynamicObject, orderId As %String, key As %String) As %DynamicObject
{
	If '$IsObject(page) || '$IsObject(page.%Get("items")) Return ""
	For i = 0 : 1 : page.items.%Size() - 1 {
		Set item = page.items.%Get(i)
		If (item.%Get("receiptId") = "") || (item.%Get("orderId") '= orderId) Continue
		If (key '= "") && (item.%Get("idempotencyKey") '= key) Continue
		Return item
	}
	Return ""
}

Method Row(executionId As %String) As SignalNoir.Application.Model.ExecutionRecord [ Private ]
{
	Set ex = ##class(SignalNoir.Application.Model.ExecutionRecord).%OpenId(executionId)
	If $IsObject(ex) Do ex.%Reload()
	Return ex
}

}
