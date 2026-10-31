Class SignalNoir.Tasks.Sweeper Extends %RegisteredObject
{

/// The single periodic sweep (AD-8, features 007, 008 and 015). Five passes:
/// redelivery of requests still pending after a grace period; expiry of
/// approvals past their deadline; the lease pass (AD-22: an execution past
/// its lease gets Reconcile, an investigation past it goes to review); and
/// the reassessment of Held Cases (AD-7); and the indexing of closed Cases
/// as precedents (015, unscoped sweeps only). It only issues commands allowed
/// to the actor sweeper and deliveries to the single entry point; it reads
/// the Partner's health, never acts on the Partner.
/// Requests redelivered per run, at most
Parameter MAXPERRUN = 50;

/// now: "" for the clock; scope: $List of caseIds ("" = all); async: deliver
/// in background jobs (the scheduled task) or inline (tests); investigations:
/// "default", or "none" to leave Investigate requests pending (tests), and
/// Execute and Reconcile too unless an executor is given; executor: the
/// execution path that delivers them and whose Partner and policy the lease
/// and Held passes use ("" = ExecutionService.Default()).
/// Returns {redelivered, expired, reconcileRequested, leaseReviews, reassessed,
/// precedentsIndexed}.
ClassMethod Run(now As %String = "", scope As %List = "", async As %Boolean = 1, graceSeconds As %Integer = 30, investigations As %String = "default", executor As SignalNoir.Application.ExecutionService = "") As %DynamicObject
{
	Set svc = ##class(SignalNoir.Application.CaseService).Default()
	If now = "" Set now = svc.Clock.NowUtc()
	Set nowSecs = ##class(SignalNoir.Core.ApprovalPolicy).Seconds(now)
	; "none" also leaves executions pending, unless the caller hands its own execution path
	Set executions = $Select($IsObject(executor): "default", 1: investigations)
	If '$IsObject(executor) Set executor = ##class(SignalNoir.Application.ExecutionService).Default()
	Set bus = ##class(SignalNoir.Application.CommandBus).Default()
	Set bus.Investigations = investigations, bus.Executions = executions, bus.Executor = executor
	; 1. requests whose delivery was lost
	Set redelivered = 0
	Set rs = ##class(%SQL.Statement).%ExecDirect(, "SELECT commandId, caseId, createdAt FROM SignalNoir_Application_Model.OutboxRecord WHERE status = 'pending' ORDER BY createdAt, commandId")
	While rs.%Next() && (redelivered < ..#MAXPERRUN) {
		If '..InScope(scope, rs.%Get("caseId")) Continue
		If (nowSecs - ##class(SignalNoir.Core.ApprovalPolicy).Seconds(rs.%Get("createdAt"))) < graceSeconds Continue
		If ..Deliver(bus, rs.%Get("commandId"), async) Set redelivered = redelivered + 1
	}
	; 2. approvals past their deadline
	Set expired = 0
	Set rs = ##class(%SQL.Statement).%ExecDirect(, "SELECT approvalId, caseId, expiresAt FROM SignalNoir_Application_Model.ApprovalRecord WHERE decision = 'approved' AND status = 'valid'")
	While rs.%Next() {
		If '..InScope(scope, rs.%Get("caseId")) Continue
		If 'svc.Policy().IsExpired(rs.%Get("expiresAt"), now) Continue
		Set r = svc.ExpireApproval(rs.%Get("approvalId"), now)
		If r.ok && r.details.expired Set expired = expired + 1
	}
	; 3. leases (AD-22): Executing -> Reconcile, never review; Investigating -> review
	Set reconcile = 0, reviews = 0
	Set rs = ##class(%SQL.Statement).%ExecDirect(, "SELECT executionId, caseId, stepLeaseUntil FROM SignalNoir_Application_Model.ExecutionRecord WHERE outcome IN ('in_progress', 'reconciling')")
	While rs.%Next() {
		If '..InScope(scope, rs.%Get("caseId")) || (rs.%Get("stepLeaseUntil") = "") Continue
		If ##class(SignalNoir.Core.ApprovalPolicy).Seconds(rs.%Get("stepLeaseUntil")) >= nowSecs Continue
		Set r = svc.RequestReconcile(rs.%Get("executionId"), "lease_expired")
		If 'r.ok || (r.ref = "") Continue
		Set reconcile = reconcile + 1
		Do ..Deliver(bus, r.ref, async)
	}
	Set lease = executor.Policy.LeaseSeconds()
	Set rs = ##class(%SQL.Statement).%ExecDirect(, "SELECT i.investigationId, i.caseId, i.startedAt FROM SignalNoir_Application_Model.InvestigationRecord i, SignalNoir_Application_Model.CaseRecord c WHERE i.status = 'open' AND c.caseId = i.caseId AND c.state = 'Investigating'")
	While rs.%Next() {
		If '..InScope(scope, rs.%Get("caseId")) || (rs.%Get("startedAt") = "") Continue
		If (nowSecs - ##class(SignalNoir.Core.ApprovalPolicy).Seconds(rs.%Get("startedAt"))) <= lease Continue
		Set r = svc.CloseInvestigation(rs.%Get("investigationId"), "investigation lease expired (sweeper)", "")
		If r.ok && (r.details.status = "review") Set reviews = reviews + 1
	}
	; 4. Held: reassess after the minimum hold, when the waiting condition ended
	Set reassessed = 0
	Set rs = ##class(%SQL.Statement).%ExecDirect(, "SELECT caseId, caseVersion, updatedAt, currentExecutionId, partnerId, orderId FROM SignalNoir_Application_Model.CaseRecord WHERE state = 'Held'")
	While rs.%Next() {
		If '..InScope(scope, rs.%Get("caseId")) Continue
		If (nowSecs - ##class(SignalNoir.Core.ApprovalPolicy).Seconds(rs.%Get("updatedAt"))) < executor.Policy.MinHoldSeconds() Continue
		Set observed = ..HoldEnded(executor, rs.%Get("currentExecutionId"), rs.%Get("partnerId"), rs.%Get("orderId"))
		If '$IsObject(observed) Continue
		Set r = svc.ReassessHeld(rs.%Get("caseId"), rs.%Get("caseVersion"), observed)
		If 'r.ok Continue
		Set reassessed = reassessed + 1
		If r.details.commandId '= "" Do ..Deliver(bus, r.details.commandId, async)
	}
	; 5. closed Cases not yet precedents (feature 015); a scoped sweep (tests) leaves them
	Set precedents = 0
	If scope = "" {
		Set r = ##class(SignalNoir.Application.PrecedentService).Default().IndexPending()
		Set precedents = +r.ref
	}
	Return {"redelivered": (redelivered), "expired": (expired), "reconcileRequested": (reconcile), "leaseReviews": (reviews), "reassessed": (reassessed), "precedentsIndexed": (precedents)}
}

/// What ended the hold ("" while it holds): a version hold ends at once (the
/// new Proposal is the fix); otherwise the Partner must be UP with no
/// active maintenance
ClassMethod HoldEnded(executor As SignalNoir.Application.ExecutionService, executionId As %String, partnerId As %String, orderId As %String) As %DynamicObject [ Private ]
{
	Set ex = ##class(SignalNoir.Application.Model.ExecutionRecord).%OpenId(executionId)
	If $IsObject(ex) && (ex.revalidationJson '= "") {
		Set failed = "", versionOnly = 1, checks = {}.%FromJSON(ex.revalidationJson).checks
		For i = 0 : 1 : checks.%Size() - 1 {
			Set c = checks.%Get(i)
			If c.passed Continue
			Set failed = failed _ $Select(failed = "": "", 1: ",") _ c.check
			If '$ListFind($ListBuild("POLICY_VERSION_UNCHANGED", "MAPPING_VERSION_UNCHANGED"), c.check) Set versionOnly = 0
		}
		If (failed '= "") && versionOnly Return {"reason": ("version changed: " _ failed)}
	}
	Set orderRec = ##class(SignalNoir.Application.Model.OrderRecord).%OpenId(orderId)
	Set health = executor.Partner.Health(partnerId, $Select($IsObject(orderRec): orderRec.scenarioInstanceId, 1: ""))
	If 'health.ok Return ""
	Set inMaintenance = $IsObject(health.obj.%Get("maintenance")) && health.obj.maintenance.active
	If (health.obj.status '= "UP") || inMaintenance Return ""
	Return {"reason": "partner healthy", "health": (health.obj.status)}
}

ClassMethod InScope(scope As %List, caseId As %String) As %Boolean [ Private ]
{
	Return (scope = "") || ($ListFind(scope, caseId) > 0)
}

/// Delivers one request (background job or inline); true when it was handled
ClassMethod Deliver(bus As SignalNoir.Application.CommandBus, commandId As %String, async As %Boolean) As %Boolean [ Private ]
{
	If async {
		Job ##class(SignalNoir.Application.CommandBus).DeliverJob(commandId)
		Return 1
	}
	Set r = bus.Deliver(commandId)
	Return r.ok && (r.details.status '= "waiting")
}

}
