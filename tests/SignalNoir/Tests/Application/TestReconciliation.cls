Class SignalNoir.Tests.Application.TestReconciliation Extends %UnitTest.TestCase
{

/// 008 T017 (US3) - an uncertain outcome is reconciled, never resent blindly
Parameter S = "SignalNoir.Tests.Support";

Method TestLostAnswerIsReconciled()
{
	Set svc = ##class(SignalNoir.Application.CaseService).Default()
	Set caseId = $ClassMethod(..#S, "ApprovedCase", svc, "rec-lost")
	Set partner = ##class(SignalNoir.Tests.Fakes.ScriptedPartner).%New()
	Do partner.Answers.%Push({"lose": 1})
	Set exec = $ClassMethod(..#S, "Executor", partner)
	; straight into the path: stop before the Reconcile is delivered
	Set r = exec.Execute(##class(SignalNoir.Tests.Application.TestCommandBus).Last(caseId, "Execute"))
	Do $$$AssertEquals(r.details.status, "reconciling", "uncertain: " _ r.message)
	Set c = svc.GetCase(caseId).obj
	Do $$$AssertEquals(c.state, "Executing", "the Case stays Executing")
	Do $$$AssertEquals(c.executions.%Get(0).outcome, "reconciling", "the outcome is unknown")
	Do $$$AssertEquals(c.executions.%Get(0).attempts.%Get(0).responseClass, "uncertain", "the attempt says so")
	Set cmd = ##class(SignalNoir.Tests.Application.TestCommandBus).Last(caseId, "Reconcile")
	Do $$$AssertEquals(r.details.commandId, cmd, "a Reconcile queued in the same commit")
	Do $$$AssertEquals(##class(SignalNoir.Tests.Application.TestCommandBus).Status(cmd), "pending", "pending")
	Do $$$AssertEquals(..SummaryOutcome(svc, caseId), "reconciling", "the summary shows the unknown outcome")
	Set r = $ClassMethod(..#S, "ExecBus", exec).Deliver(cmd)
	Do $$$AssertEquals(r.details.status, "resolved", "the Receipt settles it: " _ r.message)
	Set c = svc.GetCase(caseId).obj
	Do $$$AssertEquals(c.state, "Resolved", "Resolved")
	Do $$$AssertEquals(c.receipt.source, "reconciliation", "from reconciliation")
	Set rc = c.executions.%Get(0).reconciliations
	Do $$$AssertEquals(rc.%Get(rc.%Size() - 1).trigger _ ":" _ rc.%Get(rc.%Size() - 1).queriedBy, "timeout:idempotencyKey", "found by the key")
	Do $$$AssertEquals(c.executions.%Get(0).leaseGeneration, 2, "the reconciler took the lease over")
	Do $$$AssertEquals(partner.Deliveries, 1, "never sent again")
	Do $$$AssertEquals(partner.Count(c.orderId), 1, "one Receipt")
}

Method TestNoReceiptResendsTheSameEffect()
{
	Set svc = ##class(SignalNoir.Application.CaseService).Default()
	Set caseId = $ClassMethod(..#S, "ApprovedCase", svc, "rec-resend")
	Set partner = ##class(SignalNoir.Tests.Fakes.ScriptedPartner).%New()
	Do partner.Answers.%Push({"timeout": 1})
	Set bus = $ClassMethod(..#S, "ExecBus", $ClassMethod(..#S, "Executor", partner))
	Set r = $ClassMethod(..#S, "DeliverLast", bus, caseId)
	Do $$$AssertEquals(r.details.next.status, "resolved", "reconciled, resent, resolved: " _ r.details.%ToJSON())
	Set c = svc.GetCase(caseId).obj
	Set ex = c.executions.%Get(0)
	Do $$$AssertEquals(ex.attempts.%Size(), 2, "attempt 2 of the same execution")
	Do $$$AssertEquals(partner.Sent.%Get(1).idempotencyKey, partner.Sent.%Get(0).idempotencyKey, "same key")
	Do $$$AssertEquals(##class(SignalNoir.Core.EffectKey).Canonical(partner.Sent.%Get(1).order), ##class(SignalNoir.Core.EffectKey).Canonical(partner.Sent.%Get(0).order), "same payload")
	Do $$$AssertEquals(ex.reconciliations.%Size(), 3, "prior check, by key, by Order")
	Do $$$AssertEquals(partner.Count(c.orderId), 1, "one Receipt")
}

Method TestSameKeySamePayloadReturnsOriginal()
{
	Set partner = ##class(SignalNoir.Tests.Fakes.ScriptedPartner).%New()
	Set req = {"idempotencyKey": "bek_same", "order": {"orderId": "ORD-S", "exams": [{"code": "HEMO"}]}}
	Set a = partner.Deliver("labpartner-a", req)
	Set b = partner.Deliver("labpartner-a", {"idempotencyKey": "bek_same", "order": {"exams": [{"code": "HEMO"}], "orderId": "ORD-S"}})
	Do $$$AssertEquals(b.json.receiptId, a.json.receiptId, "the original Receipt")
	Do $$$AssertTrue(b.replayed, "marked as a replay")
	Do $$$AssertEquals(partner.Count("ORD-S"), 1, "one effect")
	Set c = partner.Deliver("labpartner-a", {"idempotencyKey": "bek_same", "order": {"orderId": "ORD-S", "exams": [{"code": "GLIC"}]}})
	Do $$$AssertEquals(c.status, 422, "same key, other payload: rejected")
	Set cls = ##class(SignalNoir.Core.ResponseClass).Classify(c, "ORD-S", "bek_same")
	Do $$$AssertEquals(cls.class, "business_error", "a refusal")
}

Method TestReusedKeyFails()
{
	Set svc = ##class(SignalNoir.Application.CaseService).Default()
	Set caseId = $ClassMethod(..#S, "ApprovedCase", svc, "rec-reused")
	Set partner = ##class(SignalNoir.Tests.Fakes.ScriptedPartner).%New()
	Set reused = "{""error"":{""code"":""IDEMPOTENCY_KEY_REUSED""}}"
	Do partner.Answers.%Push({"status": 422, "text": (reused)})
	Do $ClassMethod(..#S, "DeliverLast", $ClassMethod(..#S, "ExecBus", $ClassMethod(..#S, "Executor", partner)), caseId)
	Set c = svc.GetCase(caseId).obj
	Do $$$AssertEquals(c.state, "Failed", "the execution fails")
	Do $$$AssertTrue('$IsObject(c.receipt) || (c.receipt.%Size() = 0), "no Receipt recorded")
}

Method TestReconcilingOrderBlocksNewSends()
{
	Set svc = ##class(SignalNoir.Application.CaseService).Default()
	Set caseId = $ClassMethod(..#S, "ApprovedCase", svc, "rec-block")
	Set orderId = svc.GetCase(caseId).obj.orderId
	; another execution of the same Order is still unknown
	Set other = ##class(SignalNoir.Application.Model.ExecutionRecord).%New()
	Set other.executionId = ##class(SignalNoir.Application.IdFactory).%New().New("exec_"), other.caseId = "case_other_" _ $Job, other.orderId = orderId
	Set other.proposalId = "prop_other", other.action = "RETRY", other.outcome = "reconciling"
	Do other.%Save()
	Set partner = ##class(SignalNoir.Tests.Fakes.ScriptedPartner).%New()
	Set cmd = ##class(SignalNoir.Tests.Application.TestCommandBus).Last(caseId, "Execute")
	Set r = $ClassMethod(..#S, "ExecBus", $ClassMethod(..#S, "Executor", partner)).Deliver(cmd)
	Do $$$AssertEquals(r.details.status, "waiting", "waits for reconciliation")
	Do $$$AssertEquals(partner.Calls.deliver, 0, "nothing sent")
	Do $$$AssertEquals(svc.GetCase(caseId).obj.state, "Approved", "nothing changed")
	Do $$$AssertEquals(##class(SignalNoir.Tests.Application.TestCommandBus).Status(cmd), "pending", "the request stays pending")
	; once settled, the request goes through
	Set other.outcome = "resolved"
	Do other.%Save()
	Set r = $ClassMethod(..#S, "ExecBus", $ClassMethod(..#S, "Executor", partner)).Deliver(cmd)
	Do $$$AssertEquals(svc.GetCase(caseId).obj.state, "Resolved", "then it executes")
	Do other.%DeleteId(other.executionId)
}

Method TestUnreadableReceiptsStayUnknown()
{
	Set svc = ##class(SignalNoir.Application.CaseService).Default()
	Set caseId = $ClassMethod(..#S, "ApprovedCase", svc, "rec-unread")
	Set partner = ##class(SignalNoir.Tests.Fakes.ScriptedPartner).%New()
	Do partner.Answers.%Push({"timeout": 1})
	Set exec = $ClassMethod(..#S, "Executor", partner)
	Do exec.Execute(##class(SignalNoir.Tests.Application.TestCommandBus).Last(caseId, "Execute"))
	Set partner.ReceiptsReadable = 0
	Set r = $ClassMethod(..#S, "ExecBus", exec).Deliver(##class(SignalNoir.Tests.Application.TestCommandBus).Last(caseId, "Reconcile"))
	Do $$$AssertEquals(r.details.status, "reconciling", "still unknown")
	Set c = svc.GetCase(caseId).obj
	Do $$$AssertEquals(c.state _ ":" _ c.executionOutcome, "Executing:reconciling", "nothing settled")
	Do $$$AssertEquals(partner.Deliveries, 1, "nothing sent again")
	Do $$$AssertEquals($ClassMethod(..#S, "Count", "SELECT COUNT(*) FROM SignalNoir_Application_Model.OutboxRecord WHERE caseId = ? AND type = 'Reconcile' AND status = 'pending'", caseId), 0, "no new request: the lease pass asks again")
}

ClassMethod SummaryOutcome(svc As SignalNoir.Application.CaseService, caseId As %String) As %String
{
	Set rec = ##class(SignalNoir.Application.Model.CaseRecord).%OpenId(caseId)
	Do rec.%Reload()
	Return rec.executionOutcome
}

}
