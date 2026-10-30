Class SignalNoir.Tests.Application.TestLease Extends %UnitTest.TestCase
{

/// 008 T019 (US4) - leases with generations: restarts, late workers and
/// repeats do not duplicate the effect
Parameter S = "SignalNoir.Tests.Support";

/// An authorized execution whose worker started attempt 1 and stopped
ClassMethod Stalled(svc As SignalNoir.Application.CaseService, tag As %String, Output executionId As %String) As %String
{
	Set caseId = $ClassMethod(..#S, "ApprovedCase", svc, tag)
	Set c = svc.GetCase(caseId).obj
	Set snapshot = {}.%FromJSON(##class(SignalNoir.Application.Model.OrderRecord).%OpenId(c.orderId).snapshotJson)
	Set rv = ##class(SignalNoir.Core.ExecutionPolicy).%New().Revalidate({"now": (svc.Clock.NowUtc()), "health": {"status": "UP"}, "origin": {"status": "active"}, "approval": {"required": false}})
	Set plan = {"revalidation": (rv), "owner": "job:gone", "leaseSeconds": 300, "payload": (snapshot), "idempotencyKey": (##class(SignalNoir.Core.EffectKey).Derive(c.orderId, c.partnerId, snapshot))}
	Set a = svc.AuthorizeExecution(##class(SignalNoir.Tests.Application.TestCommandBus).Last(caseId, "Execute"), plan)
	Set executionId = a.details.executionId
	Do svc.StartAttempt(executionId, 1, "job:gone", 300)
	Return caseId
}

Method TestExpiredLeaseIsReconciledNotReviewed()
{
	Set svc = ##class(SignalNoir.Application.CaseService).Default()
	Set caseId = ..Stalled(svc, "lease-exec", .executionId)
	Set ex = svc.ExecutionJson(executionId)
	Do $$$AssertEquals(svc.GetCase(caseId).obj.state, "Executing", "in flight")
	Set partner = ##class(SignalNoir.Tests.Fakes.ScriptedPartner).%New()
	Set exec = $ClassMethod(..#S, "Executor", partner)
	; before the lease: the sweeper leaves it alone
	Set out = ##class(SignalNoir.Tasks.Sweeper).Run(##class(SignalNoir.Core.ApprovalPolicy).Plus(ex.stepLeaseUntil, -10), $ListBuild(caseId), 0, 30, "none", exec)
	Do $$$AssertEquals(out.reconcileRequested, 0, "a live lease is not rescued")
	; after it: reconciliation, never review
	Set out = ##class(SignalNoir.Tasks.Sweeper).Run(##class(SignalNoir.Core.ApprovalPolicy).Plus(ex.stepLeaseUntil, 1), $ListBuild(caseId), 0, 30, "none", exec)
	Do $$$AssertEquals(out.reconcileRequested, 1, "one Reconcile")
	Set c = svc.GetCase(caseId).obj
	Do $$$AssertNotTrue($ClassMethod(..#S, "Types", svc, caseId) [ "ReviewRequired", "never sent to review")
	Do $$$AssertEquals(c.state, "Resolved", "the reconciler finished it")
	Set ex = c.executions.%Get(0)
	Do $$$AssertEquals(ex.leaseGeneration, 2, "under a new generation")
	Do $$$AssertEquals(ex.reconciliations.%Get(0).trigger, "lease_expired", "triggered by the lease")
	Do $$$AssertEquals(partner.Count(c.orderId), 1, "one Receipt")
	Do $$$AssertTrue($ClassMethod(..#S, "Types", svc, caseId) [ "Annotation", "the sweeper says why")
}

Method TestLateWorkerIsDiscarded()
{
	Set svc = ##class(SignalNoir.Application.CaseService).Default()
	Set caseId = ..Stalled(svc, "lease-late", .executionId)
	Set r = svc.RequestReconcile(executionId, "lease_expired")
	Set t = svc.TakeOverExecution(r.ref, "job:new", 300)
	Do $$$AssertEquals(t.details.generation, 2, "taken over")
	; the old worker comes back with an answer that is not a Receipt
	Set late = svc.FinishAttempt(executionId, 1, 1, {"answered": true, "status": 503, "text": ""}, {"class": "transient", "kind": "http_error", "excerpt": ""}, 3)
	Do $$$AssertEquals(late.details.status, "discarded", "refused")
	Set ex = svc.ExecutionJson(executionId)
	Do $$$AssertEquals(ex.attempts.%Get(0).responseClass, "", "the later execution is untouched")
	Set events = $ClassMethod(..#S, "Types", svc, caseId)
	Do $$$AssertTrue(events [ "CommandDiscarded", "recorded as discarded")
	Do $$$AssertEquals(svc.StartAttempt(executionId, 1, "job:gone", 300).details.status, "discarded", "it cannot start another attempt either")
}

Method TestLateWorkerWithReceiptRequestsReconcile()
{
	Set svc = ##class(SignalNoir.Application.CaseService).Default()
	Set caseId = ..Stalled(svc, "lease-lostcas", .executionId)
	Set r = svc.RequestReconcile(executionId, "lease_expired")
	Do svc.TakeOverExecution(r.ref, "job:new", 300)
	Set ex = svc.ExecutionJson(executionId)
	Set c = svc.GetCase(caseId).obj
	Set receipt = {"receiptId": "rcp_late", "orderId": (c.orderId), "idempotencyKey": (ex.idempotencyKey), "receivedAt": "2026-10-28T10:00:00Z", "partnerId": "labpartner-a"}
	Set late = svc.FinishAttempt(executionId, 1, 1, {"answered": true, "status": 200, "json": (receipt)}, {"class": "success", "kind": "", "receipt": (receipt), "excerpt": ""}, 3)
	Do $$$AssertEquals(late.details.status, "discarded", "the write loses")
	Do $$$AssertTrue(late.details.commandId '= "", "but a Reconcile is requested")
	Set o = ##class(SignalNoir.Application.Model.OutboxRecord).%OpenId(late.details.commandId)
	Do $$$AssertEquals({}.%FromJSON(o.payloadJson).trigger, "lost_cas", "lost_cas")
	Do $$$AssertEquals(svc.GetCase(caseId).obj.state, "Executing", "nothing settled by the late worker")
}

Method TestRepeatedClick()
{
	Set svc = ##class(SignalNoir.Application.CaseService).Default()
	Set caseId = $ClassMethod(..#S, "PendingCase", svc, "lease-click")
	Set c = svc.GetCase(caseId).obj
	Set request = {"decision": "approved", "operator": "ana", "expectedCaseVersion": (c.caseVersion)}
	Set a = svc.DecideProposal(caseId, c.currentProposalId, request)
	Set b = svc.DecideProposal(caseId, c.currentProposalId, request)
	Do $$$AssertTrue(b.details.replay, "the second click is a replay")
	Set partner = ##class(SignalNoir.Tests.Fakes.ScriptedPartner).%New()
	Do $ClassMethod(..#S, "DeliverLast", $ClassMethod(..#S, "ExecBus", $ClassMethod(..#S, "Executor", partner)), caseId)
	Do $$$AssertEquals($ClassMethod(..#S, "Count", "SELECT COUNT(*) FROM SignalNoir_Application_Model.ApprovalRecord WHERE caseId = ?", caseId), 1, "one approval")
	Do $$$AssertEquals(svc.GetCase(caseId).obj.executions.%Size(), 1, "one execution")
	Do $$$AssertEquals(partner.Deliveries, 1, "one effect")
}

Method TestInvestigationLeaseGoesToReview()
{
	Set svc = ##class(SignalNoir.Application.CaseService).Default()
	Set caseId = $ClassMethod(..#S, "OpenCase", svc, $ClassMethod(..#S, "Uid", "lease-inv"))
	Do $ClassMethod(..#S, "DriveTo", svc, caseId, "Investigating")
	Set inv = ##class(SignalNoir.Application.Model.InvestigationRecord).%New()
	Set inv.investigationId = ##class(SignalNoir.Application.IdFactory).%New().New("cmd_"), inv.caseId = caseId
	Set inv.caseVersionAtStart = svc.GetCase(caseId).obj.caseVersion, inv.status = "open", inv.startedAt = "2026-10-28T10:00:00Z", inv.startedMs = 0
	Do inv.%Save()
	Set exec = $ClassMethod(..#S, "Executor", ##class(SignalNoir.Tests.Fakes.ScriptedPartner).%New())
	Set out = ##class(SignalNoir.Tasks.Sweeper).Run("2026-10-28T10:04:00Z", $ListBuild(caseId), 0, 30, "none", exec)
	Do $$$AssertEquals(out.leaseReviews, 0, "within the lease")
	Set out = ##class(SignalNoir.Tasks.Sweeper).Run("2026-10-28T10:06:00Z", $ListBuild(caseId), 0, 30, "none", exec)
	Do $$$AssertEquals(out.leaseReviews, 1, "past the lease")
	Do $$$AssertEquals(svc.GetCase(caseId).obj.state, "ReviewRequired", "to review")
}

}
