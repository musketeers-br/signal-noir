Class SignalNoir.Tests.Application.TestRevalidation Extends %UnitTest.TestCase
{

/// 008 T015 (US2) - nothing is sent on stale context
Parameter S = "SignalNoir.Tests.Support";

Method TestDegradedPartnerHolds()
{
	Set partner = ##class(SignalNoir.Tests.Fakes.ScriptedPartner).%New()
	Set partner.HealthStatus = "DEGRADED"
	Set c = ..Run(partner, "reval-degraded")
	Do $$$AssertEquals(c.state, "Held", "Held")
	Do $$$AssertEquals(partner.Calls.deliver, 0, "nothing sent")
	Set check = c.executions.%Get(0).revalidation.checks.%Get(0)
	Do $$$AssertEquals(check.check _ ":" _ check.passed _ ":" _ check.observed, "PARTNER_HEALTHY_WINDOW:0:DEGRADED", "the failed check and what was observed")
	Do $$$AssertEquals(c.executions.%Get(0).revalidation.resultingState, "Held", "recorded with its destination")
	Do $$$AssertEquals(c.executions.%Get(0).outcome, "held", "outcome held")
}

Method TestMaintenanceHolds()
{
	Set partner = ##class(SignalNoir.Tests.Fakes.ScriptedPartner).%New()
	Set partner.Maintenance = 1
	Set c = ..Run(partner, "reval-maint")
	Do $$$AssertEquals(c.state _ ":" _ partner.Calls.deliver, "Held:0", "announced maintenance holds")
}

Method TestCancelledAtOrigin()
{
	Set partner = ##class(SignalNoir.Tests.Fakes.ScriptedPartner).%New()
	Set partner.OriginStatusValue = "cancelled"
	Set c = ..Run(partner, "reval-cancel")
	Do $$$AssertEquals(c.state, "Cancelled", "Cancelled")
	Do $$$AssertEquals(partner.Calls.deliver, 0, "nothing sent")
	Do $$$AssertEquals(c.executions.%Get(0).outcome, "cancelled", "outcome cancelled")
	Set rec = ##class(SignalNoir.Application.Model.CaseRecord).%OpenId(c.caseId)
	Do $$$AssertEquals(rec.openOrderId, "", "terminal: the Order may open a new Case")
}

Method TestExpiredApprovalChangesNothing()
{
	Set svc = ##class(SignalNoir.Application.CaseService).Default()
	Set caseId = $ClassMethod(..#S, "ApprovedCase", svc, "reval-expired")
	Set approvalId = svc.GetCase(caseId).obj.currentApprovalId
	; the path reads its clock one hour after the approval
	Set clock = ##class(SignalNoir.Tests.Fakes.FixedClock).%New()
	Set clock.Value = ##class(SignalNoir.Core.ApprovalPolicy).Plus(svc.ApprovalJson(approvalId).at, 3600)
	Set late = ##class(SignalNoir.Application.CaseService).Default()
	Set late.Clock = clock
	Set partner = ##class(SignalNoir.Tests.Fakes.ScriptedPartner).%New()
	Set r = $ClassMethod(..#S, "DeliverLast", $ClassMethod(..#S, "ExecBus", $ClassMethod(..#S, "Executor", partner, late)), caseId)
	Do $$$AssertEquals(r.details.status, "refused", "refused: " _ r.message)
	Set c = svc.GetCase(caseId).obj
	Do $$$AssertEquals(c.state, "Approved", "no state change")
	Do $$$AssertEquals(svc.ApprovalJson(approvalId).status, "valid", "the sweeper, not the path, expires it")
	Do $$$AssertEquals(partner.Calls.deliver, 0, "nothing sent")
	Do $$$AssertEquals(c.executions.%Size(), 0, "no execution")
	Do $$$AssertTrue($ClassMethod(..#S, "Types", svc, caseId) [ "RevalidationPerformed", "the check is on the Timeline")
}

Method TestVersionChangeHolds()
{
	Set partner = ##class(SignalNoir.Tests.Fakes.ScriptedPartner).%New()
	Set svc = ##class(SignalNoir.Application.CaseService).Default()
	Set caseId = $ClassMethod(..#S, "ApprovedCase", svc, "reval-version")
	Set exec = $ClassMethod(..#S, "Executor", partner)
	Set exec.Policy = ##class(SignalNoir.Tests.Fakes.VersionedPolicy).%New()
	Do $ClassMethod(..#S, "DeliverLast", $ClassMethod(..#S, "ExecBus", exec), caseId)
	Set c = svc.GetCase(caseId).obj
	Do $$$AssertEquals(c.state _ ":" _ partner.Calls.deliver, "Held:0", "a policy changed since the Proposal")
	Do $$$AssertTrue(c.executions.%Get(0).revalidation.checks.%ToJSON() [ "POLICY_VERSION_UNCHANGED", "the version check")
}

Method TestUnreadableHealthHolds()
{
	Set partner = ##class(SignalNoir.Tests.Fakes.ScriptedPartner).%New()
	Set partner.HealthStatus = ""
	Set c = ..Run(partner, "reval-unreadable")
	Do $$$AssertEquals(c.state _ ":" _ partner.Calls.deliver, "Held:0", "unreadable counts as not satisfied")
	Do $$$AssertEquals(c.executions.%Get(0).revalidation.checks.%Get(0).observed, "unreadable", "and says so")
}

Method TestMappingUnavailableHolds()
{
	Set partner = ##class(SignalNoir.Tests.Fakes.ScriptedPartner).%New()
	Set c = ..Run(partner, "reval-mapping", "APPLY_APPROVED_MAPPING")
	Do $$$AssertEquals(c.state _ ":" _ partner.Calls.deliver, "Held:0", "no mapping catalog, no send")
	Do $$$AssertTrue(##class(SignalNoir.Application.Model.ExecutionRecord).%OpenId(c.executions.%Get(0).executionId).failureReason [ "mapping unavailable", "the reason")
}

Method TestConcurrentChangeLosesTheCas()
{
	Set svc = ##class(SignalNoir.Application.CaseService).Default()
	Set caseId = $ClassMethod(..#S, "ApprovedCase", svc, "reval-race")
	Set cmd = ##class(SignalNoir.Tests.Application.TestCommandBus).Last(caseId, "Execute")
	; a writer moves the Case after the request was written (the sweeper expires the approval)
	Set c = svc.GetCase(caseId).obj
	Do svc.ExpireApproval(c.currentApprovalId, ##class(SignalNoir.Core.ApprovalPolicy).Plus(svc.ApprovalJson(c.currentApprovalId).expiresAt, 1))
	Set partner = ##class(SignalNoir.Tests.Fakes.ScriptedPartner).%New()
	Set r = $ClassMethod(..#S, "Executor", partner).Execute(cmd)
	Do $$$AssertEquals(r.details.status, "discarded", "the authorization loses: " _ r.message)
	Do $$$AssertEquals(partner.Calls.deliver, 0, "nothing sent")
	Do $$$AssertEquals(svc.GetCase(caseId).obj.state, "PendingApproval", "the newer state stands")
}

Method Run(partner As SignalNoir.Tests.Fakes.ScriptedPartner, tag As %String, action As %String = "RETRY") As SignalNoir.Core.Dto.Case [ Private ]
{
	Set svc = ##class(SignalNoir.Application.CaseService).Default()
	Set caseId = $ClassMethod(..#S, "ApprovedCase", svc, tag, action)
	If action = "APPLY_APPROVED_MAPPING" {
		Set pr = ##class(SignalNoir.Application.Model.ProposalRecord).%OpenId(svc.GetCase(caseId).obj.currentProposalId)
		Set pr.paramsJson = {"mappingId": "map-glic", "mappingVersion": "v1"}.%ToJSON()
		Do pr.%Save()
	}
	Do $ClassMethod(..#S, "DeliverLast", $ClassMethod(..#S, "ExecBus", $ClassMethod(..#S, "Executor", partner)), caseId)
	Return svc.GetCase(caseId).obj
}

}
