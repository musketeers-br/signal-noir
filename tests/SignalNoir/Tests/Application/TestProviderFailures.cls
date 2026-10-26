Class SignalNoir.Tests.Application.TestProviderFailures Extends %UnitTest.TestCase
{

/// 006 T034 - US5: provider problems end in review, with the reason
/// Without AI Hub or key: review naming the provider. With them (build 154 +
/// .env, task T060): the real Agent call ends in a Proposal or an honest
/// review, with provider, model and tokens recorded.
Method TestRealAdapterWithoutAiHubOrKey()
{
	Set S = "SignalNoir.Tests.Support"
	Set svc = ##class(SignalNoir.Application.CaseService).Default()
	Set caseId = $ClassMethod(S, "InvestigatingCase", svc, "noai", "agent", .cmd, "SERUM")
	Set r = $ClassMethod(S, "Investigate", cmd, "SignalNoir.Proposers.Agent")
	Set c = svc.GetCase(caseId).obj
	If ##class(SignalNoir.Proposers.AiHubRuntime).Configured() {
		Set inv = ##class(SignalNoir.Application.Model.InvestigationRecord).%OpenId(cmd)
		Do $$$AssertTrue((c.proposals.Count() > 0) || (c.reviewReason = "invalid proposer response"), "a Proposal or an honest review: " _ c.state _ " " _ c.reviewReason)
		Do $$$AssertTrue(inv.provider '= "", "provider recorded")
		Do $$$AssertTrue(inv.model '= "", "model recorded")
		Do $$$AssertTrue(inv.tokensIn > 0, "tokens recorded")
		Do $$$AssertEquals(inv.toolCalls, 6, "same base package")
		Return
	}
	Do $$$AssertEquals(c.state, "ReviewRequired", "review")
	Do $$$AssertEquals($Extract(c.reviewReason, 1, 21), "provider unavailable:", "reason names the provider problem: " _ c.reviewReason)
	Do $$$AssertTrue(c.evidence.Count() >= 6, "base Evidence kept")
	Set inv = ##class(SignalNoir.Application.Model.InvestigationRecord).%OpenId(cmd)
	Do $$$AssertEquals(inv.status, "review", "outcome")
	Do $$$AssertEquals(inv.toolCalls, 6, "tool calls")
	Do $$$AssertTrue(inv.durationMs '= "", "duration")
	Do $$$AssertEquals(##class(SignalNoir.Proposers.Factory).Ready("agent"), ##class(SignalNoir.Proposers.AiHubRuntime).Configured(), "readiness follows the adapter")
}

Method TestRefusalProseAndFailure()
{
	Set S = "SignalNoir.Tests.Support"
	Set svc = ##class(SignalNoir.Application.CaseService).Default()
	Kill ^SignalNoir.TestScript("agent")
	For script = "content|I'm sorry, I can't help with that request.", "content|{""action"":""RETRY""", "fail|provider_unavailable:fake-ai-hub timed out", "fail|refused:content policy" {
		Kill ^SignalNoir.TestScript("agent")
		Set ^SignalNoir.TestScript("agent", $Piece(script, "|", 1)) = $Piece(script, "|", 2, *)
		Set caseId = $ClassMethod(S, "InvestigatingCase", svc, "fail", "agent", .cmd)
		Do $ClassMethod(S, "Investigate", cmd, "SignalNoir.Tests.Fakes.AgentWithFakeRuntime")
		Set c = svc.GetCase(caseId).obj
		Do $$$AssertEquals(c.state, "ReviewRequired", "review for " _ script)
		Set expected = $Select(script [ "provider_unavailable": "provider unavailable: fake-ai-hub timed out", 1: "invalid proposer response")
		Do $$$AssertEquals(c.reviewReason, expected, "reason for " _ script)
		Do $$$AssertEquals(c.proposals.Count(), 0, "nothing shown as a Proposal")
	}
	Kill ^SignalNoir.TestScript("agent")
}

/// FR-019: the key never lands in Evidence, Proposal, Timeline or Investigation
Method TestKeyNeverPersisted()
{
	Set key = $System.Util.GetEnviron("SN_AI_API_KEY")
	If key = "" Set key = "sk-signalnoir-test-key-never-stored"
	For table = "EvidenceRecord:resultJson", "EvidenceRecord:paramsJson", "ProposalRecord:diagnosisJson", "ProposalRecord:versionsJson", "CaseEventRecord:payloadJson", "InvestigationRecord:outcomeReason" {
		Set n = ##class(SignalNoir.Tests.Support).Count("SELECT COUNT(*) FROM SignalNoir_Application_Model." _ $Piece(table, ":", 1) _ " WHERE " _ $Piece(table, ":", 2) _ " [ ?", key)
		Do $$$AssertEquals(n, 0, "no key in " _ table)
	}
}

}
