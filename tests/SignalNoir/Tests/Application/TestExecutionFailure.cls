Class SignalNoir.Tests.Application.TestExecutionFailure Extends %UnitTest.TestCase
{

/// 008 T023 (US6) - refusals and exhausted attempts fail honestly
Parameter S = "SignalNoir.Tests.Support";

Method TestBusinessErrorFailsAndOpensARelatedCase()
{
	Set svc = ##class(SignalNoir.Application.CaseService).Default()
	Set caseId = $ClassMethod(..#S, "ApprovedCase", svc, "fail-500")
	Set orderId = svc.GetCase(caseId).obj.orderId
	Set partner = ##class(SignalNoir.Tests.Fakes.ScriptedPartner).%New()
	Set body = "{""erro"":""GLIC-J descontinuado"",""detalhe"":""" _ $Translate($Justify("", 700), " ", "x") _ """}"
	Do partner.Answers.%Push({"status": 500, "text": (body)})
	Set r = $ClassMethod(..#S, "DeliverLast", $ClassMethod(..#S, "ExecBus", $ClassMethod(..#S, "Executor", partner)), caseId)
	Do $$$AssertEquals(r.details.status, "failed", "failed: " _ r.message)
	Set c = svc.GetCase(caseId).obj
	Do $$$AssertEquals(c.state, "Failed", "the Case fails")
	Set at = c.executions.%Get(0).attempts.%Get(0)
	Do $$$AssertEquals(at.responseClass _ ":" _ at.httpStatus, "business_error:500", "classified")
	Do $$$AssertEquals($Length(at.bodyExcerpt), 500, "with a body excerpt")
	Do $$$AssertEquals(partner.Deliveries, 1, "never retried")
	; the refusal is a new Exception of the Order: a related Case
	Set open = svc.OpenCase(orderId)
	Do $$$AssertTrue(open.ok, "a related Case is open")
	Set related = svc.GetCase(open.ref).obj
	Do $$$AssertEquals(related.previousCaseId, caseId, "related to the failed Case")
	Do $$$AssertEquals(related.exceptions.GetAt(1).kind _ ":" _ related.exceptions.GetAt(1).httpStatus, "http_error:500", "with the refusal")
	Do $$$AssertEquals(related.state, "Investigating", "under investigation")
	Do $$$AssertEquals(r.details.next.commandId, ##class(SignalNoir.Tests.Application.TestCommandBus).Last(open.ref, "Investigate"), "its request is handed to the entry point")
}

Method Test409IsABusinessRejection()
{
	Set svc = ##class(SignalNoir.Application.CaseService).Default()
	Set caseId = $ClassMethod(..#S, "ApprovedCase", svc, "fail-409")
	Set partner = ##class(SignalNoir.Tests.Fakes.ScriptedPartner).%New()
	Do partner.Answers.%Push({"status": 409, "text": "already processed: rcp_000123"})
	Do $ClassMethod(..#S, "DeliverLast", $ClassMethod(..#S, "ExecBus", $ClassMethod(..#S, "Executor", partner)), caseId)
	Set related = svc.GetCase(svc.OpenCase(svc.GetCase(caseId).obj.orderId).ref).obj
	Do $$$AssertEquals(related.exceptions.GetAt(1).kind, "business_rejection", "a business rejection")
}

Method TestTransientThenSuccess()
{
	Set svc = ##class(SignalNoir.Application.CaseService).Default()
	Set caseId = $ClassMethod(..#S, "ApprovedCase", svc, "fail-transient")
	Set partner = ##class(SignalNoir.Tests.Fakes.ScriptedPartner).%New()
	Do partner.Answers.%Push({"status": 503, "text": "{}"})
	Do $ClassMethod(..#S, "DeliverLast", $ClassMethod(..#S, "ExecBus", $ClassMethod(..#S, "Executor", partner)), caseId)
	Set c = svc.GetCase(caseId).obj
	Do $$$AssertEquals(c.state, "Resolved", "the retry succeeded")
	Do $$$AssertEquals(c.executions.%Get(0).attempts.%Size(), 2, "two attempts")
	Do $$$AssertEquals(partner.Sent.%Get(1).idempotencyKey, partner.Sent.%Get(0).idempotencyKey, "same key")
	Do $$$AssertTrue(partner.Sent.%Get(1).transactionId '= partner.Sent.%Get(0).transactionId, "each attempt its own transaction")
}

Method TestExhaustedBudgetFails()
{
	Set svc = ##class(SignalNoir.Application.CaseService).Default()
	Set caseId = $ClassMethod(..#S, "ApprovedCase", svc, "fail-budget")
	Set orderId = svc.GetCase(caseId).obj.orderId
	Set partner = ##class(SignalNoir.Tests.Fakes.ScriptedPartner).%New()
	For i = 1 : 1 : 3 Do partner.Answers.%Push({"status": 503, "text": "{}"})
	Do $ClassMethod(..#S, "DeliverLast", $ClassMethod(..#S, "ExecBus", $ClassMethod(..#S, "Executor", partner)), caseId)
	Set c = svc.GetCase(caseId).obj
	Do $$$AssertEquals(c.state, "Failed", "failed")
	Do $$$AssertEquals(c.executions.%Get(0).attempts.%Size(), 3, "the whole budget")
	Do $$$AssertNotTrue(svc.OpenCase(orderId).ok, "no new Case for unavailability")
}

Method TestWrongKeyReceiptIsNotSuccess()
{
	Set svc = ##class(SignalNoir.Application.CaseService).Default()
	Set caseId = $ClassMethod(..#S, "ApprovedCase", svc, "fail-wrongkey")
	Set orderId = svc.GetCase(caseId).obj.orderId
	Set partner = ##class(SignalNoir.Tests.Fakes.ScriptedPartner).%New()
	Do partner.Answers.%Push({"status": 200, "json": {"receiptId": "rcp_bogus", "orderId": (orderId), "idempotencyKey": "bek_other", "receivedAt": "2026-10-28T10:00:00Z", "partnerId": "labpartner-a"}})
	Set exec = $ClassMethod(..#S, "Executor", partner)
	Set r = exec.Execute(##class(SignalNoir.Tests.Application.TestCommandBus).Last(caseId, "Execute"))
	Do $$$AssertEquals(r.details.status, "reconciling", "uncertain, not success")
	Set c = svc.GetCase(caseId).obj
	Do $$$AssertTrue('$IsObject(c.receipt) || (c.receipt.%Size() = 0), "no Receipt copy")
}

}
