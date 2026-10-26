Class SignalNoir.Tests.Application.TestInvestigation Extends %UnitTest.TestCase
{

/// 006 T011, T026 - US1/US3: an Investigation produces an evidence-linked,
/// immutable Proposal; invalid answers end in review
Method TestP5ProducesEvidenceLinkedProposal()
{
	Set S = "SignalNoir.Tests.Support"
	Set svc = ##class(SignalNoir.Application.CaseService).Default()
	Set caseId = $ClassMethod(S, "InvestigatingCase", svc, "p5", "rules", .cmd)
	Do $ClassMethod(S, "Script", caseId, "answer", $ClassMethod(S, "P5Answer"))
	Set r = $ClassMethod(S, "Investigate", cmd)
	Do $$$AssertTrue(r.ok, "ran")
	Do $$$AssertEquals(r.details.status, "proposed", "proposed: " _ r.details.reason)
	Set c = svc.GetCase(caseId).obj
	Do $$$AssertEquals(c.state, "DecisionProposed", "DecisionProposed")
	Do $$$AssertEquals(c.proposals.Count(), 1, "one Proposal")
	Set p = c.proposals.GetAt(1)
	Do $$$AssertEquals($Extract(p.proposalId, 1, 5), "prop_", "own proposalId")
	Do $$$AssertEquals(c.currentProposalId, p.proposalId, "current")
	Do $$$AssertEquals(p.origin, "rules", "author is the mode")
	Do $$$AssertEquals(p.action, "REQUEST_REVIEW", "action")
	Do $$$AssertEquals(p.scope, "single_case", "scope")
	; every claim cites Evidence of this Case
	Kill ids
	For i = 1 : 1 : c.evidence.Count() Set ids(c.evidence.GetAt(i).evidenceId) = c.evidence.GetAt(i).source
	Set claims = p.diagnosis.claims
	For i = 0 : 1 : claims.%Size() - 1 {
		Set cited = claims.%Get(i).evidenceIds
		Do $$$AssertTrue(cited.%Size() >= 1, "claim cites Evidence")
		For j = 0 : 1 : cited.%Size() - 1 Do $$$AssertTrue($Data(ids(cited.%Get(j))), "cited Evidence is on the Case")
	}
	Do $$$AssertEquals(p.diagnosis.hypotheses.%Get(0).reason, "health is UP", "discarded hypothesis keeps its reason")
	; Exceptions are system Evidence; the base package is 5 Tool calls before the Proposal
	Set sources = ""
	For i = 1 : 1 : c.evidence.Count() Set sources = sources _ c.evidence.GetAt(i).source _ ","
	Do $$$AssertTrue(sources [ "system.exception", "Exception recorded as Evidence")
	Set types = $ClassMethod(S, "Types", svc, caseId)
	Do $$$AssertTrue(types [ "ToolCalled;ToolCalled;ToolCalled;ToolCalled;ToolCalled;", "five base Tool calls")
	Do $$$AssertTrue($Find(types, "ProposalCreated;StateChanged;") > $Find(types, "ToolCalled;"), "Tool calls before the Proposal, then the state change")
	; versions and metrics
	Do $$$AssertEquals(p.versions.policy, "pol-2026.10.1", "policy version from the Evidence")
	Do $$$AssertEquals(p.versions.mapping, "2026.10.1", "mapping version from the Evidence")
	Do $$$AssertEquals(p.versions.model, "scripted-1", "model")
	Do $$$AssertEquals(p.metrics.toolCalls, 5, "toolCalls")
	Do $$$AssertEquals(p.metrics.tokensIn, 120, "tokens")
	Set inv = ##class(SignalNoir.Application.Model.InvestigationRecord).%OpenId(cmd)
	Do $$$AssertEquals(inv.status, "proposed", "investigation proposed")
	Do $$$AssertEquals(inv.mode, "rules", "mode")
	Do $$$AssertEquals(inv.provider, "scripted", "provider")
	Do $$$AssertEquals(inv.promptVersion, "script-v1", "prompt version")
	Do $$$AssertTrue(inv.durationMs '= "", "duration")
	Do $$$AssertEquals(inv.toolCalls, 5, "tool calls")
	Do $$$AssertEquals(##class(SignalNoir.Application.Model.OutboxRecord).%OpenId(cmd).status, "done", "request done")
	Do $ClassMethod(S, "ClearScript", caseId)
}

Method TestP8bKeepsTheChosenMapping()
{
	Set S = "SignalNoir.Tests.Support"
	Set svc = ##class(SignalNoir.Application.CaseService).Default()
	Set caseId = $ClassMethod(S, "InvestigatingCase", svc, "p8b", "agent", .cmd, "soro")
	Do $ClassMethod(S, "Script", caseId, "answer", $ClassMethod(S, "P8bAnswer"))
	Set r = $ClassMethod(S, "Investigate", cmd)
	Do $$$AssertEquals(r.details.status, "proposed", "proposed: " _ r.details.reason)
	Set p = svc.GetCase(caseId).obj.proposals.GetAt(1)
	Do $$$AssertEquals(p.action, "APPLY_APPROVED_MAPPING", "mapping Action")
	Do $$$AssertEquals(p.params.mappingId, "map_glicj_soro", "mappingId")
	Do $$$AssertEquals(p.params.mappingVersion, "2026.10.1", "mappingVersion")
	Do $$$AssertEquals(p.confidence, "HIGH", "confidence")
	Do $ClassMethod(S, "ClearScript", caseId)
}

Method TestProposalIsImmutableAndSuperseded()
{
	Set S = "SignalNoir.Tests.Support"
	Set svc = ##class(SignalNoir.Application.CaseService).Default()
	Set caseId = $ClassMethod(S, "InvestigatingCase", svc, "immut", "rules", .cmd)
	Do $ClassMethod(S, "Script", caseId, "answer", $ClassMethod(S, "P5Answer"))
	Do $ClassMethod(S, "Investigate", cmd)
	Set first = svc.GetCase(caseId).obj.currentProposalId
	Set pr = ##class(SignalNoir.Application.Model.ProposalRecord).%OpenId(first)
	Set pr.action = "RETRY"
	Set sc = pr.%Save()
	Do $$$AssertEquals($$$ISERR(sc), 1, "content change refused")
	Kill pr
	Do $$$AssertEquals(##class(SignalNoir.Application.Model.ProposalRecord).%OpenId(first).action, "REQUEST_REVIEW", "content unchanged")
	; a new Investigation (new Exception -> Investigating) supersedes it
	Set c = svc.GetCase(caseId).obj
	Do svc.RecordException(c.orderId, ##class(SignalNoir.Tests.Support).Exception("timeout"))
	Set rs = ##class(%SQL.Statement).%ExecDirect(, "SELECT commandId FROM SignalNoir_Application_Model.OutboxRecord WHERE caseId = ? AND type = 'Investigate' AND status = 'pending'", caseId)
	Do $$$AssertTrue(rs.%Next(), "a new investigation request")
	Set r = $ClassMethod(S, "Investigate", rs.%Get("commandId"))
	Do $$$AssertEquals(r.details.status, "proposed", "second Proposal")
	Set c = svc.GetCase(caseId).obj
	Do $$$AssertEquals(c.proposals.Count(), 2, "two Proposals")
	Do $$$AssertEquals(c.proposals.GetAt(1).current, 0, "first not current")
	Do $$$AssertEquals(c.proposals.GetAt(1).supersededBy, c.currentProposalId, "superseded by the second")
	Do $$$AssertEquals(c.proposals.GetAt(2).current, 1, "second current")
	Do $ClassMethod(S, "ClearScript", caseId)
}

Method TestStaleAndDuplicateRequestsDiscarded()
{
	Set S = "SignalNoir.Tests.Support"
	Set svc = ##class(SignalNoir.Application.CaseService).Default()
	Set caseId = $ClassMethod(S, "InvestigatingCase", svc, "stale", "rules", .cmd)
	; the Case moves before the request runs
	Do svc.MarkReviewRequired(caseId, 2, "system", "moved by test")
	Set r = $ClassMethod(S, "Investigate", cmd)
	Do $$$AssertEquals(r.details.status, "discarded", "stale request discarded")
	Do $$$AssertEquals(##class(SignalNoir.Application.Model.InvestigationRecord).%ExistsId(cmd), 0, "no Investigation")
	Do $$$AssertTrue($ClassMethod(S, "Types", svc, caseId) [ "CommandDiscarded", "discard recorded")
	; a duplicate delivery of a request that already ran
	Set caseId2 = $ClassMethod(S, "InvestigatingCase", svc, "dup", "rules", .cmd2)
	Do $ClassMethod(S, "Script", caseId2, "answer", $ClassMethod(S, "P5Answer"))
	Do $ClassMethod(S, "Investigate", cmd2)
	Set again = $ClassMethod(S, "Investigate", cmd2)
	Do $$$AssertEquals(again.details.status, "discarded", "duplicate discarded")
	Do $$$AssertEquals(+^SignalNoir.TestScript(caseId2, "proposed"), 1, "proposer ran once")
	Do $ClassMethod(S, "ClearScript", caseId2)
}

Method TestInvalidAnswersEndInReview()
{
	Set S = "SignalNoir.Tests.Support"
	Set svc = ##class(SignalNoir.Application.CaseService).Default()
	For bad = "{""diagnosis"":{""summary"":""s"",""claims"":[{""text"":""t"",""evidenceIds"":[""@ev:system.exception""]}],""hypotheses"":[]},""action"":""DELETE_ORDER"",""params"":{},""confidence"":""HIGH"",""preconditions"":[]}", "{""diagnosis"":{""summary"":""s"",""claims"":[{""text"":""t"",""evidenceIds"":[""evid_999999""]}],""hypotheses"":[]},""action"":""RETRY"",""params"":{},""confidence"":""HIGH"",""preconditions"":[]}" {
		Set caseId = $ClassMethod(S, "InvestigatingCase", svc, "bad", "rules", .cmd)
		Do $ClassMethod(S, "Script", caseId, "answer", bad)
		Set r = $ClassMethod(S, "Investigate", cmd)
		Set c = svc.GetCase(caseId).obj
		Do $$$AssertEquals(c.state, "ReviewRequired", "review")
		Do $$$AssertEquals(c.reviewReason, "invalid proposer response", "reason")
		Do $$$AssertEquals(c.proposals.Count(), 0, "no Proposal")
		Do $ClassMethod(S, "ClearScript", caseId)
	}
}

}
