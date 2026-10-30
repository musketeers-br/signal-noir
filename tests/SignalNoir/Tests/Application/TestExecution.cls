Class SignalNoir.Tests.Application.TestExecution Extends %UnitTest.TestCase
{

/// 008 T011 (US1) - an approved Action reaches the Partner once
Parameter S = "SignalNoir.Tests.Support";

Method TestApprovedResendResolves()
{
	Set svc = ##class(SignalNoir.Application.CaseService).Default()
	Set caseId = $ClassMethod(..#S, "ApprovedCase", svc, "exec-ok")
	Set approvalId = svc.GetCase(caseId).obj.currentApprovalId
	Set partner = ##class(SignalNoir.Tests.Fakes.ScriptedPartner).%New()
	Set bus = $ClassMethod(..#S, "ExecBus", $ClassMethod(..#S, "Executor", partner))
	Set r = $ClassMethod(..#S, "DeliverLast", bus, caseId)
	Do $$$AssertTrue(r.ok, "delivered: " _ r.message)
	Do $$$AssertEquals(r.details.status, "resolved", "resolved")
	Set c = svc.GetCase(caseId).obj
	Do $$$AssertEquals(c.state, "Resolved", "the Case is resolved")
	Do $$$AssertEquals(c.executionOutcome, "resolved", "with the outcome")
	Set ex = c.executions.%Get(0)
	Do $$$AssertEquals(c.executions.%Size(), 1, "one execution")
	Do $$$AssertEquals(ex.approvalId, approvalId, "bound to the approval")
	Do $$$AssertEquals(ex.proposalId, c.currentProposalId, "and the Proposal")
	Do $$$AssertEquals(ex.leaseGeneration, 1, "generation 1")
	Do $$$AssertEquals($Extract(ex.idempotencyKey, 1, 4), "bek_", "the effect key")
	Do $$$AssertTrue(ex.revalidation.passed, "revalidated")
	Do $$$AssertEquals(ex.attempts.%Size(), 1, "one attempt")
	Do $$$AssertEquals(ex.attempts.%Get(0).responseClass, "success", "classified")
	Do $$$AssertEquals(ex.reconciliations.%Get(0).trigger, "prior_check", "the prior check by Order")
	Do $$$AssertNotTrue(ex.reconciliations.%Get(0).found, "found nothing")
	Do $$$AssertEquals(c.receipt.source, "delivery", "the Receipt copy")
	Do $$$AssertEquals(c.receipt.idempotencyKey, ex.idempotencyKey, "for the key sent")
	Do $$$AssertEquals(svc.ApprovalJson(approvalId).status, "consumed", "the approval is spent")
	Do $$$AssertEquals(partner.Deliveries, 1, "one delivery")
	Do $$$AssertEquals(partner.Count(c.orderId), 1, "the Partner holds one Receipt")
	Set sent = partner.Sent.%Get(0)
	Do $$$AssertEquals(sent.idempotencyKey, ex.idempotencyKey, "sent with the effect key")
	Do $$$AssertEquals(sent.order.orderId, c.orderId, "the snapshot is the payload")
	Do $$$AssertEquals(..Types(svc, caseId), "RevalidationPerformed,ExecutionAuthorized,StateChanged,ReconciliationPerformed,AttemptRecorded,ReceiptRecorded,StateChanged", "the Timeline tells the story")
}

Method TestPriorReceiptResolvesWithoutSending()
{
	Set svc = ##class(SignalNoir.Application.CaseService).Default()
	Set caseId = $ClassMethod(..#S, "ApprovedCase", svc, "exec-prior")
	Set partner = ##class(SignalNoir.Tests.Fakes.ScriptedPartner).%New()
	Do partner.Hold(svc.GetCase(caseId).obj.orderId, "idk_first_x")
	Set r = $ClassMethod(..#S, "DeliverLast", $ClassMethod(..#S, "ExecBus", $ClassMethod(..#S, "Executor", partner)), caseId)
	Do $$$AssertEquals(r.details.status, "resolved", "resolved: " _ r.message)
	Set c = svc.GetCase(caseId).obj
	Do $$$AssertEquals(c.state, "Resolved", "Resolved")
	Do $$$AssertEquals(partner.Calls.deliver, 0, "nothing sent")
	Do $$$AssertEquals(c.receipt.source, "reconciliation", "the copy came from reconciliation")
	Do $$$AssertEquals(c.executions.%Get(0).reconciliations.%Get(0).found, 1, "the prior check found it")
}

Method TestHoldExecutesWithoutPartner()
{
	Set svc = ##class(SignalNoir.Application.CaseService).Default()
	Set caseId = $ClassMethod(..#S, "HoldCase", svc, "exec-hold")
	Set partner = ##class(SignalNoir.Tests.Fakes.ScriptedPartner).%New()
	Set r = $ClassMethod(..#S, "DeliverLast", $ClassMethod(..#S, "ExecBus", $ClassMethod(..#S, "Executor", partner)), caseId)
	Do $$$AssertEquals(r.details.status, "held", "held: " _ r.message)
	Set c = svc.GetCase(caseId).obj
	Do $$$AssertEquals(c.state, "Held", "Held")
	Set ex = c.executions.%Get(0)
	Do $$$AssertEquals(ex.approvalId, "", "no approval")
	Do $$$AssertEquals(ex.attempts.%Size(), 0, "no attempt")
	Do $$$AssertEquals(ex.outcome, "held", "outcome held")
	Do $$$AssertEquals(partner.Calls.deliver + partner.Calls.health + partner.Calls.receipts, 0, "the Partner is not called")
}

Method TestNoSendWhenAuthorizationCannotBeStored()
{
	Set svc = ##class(SignalNoir.Application.CaseService).Default()
	Set caseId = $ClassMethod(..#S, "ApprovedCase", svc, "exec-broken")
	Set broken = ##class(SignalNoir.Application.CaseService).Default()
	Set broken.Ids = ##class(SignalNoir.Tests.Fakes.BrokenExecIds).%New()
	Set partner = ##class(SignalNoir.Tests.Fakes.ScriptedPartner).%New()
	Set r = $ClassMethod(..#S, "DeliverLast", $ClassMethod(..#S, "ExecBus", $ClassMethod(..#S, "Executor", partner, broken)), caseId)
	Do $$$AssertNotTrue(r.ok, "the authorization failed")
	Set c = svc.GetCase(caseId).obj
	Do $$$AssertEquals(c.state, "Approved", "still Approved")
	Do $$$AssertEquals(partner.Calls.deliver, 0, "no Partner call")
	Do $$$AssertEquals(c.executions.%Size(), 0, "no execution")
	Do $$$AssertEquals(##class(SignalNoir.Tests.Application.TestCommandBus).Status(##class(SignalNoir.Tests.Application.TestCommandBus).Last(caseId, "Execute")), "pending", "the request is still pending")
}

Method TestExecuteDeliveredTwice()
{
	Set svc = ##class(SignalNoir.Application.CaseService).Default()
	Set caseId = $ClassMethod(..#S, "ApprovedCase", svc, "exec-twice")
	Set partner = ##class(SignalNoir.Tests.Fakes.ScriptedPartner).%New()
	Set exec = $ClassMethod(..#S, "Executor", partner)
	Set cmd = ##class(SignalNoir.Tests.Application.TestCommandBus).Last(caseId, "Execute")
	Set bus = $ClassMethod(..#S, "ExecBus", exec)
	Do bus.Deliver(cmd)
	Set r = bus.Deliver(cmd)
	Do $$$AssertEquals(r.details.status, "already done", "the second delivery does nothing")
	; even straight into the path, bypassing the entry point
	Set r = exec.Execute(cmd)
	Do $$$AssertEquals(r.details.status, "already done", "the path checks too")
	Do $$$AssertEquals(svc.GetCase(caseId).obj.executions.%Size(), 1, "one execution")
	Do $$$AssertEquals(partner.Calls.deliver, 1, "one delivery")
}

/// Timeline event types after the approval (the execution's part)
ClassMethod Types(svc As SignalNoir.Application.CaseService, caseId As %String) As %String
{
	Set all = $Translate($ClassMethod(..#S, "Types", svc, caseId), ";", ",")
	Set from = $Find(all, "ApprovalRecorded,StateChanged,")
	Set tail = $Select(from: $Extract(all, from, *), 1: all)
	Return $Select($Extract(tail, *) = ",": $Extract(tail, 1, *-1), 1: tail)
}

}
