Class SignalNoir.Tests.Application.TestDecision Extends %UnitTest.TestCase
{

/// 007 T006, T008, T010 - the Operator's decision on the exact Proposal
ClassMethod Rows(sql As %String, arg As %String) As %Integer
{
	Return ##class(SignalNoir.Tests.Support).Count(sql, arg)
}

ClassMethod Approvals(caseId As %String) As %Integer
{
	Return ..Rows("SELECT COUNT(*) FROM SignalNoir_Application_Model.ApprovalRecord WHERE caseId = ?", caseId)
}

ClassMethod Requests(caseId As %String, type As %String) As %Integer
{
	Return ..Rows("SELECT COUNT(*) FROM SignalNoir_Application_Model.OutboxRecord WHERE caseId = ? AND type = '" _ type _ "'", caseId)
}

Method TestApproveExactVersion()
{
	Set S = "SignalNoir.Tests.Support"
	Set svc = ##class(SignalNoir.Application.CaseService).Default()
	Set clock = ##class(SignalNoir.Tests.Fakes.FixedClock).%New()
	Set clock.Value = "2026-10-29T13:00:13Z"
	Set svc.Clock = clock
	Set caseId = $ClassMethod(S, "PendingCase", svc, "dec-ok")
	Set c = svc.GetCase(caseId).obj
	Set r = svc.DecideProposal(caseId, c.currentProposalId, {"decision": "approved", "operator": "Carla", "expectedCaseVersion": (c.caseVersion)})
	Do $$$AssertTrue(r.ok, "approved: " _ r.message)
	Do $$$AssertEquals(r.details.replay, 0, "not a replay")
	Do $$$AssertEquals(r.details.state, "Approved", "ack state")
	Do $$$AssertEquals(r.details.caseVersion, c.caseVersion + 1, "one transition")
	Do $$$AssertTrue(r.details.commandId [ "cmd_", "the execution request in the ack")
	; a fresh service reads it back (survives a restart: nothing lives in memory)
	Set after = ##class(SignalNoir.Application.CaseService).Default().GetCase(caseId).obj
	Do $$$AssertEquals(after.state, "Approved", "Approved")
	Do $$$AssertEquals(after.currentApprovalId, r.details.approvalId, "current approval")
	Set a = svc.ApprovalJson(r.details.approvalId)
	Do $$$AssertEquals(a.proposalId, c.currentProposalId, "binds the exact Proposal")
	Do $$$AssertEquals(a.by, "operator:Carla", "by the Operator")
	Do $$$AssertEquals(a.at, "2026-10-29T13:00:13Z", "at")
	Do $$$AssertEquals(a.expiresAt, "2026-10-29T13:15:13Z", "15-minute deadline")
	Do $$$AssertEquals(a.status, "valid", "valid")
	Do $$$AssertEquals(a.%GetTypeOf("reason"), "null", "no reason")
	Do $$$AssertEquals(..Requests(caseId, "Execute"), 1, "one execution request")
	Set types = $ClassMethod(S, "Types", svc, caseId)
	Do $$$AssertTrue(types [ "ApprovalRecorded;StateChanged;", "approval then the transition")
	Set tl = svc.GetTimeline(caseId, c.lastEventSeq).list
	Do $$$AssertEquals(tl.GetAt(tl.Count()).payload.approvalId, r.details.approvalId, "StateChanged names the approval")
}

Method TestConflictsRecordNothing()
{
	Set S = "SignalNoir.Tests.Support"
	Set svc = ##class(SignalNoir.Application.CaseService).Default()
	Set caseId = $ClassMethod(S, "PendingCase", svc, "dec-409")
	Set c = svc.GetCase(caseId).obj
	; stale version
	Set r = svc.DecideProposal(caseId, c.currentProposalId, {"decision": "approved", "operator": "Carla", "expectedCaseVersion": (c.caseVersion - 1)})
	Do $$$AssertEquals(r.code, "STALE_VERSION", "stale version")
	Do $$$AssertEquals(r.details.currentProposalId, c.currentProposalId, "names the current Proposal")
	Do $$$AssertEquals(r.details.caseId, caseId, "names the Case")
	; a Proposal that is no longer current
	Set old = c.currentProposalId
	Set newer = $ClassMethod(S, "FixtureProposal", caseId)
	Set r = svc.DecideProposal(caseId, old, {"decision": "approved", "operator": "Carla", "expectedCaseVersion": (c.caseVersion)})
	Do $$$AssertEquals(r.code, "STALE_VERSION", "superseded Proposal refused")
	Do $$$AssertEquals(r.details.currentProposalId, newer, "the current one is named")
	; wrong state
	Set other = $ClassMethod(S, "OpenCase", svc, $ClassMethod(S, "Uid", "dec-state"))
	Do $$$AssertEquals(svc.DecideProposal(other, "prop_x", {"decision": "approved", "operator": "Carla", "expectedCaseVersion": 1}).code, "INVALID_TRANSITION", "not waiting for approval")
	; malformed and unknown
	Do $$$AssertEquals(svc.DecideProposal(caseId, newer, {"decision": "yes", "operator": "Carla", "expectedCaseVersion": (c.caseVersion)}).code, "VALIDATION_FAILED", "shape")
	Do $$$AssertEquals(svc.DecideProposal("case_nope", newer, {"decision": "approved", "operator": "Carla", "expectedCaseVersion": 1}).code, "NOT_FOUND", "unknown Case")
	; none of the refusals recorded anything
	Do $$$AssertEquals(..Approvals(caseId), 0, "no approval")
	Do $$$AssertEquals(..Requests(caseId, "Execute"), 0, "no request")
	Do $$$AssertEquals(svc.GetCase(caseId).obj.caseVersion, c.caseVersion, "version unchanged")
}

Method TestReplay()
{
	Set S = "SignalNoir.Tests.Support"
	Set svc = ##class(SignalNoir.Application.CaseService).Default()
	Set caseId = $ClassMethod(S, "PendingCase", svc, "dec-replay")
	Set c = svc.GetCase(caseId).obj
	Set first = svc.DecideProposal(caseId, c.currentProposalId, {"decision": "approved", "operator": "Carla", "expectedCaseVersion": (c.caseVersion)})
	Do $$$AssertTrue(first.ok, "first approval")
	; again, with the version the Operator saw (now stale), and by someone else
	For who = "Carla", "Bruno" {
		Set r = svc.DecideProposal(caseId, c.currentProposalId, {"decision": "approved", "operator": (who), "expectedCaseVersion": (c.caseVersion)})
		Do $$$AssertTrue(r.ok, "replay for " _ who)
		Do $$$AssertEquals(r.details.replay, 1, "reported as replay")
		Do $$$AssertEquals(r.details.approvalId, first.details.approvalId, "the existing approval")
		Do $$$AssertEquals(r.details.commandId, "", "no new request")
	}
	; still a replay after the Case moved on
	Set g = svc.GetCase(caseId).obj
	Do $$$AssertTrue(svc.Transition(caseId, g.caseVersion, "Executing", "system", $ClassMethod(S, "Ev")).ok, "executing")
	Set r = svc.DecideProposal(caseId, c.currentProposalId, {"decision": "approved", "operator": "Carla", "expectedCaseVersion": (c.caseVersion)})
	Do $$$AssertEquals(r.details.replay _ ":" _ r.details.state, "1:Executing", "replay while executing")
	Do $$$AssertEquals(..Approvals(caseId), 1, "one approval")
	Do $$$AssertEquals(..Requests(caseId, "Execute"), 1, "one execution request")
}

Method TestConcurrentApprovals()
{
	Set S = "SignalNoir.Tests.Support"
	Set svc = ##class(SignalNoir.Application.CaseService).Default()
	Set caseId = $ClassMethod(S, "PendingCase", svc, "dec-race")
	Set c = svc.GetCase(caseId).obj
	Set key = $ClassMethod(S, "Uid", "race")
	Kill ^SignalNoir.TestBarrier(key)
	For who = "Carla", "Bruno", "Dora" {
		Job ##class(SignalNoir.Tests.Application.TestDecision).RaceApprove(key, caseId, c.currentProposalId, c.caseVersion, who)
	}
	Hang 0.3
	Set ^SignalNoir.TestBarrier(key) = 1
	Do $$$AssertEquals($ClassMethod(S, "WaitResults", key, 3), 3, "three answers")
	Set created = 0, replays = 0, j = ""
	For {
		Set j = $Order(^SignalNoir.TestRace(key, j), 1, v)
		Quit:j=""
		If v = "created" Set created = created + 1
		If v = "replay" Set replays = replays + 1
	}
	Do $$$AssertEquals(created _ "/" _ replays, "1/2", "one approval, two replays")
	Do $$$AssertEquals(..Approvals(caseId), 1, "exactly one approval")
	Do $$$AssertEquals(..Requests(caseId, "Execute"), 1, "exactly one execution request")
	Kill ^SignalNoir.TestBarrier(key)
}

/// JOB worker: approves after the barrier and records created, replay or the code
ClassMethod RaceApprove(key As %String, caseId As %String, proposalId As %String, version As %Integer, who As %String)
{
	For i = 1 : 1 : 500 {
		Quit:$Get(^SignalNoir.TestBarrier(key))
		Hang 0.01
	}
	Set r = ##class(SignalNoir.Application.CaseService).Default().DecideProposal(caseId, proposalId, {"decision": "approved", "operator": (who), "expectedCaseVersion": (version)})
	Set ^SignalNoir.TestRace(key, $JOB) = $Select('r.ok: r.code, r.details.replay: "replay", 1: "created")
}

Method TestDenialWithReason()
{
	Set S = "SignalNoir.Tests.Support"
	Set svc = ##class(SignalNoir.Application.CaseService).Default()
	Set caseId = $ClassMethod(S, "PendingCase", svc, "dec-deny")
	Set c = svc.GetCase(caseId).obj
	Set r = svc.DecideProposal(caseId, c.currentProposalId, {"decision": "denied", "operator": "Carla", "expectedCaseVersion": (c.caseVersion)})
	Do $$$AssertEquals(r.code, "VALIDATION_FAILED", "a denial needs a reason")
	Do $$$AssertTrue(r.message [ "requires a reason", "says why")
	Set r = svc.DecideProposal(caseId, c.currentProposalId, {"decision": "denied", "operator": "Carla", "expectedCaseVersion": (c.caseVersion), "reason": "plasma, not serum"})
	Do $$$AssertTrue(r.ok, "denied: " _ r.message)
	Set after = svc.GetCase(caseId).obj
	Do $$$AssertEquals(after.state, "Rejected", "Rejected")
	Do $$$AssertEquals(after.denialCount, 1, "first denial")
	Do $$$AssertEquals(after.currentApprovalId, "", "a denial authorizes nothing")
	Set a = svc.ApprovalJson(r.details.approvalId)
	Do $$$AssertEquals(a.decision _ ":" _ a.reason, "denied:plasma, not serum", "the denial and its reason")
	Do $$$AssertEquals(a.%GetTypeOf("expiresAt"), "null", "no deadline")
	; the reason is Evidence from the Operator
	Set ev = after.evidence.GetAt(after.evidence.Count())
	Do $$$AssertEquals(ev.source, "operator.denial_reason", "denial reason Evidence")
	Do $$$AssertEquals(ev.calledBy, "operator:Carla", "by the Operator")
	Do $$$AssertEquals(ev.result.text, "plasma, not serum", "the reason, by value")
	; follow-up: one Reassess request carrying the reason
	Set n = $ClassMethod(S, "Outbox", caseId, .rows)
	Do $$$AssertEquals($ListGet(rows(n), 2) _ ":" _ $ListGet(rows(n), 3), "Reassess:pending", "reassess requested")
	Do $$$AssertEquals({}.%FromJSON($ListGet(rows(n), 5)).rejectionReason, "plasma, not serum", "the reason travels")
	Do $$$AssertEquals(r.details.commandId, $ListGet(rows(n), 1), "the ack names it")
	; a denied Proposal is never replayed as an approval
	Do $$$AssertEquals(svc.DecideProposal(caseId, c.currentProposalId, {"decision": "approved", "operator": "Carla", "expectedCaseVersion": (after.caseVersion)}).code, "INVALID_TRANSITION", "Rejected is not waiting")
}

/// 007 FR-007: no path reaches Approved or Rejected without a recorded decision
Method TestNoApprovalWithoutDecision()
{
	Set S = "SignalNoir.Tests.Support"
	Set svc = ##class(SignalNoir.Application.CaseService).Default()
	Set caseId = $ClassMethod(S, "PendingCase", svc, "dec-guard")
	Set c = svc.GetCase(caseId).obj
	For to = "Approved", "Rejected" {
		Set r = svc.Transition(caseId, c.caseVersion, to, "operator:ana", $ClassMethod(S, "Ev", "raw"))
		Do $$$AssertEquals(r.code, "INVALID_TRANSITION", to _ " needs a decision")
	}
	; a decision on another Proposal does not count
	Set other = $ClassMethod(S, "PendingCase", svc, "dec-guard2")
	Set d = $ClassMethod(S, "Decide", svc, other)
	Set event = $ClassMethod(S, "Ev", "borrowed")
	Set event.payload = {"reason": "borrowed", "approvalId": (d.details.approvalId)}
	Do $$$AssertEquals(svc.Transition(caseId, c.caseVersion, "Approved", "operator:ana", event).code, "INVALID_TRANSITION", "another Case's approval")
	Do $$$AssertEquals(svc.GetCase(caseId).obj.state, "PendingApproval", "still waiting")
	Do $$$AssertEquals(..Approvals(caseId), 0, "nothing recorded")
}

/// 007 FR-015: if the authorization cannot be stored, nothing is
Method TestStorageFailureRecordsNothing()
{
	Set S = "SignalNoir.Tests.Support"
	Set svc = ##class(SignalNoir.Application.CaseService).Default()
	Set caseId = $ClassMethod(S, "PendingCase", svc, "dec-fail")
	Set c = svc.GetCase(caseId).obj
	Set svc.Ids = ##class(SignalNoir.Tests.Fakes.BrokenCmdIds).%New()
	Set r = svc.DecideProposal(caseId, c.currentProposalId, {"decision": "approved", "operator": "Carla", "expectedCaseVersion": (c.caseVersion)})
	Do $$$AssertNotTrue(r.ok, "refused")
	Set after = ##class(SignalNoir.Application.CaseService).Default().GetCase(caseId).obj
	Do $$$AssertEquals(after.state, "PendingApproval", "no state change")
	Do $$$AssertEquals(after.caseVersion, c.caseVersion, "no version change")
	Do $$$AssertEquals(..Approvals(caseId), 0, "no approval")
	Do $$$AssertEquals(..Requests(caseId, "Execute"), 0, "no request")
	Do $$$AssertNotTrue($ClassMethod(S, "Types", svc, caseId) [ "ApprovalRecorded", "no event")
}

}
