Class SignalNoir.Tests.Application.TestHeld Extends %UnitTest.TestCase
{

/// 008 T021 (US5) - Held is reassessed; leaving Held starts over
Parameter S = "SignalNoir.Tests.Support";

/// A Case held by a degraded Partner, with the Partner fake left degraded
ClassMethod HeldCase(svc As SignalNoir.Application.CaseService, tag As %String, partner As SignalNoir.Tests.Fakes.ScriptedPartner, exec As SignalNoir.Application.ExecutionService) As %String
{
	Set caseId = $ClassMethod(..#S, "ApprovedCase", svc, tag)
	Set partner.HealthStatus = "DEGRADED"
	Do $ClassMethod(..#S, "DeliverLast", $ClassMethod(..#S, "ExecBus", exec), caseId)
	Return caseId
}

Method TestReassessment()
{
	Set svc = ##class(SignalNoir.Application.CaseService).Default()
	Set partner = ##class(SignalNoir.Tests.Fakes.ScriptedPartner).%New()
	Set exec = $ClassMethod(..#S, "Executor", partner)
	Set caseId = ..HeldCase(svc, "held-reassess", partner, exec)
	Set c = svc.GetCase(caseId).obj
	Do $$$AssertEquals(c.state, "Held", "held")
	Set heldAt = ##class(SignalNoir.Application.Model.CaseRecord).%OpenId(caseId).updatedAt
	; before the minimum hold: untouched, even with a healthy Partner
	Set partner.HealthStatus = "UP"
	Set out = ##class(SignalNoir.Tasks.Sweeper).Run(##class(SignalNoir.Core.ApprovalPolicy).Plus(heldAt, 60), $ListBuild(caseId), 0, 30, "none", exec)
	Do $$$AssertEquals(out.reassessed _ ":" _ svc.GetCase(caseId).obj.state, "0:Held", "too early")
	; (that sweep also discarded the walk's stale Investigate request)
	Set events = $Length($ClassMethod(..#S, "Types", svc, caseId), ";")
	; after it, still degraded: untouched and quiet
	Set partner.HealthStatus = "DEGRADED"
	Set out = ##class(SignalNoir.Tasks.Sweeper).Run(##class(SignalNoir.Core.ApprovalPolicy).Plus(heldAt, 301), $ListBuild(caseId), 0, 30, "none", exec)
	Do $$$AssertEquals(out.reassessed _ ":" _ svc.GetCase(caseId).obj.state, "0:Held", "still degraded")
	Do $$$AssertEquals($Length($ClassMethod(..#S, "Types", svc, caseId), ";"), events, "no Timeline noise")
	; recovered
	Set partner.HealthStatus = "UP"
	Set out = ##class(SignalNoir.Tasks.Sweeper).Run(##class(SignalNoir.Core.ApprovalPolicy).Plus(heldAt, 301), $ListBuild(caseId), 0, 30, "none", exec)
	Do $$$AssertEquals(out.reassessed, 1, "reassessed")
	Set c = svc.GetCase(caseId).obj
	Do $$$AssertEquals(c.state, "Investigating", "back to investigation")
	Do $$$AssertTrue($ClassMethod(..#S, "Types", svc, caseId) [ "ReassessmentPerformed", "recorded")
	Do $$$AssertEquals(..LastActor(caseId), "sweeper", "by the sweeper")
	Do $$$AssertEquals(##class(SignalNoir.Tests.Application.TestCommandBus).Status(##class(SignalNoir.Tests.Application.TestCommandBus).Last(caseId, "Investigate")), "pending", "a new investigation is requested")
}

Method TestVersionHoldEndsWithoutHealthRead()
{
	Set svc = ##class(SignalNoir.Application.CaseService).Default()
	Set partner = ##class(SignalNoir.Tests.Fakes.ScriptedPartner).%New()
	Set exec = $ClassMethod(..#S, "Executor", partner)
	Set exec.Policy = ##class(SignalNoir.Tests.Fakes.VersionedPolicy).%New()
	Set caseId = $ClassMethod(..#S, "ApprovedCase", svc, "held-version")
	Do $ClassMethod(..#S, "DeliverLast", $ClassMethod(..#S, "ExecBus", exec), caseId)
	Do $$$AssertEquals(svc.GetCase(caseId).obj.state, "Held", "held on the version")
	Set partner.HealthStatus = ""
	Set heldAt = ##class(SignalNoir.Application.Model.CaseRecord).%OpenId(caseId).updatedAt
	Set out = ##class(SignalNoir.Tasks.Sweeper).Run(##class(SignalNoir.Core.ApprovalPolicy).Plus(heldAt, 301), $ListBuild(caseId), 0, 30, "none", exec)
	Do $$$AssertEquals(svc.GetCase(caseId).obj.state, "Investigating", "the new Proposal is the fix")
}

Method TestLeavingHeldNeedsANewApproval()
{
	Set svc = ##class(SignalNoir.Application.CaseService).Default()
	Set partner = ##class(SignalNoir.Tests.Fakes.ScriptedPartner).%New()
	Set exec = $ClassMethod(..#S, "Executor", partner)
	Set caseId = ..HeldCase(svc, "held-approval", partner, exec)
	Set old = svc.GetCase(caseId).obj
	Set oldApproval = old.approvals.%Get(0).approvalId, oldProposal = old.currentProposalId
	Do $$$AssertEquals(svc.ApprovalJson(oldApproval).status, "consumed", "the approval was spent on the held execution")
	Set partner.HealthStatus = "UP"
	Set heldAt = ##class(SignalNoir.Application.Model.CaseRecord).%OpenId(caseId).updatedAt
	Do ##class(SignalNoir.Tasks.Sweeper).Run(##class(SignalNoir.Core.ApprovalPolicy).Plus(heldAt, 301), $ListBuild(caseId), 0, 30, "none", exec)
	; a new Proposal waits for approval; the old approval cannot authorize it
	For step = "DecisionProposed:agent", "PendingApproval:system" Do $ClassMethod(..#S, "Step", svc, caseId, step)
	Set newProposal = $ClassMethod(..#S, "FixtureProposal", caseId)
	Set c = svc.GetCase(caseId).obj
	Do $$$AssertEquals(c.state, "PendingApproval", "waiting for a new approval")
	Do $$$AssertTrue(newProposal '= oldProposal, "on a new Proposal")
	Set r = svc.Transition(caseId, c.caseVersion, "Approved", "operator:ana", $ClassMethod(..#S, "Ev", "reuse"))
	Do $$$AssertNotTrue(r.ok, "no Approved without a decision on the new Proposal")
	Set r = svc.DecideProposal(caseId, oldProposal, {"decision": "approved", "operator": "ana", "expectedCaseVersion": (c.caseVersion)})
	Do $$$AssertTrue(r.ok && r.details.replay, "approving the old Proposal is only a replay")
	Do $$$AssertEquals(svc.GetCase(caseId).obj.state, "PendingApproval", "which authorizes nothing new")
}

ClassMethod LastActor(caseId As %String) As %String
{
	Set rs = ##class(%SQL.Statement).%ExecDirect(, "SELECT TOP 1 actor FROM SignalNoir_Application_Model.CaseEventRecord WHERE caseId = ? AND type = 'StateChanged' ORDER BY seq DESC", caseId)
	Return $Select(rs.%Next(): rs.%Get("actor"), 1: "")
}

}
