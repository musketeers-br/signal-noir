Class SignalNoir.Tests.Application.TestDossier Extends %UnitTest.TestCase
{

/// 009 T006 - every entry into ReviewRequired records a Dossier with it
ClassMethod Latest(svc, caseId) As %DynamicObject
{
	Return svc.GetCase(caseId).obj.dossier
}

ClassMethod AssertNothingInvented(test, svc, caseId)
{
	Set c = svc.GetCase(caseId).obj
	Set ids = ""
	For i = 1 : 1 : c.evidence.Count() Set ids = ids _ $ListBuild(c.evidence.GetAt(i).evidenceId)
	Set cited = ##class(SignalNoir.Tests.Core.TestDossierBuilder).CitedIds(c.dossier)
	For i = 1 : 1 : $ListLength(cited) Do test.AssertTrueViaMacro("$ListFind(ids, cited)", $ListFind(ids, $ListGet(cited, i)) > 0, "Dossier cites recorded Evidence only: " _ $ListGet(cited, i))
}

Method TestProviderUnavailableAtOpen()
{
	If ##class(SignalNoir.Proposers.AiHubRuntime).Configured() {
		Do $$$LogMessage("skipped: an AI provider is configured on this instance, so a new case is not routed to review at open")
		Return
	}
	; with no provider, a new agent-mode Case goes straight to ReviewRequired (001/006)
	Set svc = ##class(SignalNoir.Application.CaseService).Default()
	Set orderId = ##class(SignalNoir.Tests.Support).Uid("dos-prov")
	Do svc.AcceptOrder(##class(SignalNoir.Tests.Support).Order(orderId))
	Set r = svc.ProcessException(orderId, ##class(SignalNoir.Tests.Support).Exception())
	Set c = svc.GetCase(r.ref).obj
	Do $$$AssertEquals(c.state, "ReviewRequired", "review")
	Do $$$AssertEquals(c.dossier.reason, "provider_unavailable", "reason")
	Do $$$AssertTrue(c.dossier.reasonText [ "provider unavailable", "explains")
	Do $$$AssertEquals(c.dossier.%GetTypeOf("partialDiagnosis"), "null", "no diagnosis")
	Do $$$AssertTrue(##class(SignalNoir.Tests.Support).Types(svc, r.ref) [ "DossierCreated", "DossierCreated on the Timeline")
}

Method TestInvestigationFailuresKeepTheEvidence()
{
	Set S = "SignalNoir.Tests.Support"
	Set svc = ##class(SignalNoir.Application.CaseService).Default()
	; invalid response
	Set caseId = $ClassMethod(S, "InvestigatingCase", svc, "dos-inv", "rules", .cmd)
	Do $ClassMethod(S, "Script", caseId, "answer", "not json at all")
	Do $ClassMethod(S, "Investigate", cmd)
	Set d = ..Latest(svc, caseId)
	Do $$$AssertEquals(d.reason, "invalid_agent_response", "invalid response")
	Do $$$AssertTrue(d.relevantEvidenceIds.%Size() >= 6, "Evidence collected so far")
	Do ..AssertNothingInvented($this, svc, caseId)
	Do $ClassMethod(S, "ClearScript", caseId)
	; budget
	Set caseId = $ClassMethod(S, "InvestigatingCase", svc, "dos-bud", "rules", .cmd)
	Do $ClassMethod(S, "Script", caseId, "tools", "tool.order_timeline,tool.order_timeline")
	Do $ClassMethod(S, "Script", caseId, "answer", $ClassMethod(S, "P5Answer"))
	Do $ClassMethod(S, "Investigate", cmd)
	Set d = ..Latest(svc, caseId)
	Do $$$AssertEquals(d.reason, "budget_exceeded", "budget")
	Do $$$AssertEquals(d.relevantEvidenceIds.%Size(), 7, "exception + 6 Tool calls")
	Do $ClassMethod(S, "ClearScript", caseId)
	; interrupted
	Set caseId = $ClassMethod(S, "InvestigatingCase", svc, "dos-int", "rules", .cmd)
	Do svc.MarkDispatched(cmd)
	Do svc.RecoverInterrupted()
	Do $$$AssertEquals(..Latest(svc, caseId).reason, "investigation_interrupted", "interrupted")
}

Method TestSecondRejectionAndFreshDossier()
{
	Set S = "SignalNoir.Tests.Support"
	Set svc = ##class(SignalNoir.Application.CaseService).Default()
	Set caseId = $ClassMethod(S, "OpenCase", svc, $ClassMethod(S, "Uid", "dos-rej"))
	Do $$$AssertEquals($ClassMethod(S, "DriveTo", svc, caseId, "Rejected"), "", "first rejection")
	Do svc.ResolveRejection(caseId, svc.GetCase(caseId).obj.caseVersion, "no")
	For step = "DecisionProposed:agent", "PendingApproval:system", "Rejected:operator:ana" {
		Set g = svc.GetCase(caseId).obj
		Do svc.Transition(caseId, g.caseVersion, $Piece(step, ":", 1), $Piece(step, ":", 2, 3), $ClassMethod(S, "Ev"))
	}
	Do svc.ResolveRejection(caseId, svc.GetCase(caseId).obj.caseVersion, "still no")
	Set first = ..Latest(svc, caseId)
	Do $$$AssertEquals(first.reason, "second_denial", "second rejection")
	Do $$$AssertEquals(##class(SignalNoir.Tests.Support).Count("SELECT COUNT(*) FROM SignalNoir_Application_Model.DossierRecord WHERE caseId = ?", caseId), 1, "one Dossier")
}

Method TestDossierCommitsWithTheTransition()
{
	; a failed transition leaves no Dossier behind
	Set svc = ##class(SignalNoir.Application.CaseService).Default()
	Set caseId = ##class(SignalNoir.Tests.Support).OpenCase(svc, ##class(SignalNoir.Tests.Support).Uid("dos-atom"))
	Set stale = svc.Transition(caseId, 99, "ReviewRequired", "system", ##class(SignalNoir.Tests.Support).Ev("x"))
	Do $$$AssertEquals(stale.code, "STALE_VERSION", "refused")
	Do $$$AssertEquals(##class(SignalNoir.Tests.Support).Count("SELECT COUNT(*) FROM SignalNoir_Application_Model.DossierRecord WHERE caseId = ?", caseId), 0, "no Dossier without the transition")
	Do svc.MarkReviewRequired(caseId, 1, "system", "moved by test")
	Do $$$AssertEquals(..Latest(svc, caseId).reason, "review_requested", "Dossier with the transition")
}

}
