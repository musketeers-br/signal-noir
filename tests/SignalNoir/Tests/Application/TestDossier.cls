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

/// 009 US1 #3 end to end: recorded patient records collide; the Rules
/// proposer asks for review, the Validator routes the Case to review, and the
/// Dossier lists the colliding records with their divergent fields
Method TestAmbiguousIdentityEndToEnd()
{
	Set S = "SignalNoir.Tests.Support"
	Set svc = ##class(SignalNoir.Application.CaseService).Default()
	Set caseId = $ClassMethod(S, "InvestigatingCase", svc, "dos-ident", "rules", .cmd, "SERUM")
	Set order = ##class(SignalNoir.Application.Model.OrderRecord).%OpenId(##class(SignalNoir.Application.Model.CaseRecord).%OpenId(caseId).orderId)
	Set patient = {}.%FromJSON(order.snapshotJson).patient
	Set other = {"patientId": "SYN-PAT-0311", "name": (patient.name), "birthDate": "1981-03-04"}
	Set ^SignalNoir.TestScript(caseId, "source", "tool.receipts_and_orders_by_patient") = {"items": [{"receiptId": "rcp_7", "orderId": "ORD-OTHER", "orderSnapshot": {"patient": (other)}}]}.%ToJSON()
	Set r = $ClassMethod(S, "Investigate", cmd, "SignalNoir.Proposers.Rules")
	Set c = svc.GetCase(caseId).obj
	Do $$$AssertEquals(c.proposals.GetAt(1).action, "REQUEST_REVIEW", "Rules asks for review on ambiguous identity")
	Do $$$AssertEquals(c.state, "ReviewRequired", "routed to review")
	Do $$$AssertEquals(c.dossier.reason, "ambiguous_identity", "identity reason")
	Do $$$AssertEquals(c.dossier.collidingRecords.%Size(), 2, "the order's record and the other record")
	Set found = 0
	For i = 0 : 1 : c.dossier.collidingRecords.%Size() - 1 {
		Set rec = c.dossier.collidingRecords.%Get(i)
		If rec.recordRef = "SYN-PAT-0311" Set found = (rec.divergentFields.%ToJSON() [ "patientId") && (rec.divergentFields.%ToJSON() [ "birthDate")
	}
	Do $$$AssertTrue(found, "divergent fields marked")
	Do ..AssertNothingInvented($this, svc, caseId)
	Do $ClassMethod(S, "ClearScript", caseId)
}

/// 009 US1 #4 end to end: a Proposal points to a prior Receipt whose
/// equivalence key does not match; the review Dossier lists it with the
/// mismatched fields
Method TestUnconfirmedPriorReceiptEndToEnd()
{
	Set S = "SignalNoir.Tests.Support"
	Set svc = ##class(SignalNoir.Application.CaseService).Default()
	Set caseId = $ClassMethod(S, "InvestigatingCase", svc, "dos-prior", "agent", .cmd, "SERUM")
	Set order = {}.%FromJSON(##class(SignalNoir.Application.Model.OrderRecord).%OpenId(##class(SignalNoir.Application.Model.CaseRecord).%OpenId(caseId).orderId).snapshotJson)
	Set prior = order.%FromJSON(order.%ToJSON())
	Set prior.specimen.specimenId = "SP-OTHER"
	Set ^SignalNoir.TestScript(caseId, "source", "tool.receipts_and_orders_by_patient") = {"items": [{"receiptId": "rcp_9", "orderId": "ORD-PRIOR", "orderSnapshot": (prior)}]}.%ToJSON()
	Do $ClassMethod(S, "Script", caseId, "answer", "{""diagnosis"":{""summary"":""A prior receipt may cover this order"",""claims"":[{""text"":""A receipt exists for the same patient"",""evidenceIds"":[""@ev:tool.receipts_and_orders_by_patient""]}],""hypotheses"":[]},""action"":""REQUEST_REVIEW"",""params"":{""reason"":""prior receipt unconfirmed""},""confidence"":""LOW"",""preconditions"":[],""priorReceiptCandidate"":{""receiptId"":""rcp_9"",""orderId"":""ORD-PRIOR""}}")
	Do $ClassMethod(S, "Investigate", cmd)
	Set c = svc.GetCase(caseId).obj
	Do $$$AssertEquals(c.state, "ReviewRequired", "routed to review")
	Do $$$AssertEquals(c.dossier.unconfirmedCandidates.%Size(), 1, "candidate listed")
	Do $$$AssertEquals(c.dossier.unconfirmedCandidates.%Get(0).mismatchedFields.%ToJSON(), "[""specimenId""]", "mismatched field")
	Do $ClassMethod(S, "ClearScript", caseId)
}

/// 009: a Proposal the Validator blocks ends in review with the reason
/// codes, and the Dossier says validator_blocked
Method TestValidatorBlockedRoutesToReview()
{
	Set S = "SignalNoir.Tests.Support"
	Set svc = ##class(SignalNoir.Application.CaseService).Default()
	Set fake = ##class(SignalNoir.Tests.Fakes.FakeValidator).%New()
	Set fake.Verdict = "invalid"
	Set fake.FailedPreconditions = $ListBuild("MAPPING_CONDITION_MISMATCH")
	Set svc.Validator = fake
	Set caseId = $ClassMethod(S, "InvestigatingCase", svc, "dos-block", "agent", .cmd, "SERUM")
	Set started = svc.StartInvestigation(cmd, "SignalNoir.Tests.Fakes.ScriptedProposer", "SignalNoir.Tests.Fakes.ScriptedSource")
	Set ids = ##class(%ListOfDataTypes).%New()
	Do ids.Insert(started.details.evidenceIds.%Get(0))
	Set answer = {}.%FromJSON($Replace($ClassMethod(S, "P8bAnswer"), """@ev:tool.mapping_catalog""", """" _ ids.GetAt(1) _ """"))
	Set answer = {}.%FromJSON($Replace(answer.%ToJSON(), """@ev:system.exception""", """" _ ids.GetAt(1) _ """"))
	Set p = ##class(SignalNoir.Core.ProposalShape).Convert(answer, ids, "agent", {"policy": "p", "mapping": "m"}, {}).obj
	Set r = svc.CompleteInvestigation(cmd, p)
	Do $$$AssertTrue(r.ok, "proposal recorded: " _ r.message)
	Set c = svc.GetCase(caseId).obj
	Do $$$AssertEquals(c.state, "ReviewRequired", "blocked -> review")
	Do $$$AssertTrue(c.reviewReason [ "MAPPING_CONDITION_MISMATCH", "reason names the codes: " _ c.reviewReason)
	Do $$$AssertEquals(c.dossier.reason, "validator_blocked", "Dossier reason")
}

}
