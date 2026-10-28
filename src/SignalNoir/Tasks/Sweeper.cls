Class SignalNoir.Tasks.Sweeper Extends %RegisteredObject
{

/// The single periodic sweep (AD-8, feature 007). Two passes: redelivery of
/// requests still pending after a grace period, and expiry of approvals past
/// their deadline. It only issues commands allowed to the actor sweeper and
/// deliveries to the single entry point. The lease pass (AD-22) is 008's.
/// Requests redelivered per run, at most
Parameter MAXPERRUN = 50;

/// now: "" for the clock; scope: $List of caseIds ("" = all); async: deliver
/// in background jobs (the scheduled task) or inline (tests).
/// Returns {redelivered, expired}.
ClassMethod Run(now As %String = "", scope As %List = "", async As %Boolean = 1, graceSeconds As %Integer = 30) As %DynamicObject
{
	Set svc = ##class(SignalNoir.Application.CaseService).Default()
	If now = "" Set now = svc.Clock.NowUtc()
	Set nowSecs = ##class(SignalNoir.Core.ApprovalPolicy).Seconds(now)
	; 1. requests whose delivery was lost
	Set redelivered = 0
	Set bus = ##class(SignalNoir.Application.CommandBus).Default()
	Set rs = ##class(%SQL.Statement).%ExecDirect(, "SELECT commandId, caseId, createdAt FROM SignalNoir_Application_Model.OutboxRecord WHERE status = 'pending' ORDER BY createdAt, commandId")
	While rs.%Next() && (redelivered < ..#MAXPERRUN) {
		If (scope '= "") && '$ListFind(scope, rs.%Get("caseId")) Continue
		If (nowSecs - ##class(SignalNoir.Core.ApprovalPolicy).Seconds(rs.%Get("createdAt"))) < graceSeconds Continue
		If async {
			Job ##class(SignalNoir.Application.CommandBus).DeliverJob(rs.%Get("commandId"))
			Set redelivered = redelivered + 1
		} Else {
			Set r = bus.Deliver(rs.%Get("commandId"))
			If r.ok && (r.details.status '= "waiting") Set redelivered = redelivered + 1
		}
	}
	; 2. approvals past their deadline
	Set expired = 0
	Set rs = ##class(%SQL.Statement).%ExecDirect(, "SELECT approvalId, caseId, expiresAt FROM SignalNoir_Application_Model.ApprovalRecord WHERE decision = 'approved' AND status = 'valid'")
	While rs.%Next() {
		If (scope '= "") && '$ListFind(scope, rs.%Get("caseId")) Continue
		If 'svc.Policy().IsExpired(rs.%Get("expiresAt"), now) Continue
		Set r = svc.ExpireApproval(rs.%Get("approvalId"), now)
		If r.ok && r.details.expired Set expired = expired + 1
	}
	Return {"redelivered": (redelivered), "expired": (expired)}
}

}
