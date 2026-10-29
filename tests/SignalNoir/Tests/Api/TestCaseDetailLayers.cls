Class SignalNoir.Tests.Api.TestCaseDetailLayers Extends %UnitTest.TestCase
{

/// 006 T037 - the detail shows Evidence, Proposals, Diagnosis and metrics
Method TestDetailLayers()
{
	Set S = "SignalNoir.Tests.Support"
	Set svc = ##class(SignalNoir.Application.CaseService).Default()
	Set caseId = $ClassMethod(S, "InvestigatingCase", svc, "api-layers", "rules", .cmd)
	Do $ClassMethod(S, "Script", caseId, "answer", $ClassMethod(S, "P5Answer"))
	Do $ClassMethod(S, "Investigate", cmd)
	Set p = ##class(SignalNoir.Api.Dispatch).CasePayload(svc.GetCase(caseId).obj)
	Do $$$AssertTrue(p.evidence.%Size() >= 6, "evidence")
	Set ev = p.evidence.%Get(0)
	For f = "evidenceId", "source", "observedAt", "result", "suspicious", "params", "calledBy" {
		Do $$$AssertTrue(ev.%IsDefined(f), "Evidence." _ f)
	}
	Do $$$AssertEquals(ev.%GetTypeOf("suspicious"), "boolean", "suspicious boolean")
	Do $$$AssertEquals(p.proposals.%Size(), 1, "proposals")
	Set pr = p.proposals.%Get(0)
	For f = "proposalId", "author", "createdAt", "current", "diagnosis", "action", "params", "scope", "confidence", "preconditions", "versions", "metrics" {
		Do $$$AssertTrue(pr.%IsDefined(f), "Proposal." _ f)
	}
	Do $$$AssertEquals(pr.%GetTypeOf("current"), "boolean", "current boolean")
	Do $$$AssertEquals(pr.%GetTypeOf("priorReceiptCandidate"), "null", "no prior receipt candidate is null, not {}")
	Do $$$AssertEquals(p.currentProposalId, pr.proposalId, "currentProposalId")
	Do $$$AssertEquals(p.diagnosis.summary, pr.diagnosis.summary, "diagnosis of the current Proposal")
	Do $$$AssertEquals(p.metrics.toolCalls, 6, "metrics.toolCalls")
	Do $$$AssertEquals(p.metrics.provider, "scripted", "metrics.provider")
	Set run = svc.ListCases("", "older", 200, {"state": ["ReviewRequired"]})
	Set found = ""
	For i = 1 : 1 : run.list.Count() If run.list.GetAt(i).caseId = caseId Set found = run.list.GetAt(i)
	Set s = ##class(SignalNoir.Api.Dispatch).SummaryPayload(found)
	Do $$$AssertEquals(s.currentProposal.proposalId, pr.proposalId, "summary currentProposal")
	Do $$$AssertEquals(s.currentProposal.action, "REQUEST_REVIEW", "summary action")
	Do $$$AssertEquals(s.currentProposal.confidence, "MEDIUM", "summary confidence")
	Do $ClassMethod(S, "ClearScript", caseId)
}


/// 008 T025 - the detail shows executions and the Receipt copy; the
/// summary carries the latest execution's outcome (contract CaseSummary)
Method TestExecutionLayers()
{
	Set S = "SignalNoir.Tests.Support"
	Set svc = ##class(SignalNoir.Application.CaseService).Default()
	Set caseId = $ClassMethod(S, "ApprovedCase", svc, "api-exec")
	Set partner = ##class(SignalNoir.Tests.Fakes.ScriptedPartner).%New()
	Do $ClassMethod(S, "DeliverLast", $ClassMethod(S, "ExecBus", $ClassMethod(S, "Executor", partner)), caseId)
	Set p = ##class(SignalNoir.Api.Dispatch).CasePayload(svc.GetCase(caseId).obj)
	Do $$$AssertEquals(p.executions.%Size(), 1, "one execution")
	Set ex = p.executions.%Get(0)
	For f = "executionId", "approvalId", "proposalId", "action", "idempotencyKey", "authorizedAt", "leaseGeneration", "revalidation", "attempts", "reconciliations", "outcome", "completedAt" {
		Do $$$AssertTrue(ex.%IsDefined(f), "Execution." _ f)
	}
	Do $$$AssertEquals(ex.outcome, "resolved", "outcome")
	Do $$$AssertEquals(ex.revalidation.%GetTypeOf("passed"), "boolean", "revalidation.passed boolean")
	Set at = ex.attempts.%Get(0)
	For f = "attemptId", "n", "sentAt", "completedAt", "httpStatus", "responseClass", "receiptId" {
		Do $$$AssertTrue(at.%IsDefined(f), "Attempt." _ f)
	}
	Set rc = ex.reconciliations.%Get(0)
	For f = "at", "trigger", "queriedBy", "found" {
		Do $$$AssertTrue(rc.%IsDefined(f), "Reconciliation." _ f)
	}
	Do $$$AssertEquals(rc.%GetTypeOf("found"), "boolean", "found boolean")
	For f = "receiptId", "orderId", "idempotencyKey", "receivedAt", "partnerId", "source" {
		Do $$$AssertTrue(p.receipt.%IsDefined(f), "ReceiptCopy." _ f)
	}
	Set run = svc.ListCases("", "older", 200, {"state": ["Resolved"]})
	Set found = ""
	For i = 1 : 1 : run.list.Count() If run.list.GetAt(i).caseId = caseId Set found = run.list.GetAt(i)
	Do $$$AssertEquals(##class(SignalNoir.Api.Dispatch).SummaryPayload(found).executionOutcome, "resolved", "summary executionOutcome")
	; a Case without execution keeps the empty shape
	Set other = $ClassMethod(S, "PendingCase", svc, "api-noexec")
	Set q = ##class(SignalNoir.Api.Dispatch).CasePayload(svc.GetCase(other).obj)
	Do $$$AssertEquals(q.executions.%Size(), 0, "no executions")
	Do $$$AssertEquals(q.%GetTypeOf("receipt"), "null", "receipt null")
}

}
