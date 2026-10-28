Class SignalNoir.Tests.Api.TestDecisionApi Extends %UnitTest.TestCase
{

/// 007 T019 - the decision answers follow the contract (ProposalDecisionResult)
Method TestCreatedAndReplay()
{
	Set S = "SignalNoir.Tests.Support"
	Set svc = ##class(SignalNoir.Application.CaseService).Default()
	Set caseId = $ClassMethod(S, "PendingCase", svc, "api-dec")
	Set r = $ClassMethod(S, "Decide", svc, caseId, "approved", "Carla")
	Set p = ##class(SignalNoir.Api.Dispatch).DecisionPayload(svc, r.details)
	Do $$$AssertEquals(##class(SignalNoir.Api.Dispatch).DecisionStatus(r), "201 Created", "201")
	Do $$$AssertEquals(p.%GetTypeOf("idempotentReplay"), "boolean", "boolean flag")
	Do $$$AssertEquals(p.idempotentReplay, 0, "not a replay")
	For f = "approvalId", "proposalId", "decision", "by", "at", "expiresAt", "status" Do $$$AssertTrue(p.approval.%IsDefined(f), "Approval." _ f)
	Do $$$AssertEquals(p.approval.by, "operator:Carla", "by")
	For f = "caseId", "state", "caseVersion", "lastEventSeq", "serverTime", "commandId" Do $$$AssertTrue(p.case.%IsDefined(f), "CommandAck." _ f)
	Do $$$AssertEquals(p.case.state, "Approved", "state")
	Do $$$AssertTrue(p.case.commandId [ "cmd_", "request id")
	Set c = svc.GetCase(caseId).obj
	Set again = svc.DecideProposal(caseId, c.currentProposalId, {"decision": "approved", "operator": "Carla", "expectedCaseVersion": 1})
	Set p = ##class(SignalNoir.Api.Dispatch).DecisionPayload(svc, again.details)
	Do $$$AssertEquals(##class(SignalNoir.Api.Dispatch).DecisionStatus(again), "200 OK", "200 on replay")
	Do $$$AssertEquals(p.idempotentReplay, 1, "replay flag")
	Do $$$AssertEquals(p.case.%GetTypeOf("commandId"), "null", "no new request")
}

Method TestDenialPayload()
{
	Set S = "SignalNoir.Tests.Support"
	Set svc = ##class(SignalNoir.Application.CaseService).Default()
	Set caseId = $ClassMethod(S, "PendingCase", svc, "api-deny")
	Set r = $ClassMethod(S, "Decide", svc, caseId, "denied", "Carla", "maintenance window")
	Set p = ##class(SignalNoir.Api.Dispatch).DecisionPayload(svc, r.details)
	Do $$$AssertEquals(p.approval.decision, "denied", "denied")
	Do $$$AssertEquals(p.approval.%GetTypeOf("expiresAt"), "null", "no deadline")
	Do $$$AssertEquals(p.approval.reason, "maintenance window", "reason")
	Do $$$AssertEquals(p.case.state, "Rejected", "Rejected")
	Do $$$AssertTrue(p.case.commandId [ "cmd_", "the follow-up request")
}

}
