Class SignalNoir.Tests.Application.TestResolution Extends %UnitTest.TestCase
{

/// 009 T010, T012 - operator resolution through the same Validator
/// A Case in ReviewRequired with the Evidence of an investigation; examCode, when given, is
/// the one exam of its Order
ClassMethod ReviewCase(svc, tag, examCode As %String = "") As %String
{
	Set caseId = ##class(SignalNoir.Tests.Support).OpenCase(svc, ##class(SignalNoir.Tests.Support).Uid(tag), "", examCode)
	Do ##class(SignalNoir.Tests.Support).SeedEvidence(caseId)
	Do svc.MarkReviewRequired(caseId, 1, "system", "moved by test")
	Return caseId
}

ClassMethod Outbox(caseId, type) As %Integer
{
	Return ##class(SignalNoir.Tests.Support).Count("SELECT COUNT(*) FROM SignalNoir_Application_Model.OutboxRecord WHERE caseId = ? AND type = '" _ type _ "'", caseId)
}

Method TestAcceptedMappingIsApprovedByTheSameOperator()
{
	Set svc = ##class(SignalNoir.Application.CaseService).Default()
	Set caseId = ..ReviewCase(svc, "res-ok", "GLIC-J")
	Set v = svc.GetCase(caseId).obj.caseVersion
	Set r = svc.ResolveReview(caseId, {"kind": "action", "operator": "Carla", "expectedCaseVersion": (v), "action": "APPLY_APPROVED_MAPPING", "params": {"mappingId": "map_glicj_soro", "mappingVersion": "2026.10.1"}, "note": "phone"})
	Do $$$AssertTrue(r.ok, "accepted: " _ r.message)
	Set c = svc.GetCase(caseId).obj
	Do $$$AssertEquals(c.state, "Approved", "Approved")
	Do $$$AssertEquals(c.caseVersion, v + 3, "three transitions")
	Set p = c.proposals.GetAt(c.proposals.Count())
	Do $$$AssertEquals(p.origin, "operator:Carla", "operator is the author")
	Do $$$AssertEquals(c.currentProposalId, p.proposalId, "current")
	Do $$$AssertEquals(p.params.mappingId, "map_glicj_soro", "params")
	Do $$$AssertEquals(c.approvals.%Size(), 1, "one Approval")
	Set a = c.approvals.%Get(0)
	Do $$$AssertEquals(a.by, "operator:Carla", "approved by the same operator")
	Do $$$AssertEquals(a.proposalId, p.proposalId, "binds the exact Proposal")
	Do $$$AssertEquals(a.decision, "approved", "approved")
	Do $$$AssertTrue(a.expiresAt ] a.at, "has a deadline")
	Do $$$AssertEquals(..Outbox(caseId, "Execute"), 1, "execution work pending")
	Set types = ##class(SignalNoir.Tests.Support).Types(svc, caseId)
	For t = "ValidatorVerdict", "ProposalCreated", "ApprovalRecorded", "OperatorResolution" Do $$$AssertTrue(types [ t, t _ " recorded")
	Do $$$AssertEquals(r.obj.kind, "action", "result kind")
	Do $$$AssertEquals(r.obj.state, "Approved", "ack state")
}

/// The Operator's note becomes operator.note Evidence that the Proposal
/// cites, even when the Dossier lists no Evidence
Method TestNoteIsRecordedAsEvidenceWithoutDossierEvidence()
{
	Set svc = ##class(SignalNoir.Application.CaseService).Default()
	Set caseId = ..ReviewCase(svc, "res-note")
	Set c = svc.GetCase(caseId).obj
	Set listed = c.dossier.relevantEvidenceIds.%Size()
	Set before = c.evidence.Count()
	Set r = svc.ResolveReview(caseId, {"kind": "action", "operator": "Carla", "expectedCaseVersion": (c.caseVersion), "action": "RETRY", "note": "partner confirmed by phone"})
	Do $$$AssertTrue(r.ok, "accepted: " _ r.message)
	Set c = svc.GetCase(caseId).obj
	Do $$$AssertEquals(c.evidence.Count(), before + 1, "one new Evidence")
	Set ev = c.evidence.GetAt(c.evidence.Count())
	Do $$$AssertEquals(ev.source, "operator.note", "source")
	Do $$$AssertEquals(ev.calledBy, "operator:Carla", "by the Operator")
	Do $$$AssertEquals(ev.result.text, "partner confirmed by phone", "the note, by value")
	Set p = c.proposals.GetAt(c.proposals.Count())
	Do $$$AssertEquals(p.diagnosis.claims.%Size(), 1, "one claim")
	Set cited = p.diagnosis.claims.%Get(0).evidenceIds
	Do $$$AssertEquals(cited.%Size(), listed + 1, "the claim cites what the Dossier lists, plus the note")
	Do $$$AssertEquals(cited.%Get(cited.%Size() - 1), ev.evidenceId, "the claim cites the note")
}

Method TestBlockedResolutionRecordsNoNote()
{
	Set svc = ##class(SignalNoir.Application.CaseService).Default()
	Set fake = ##class(SignalNoir.Tests.Fakes.FakeValidator).%New()
	Set fake.Verdict = "blocked"
	Set svc.Validator = fake
	Set caseId = ..ReviewCase(svc, "res-note-blk")
	Set c = svc.GetCase(caseId).obj
	Set before = c.evidence.Count()
	Set r = svc.ResolveReview(caseId, {"kind": "action", "operator": "Carla", "expectedCaseVersion": (c.caseVersion), "action": "RETRY", "note": "try again"})
	Do $$$AssertNotTrue(r.ok, "blocked")
	Do $$$AssertEquals(svc.GetCase(caseId).obj.evidence.Count(), before, "only the verdict is recorded")
}

Method TestHoldGoesToExecutingWithoutApproval()
{
	Set svc = ##class(SignalNoir.Application.CaseService).Default()
	Set caseId = ..ReviewCase(svc, "res-hold")
	Set r = svc.ResolveReview(caseId, {"kind": "action", "operator": "Carla", "expectedCaseVersion": 2, "action": "HOLD", "params": {"reason": "maintenance"}})
	Do $$$AssertTrue(r.ok, "accepted")
	Set c = svc.GetCase(caseId).obj
	Do $$$AssertEquals(c.state, "Executing", "Executing")
	Do $$$AssertEquals(c.approvals.%Size(), 0, "no Approval for HOLD")
	Do $$$AssertEquals(..Outbox(caseId, "Execute"), 1, "execution work pending")
}

Method TestValidatorBlockedRecordsOnlyTheVerdict()
{
	Set svc = ##class(SignalNoir.Application.CaseService).Default()
	Set fake = ##class(SignalNoir.Tests.Fakes.FakeValidator).%New()
	Set fake.Verdict = "blocked"
	Set fake.Reasons = $ListBuild("MAPPING_CONDITION_MISMATCH")
	Set svc.Validator = fake
	Set caseId = ..ReviewCase(svc, "res-block")
	Set before = svc.GetCase(caseId).obj
	Set r = svc.ResolveReview(caseId, {"kind": "action", "operator": "Carla", "expectedCaseVersion": 2, "action": "APPLY_APPROVED_MAPPING", "params": {"mappingId": "map_glicj_plasma", "mappingVersion": "2026.10.1"}})
	Do $$$AssertEquals(r.ok, 0, "refused")
	Do $$$AssertEquals(r.code, "VALIDATION_FAILED", "code")
	Do $$$AssertEquals(r.details.verdict.verdict, "blocked", "blocked")
	Do $$$AssertEquals(r.details.verdict.reasons.%Get(0), "MAPPING_CONDITION_MISMATCH", "reason codes named")
	Do $$$AssertEquals(r.details.caseVersion, before.caseVersion, "current version in details")
	Set after = svc.GetCase(caseId).obj
	Do $$$AssertEquals(after.state, "ReviewRequired", "still in review")
	Do $$$AssertEquals(after.caseVersion, before.caseVersion, "same version")
	Do $$$AssertEquals(after.currentProposalId, before.currentProposalId, "no current Proposal")
	Do $$$AssertEquals(after.proposals.Count(), before.proposals.Count(), "no Proposal")
	Do $$$AssertEquals(after.approvals.%Size(), 0, "no Approval")
	Do $$$AssertEquals(..Outbox(caseId, "Execute"), 0, "nothing executed")
	Do $$$AssertEquals(after.lastEventSeq, before.lastEventSeq + 1, "only the verdict appended")
	Set ev = svc.GetTimeline(caseId, before.lastEventSeq).list.GetAt(1)
	Do $$$AssertEquals(ev.type, "ValidatorVerdict", "the verdict")
	Do $$$AssertEquals(ev.actor, "operator:Carla", "for the operator's choice")
}

Method TestConflictsAndShapeRecordNothing()
{
	Set svc = ##class(SignalNoir.Application.CaseService).Default()
	Set caseId = ..ReviewCase(svc, "res-conf")
	Set before = svc.GetCase(caseId).obj
	Set r = svc.ResolveReview(caseId, {"kind": "action", "operator": "Carla", "expectedCaseVersion": 1, "action": "RETRY"})
	Do $$$AssertEquals(r.code, "STALE_VERSION", "stale version")
	Set r = svc.ResolveReview(caseId, {"kind": "action", "operator": "Carla", "expectedCaseVersion": 2, "action": "RETRY", "payload": {"exams": []}})
	Do $$$AssertEquals(r.code, "VALIDATION_FAILED", "free payload refused")
	Do $$$AssertEquals(r.details.reasons.%Get(0), "unknown_field:payload", "named")
	Set r = svc.ResolveReview(caseId, {"kind": "action", "operator": "op:x", "expectedCaseVersion": 2, "action": "RETRY"})
	Do $$$AssertEquals(r.code, "VALIDATION_FAILED", "operator name")
	Set after = svc.GetCase(caseId).obj
	Do $$$AssertEquals(after.lastEventSeq, before.lastEventSeq, "nothing recorded")
	Set open = ##class(SignalNoir.Tests.Support).OpenCase(svc, ##class(SignalNoir.Tests.Support).Uid("res-open"))
	Set r = svc.ResolveReview(open, {"kind": "cancel", "operator": "Carla", "expectedCaseVersion": 1, "reason": "x"})
	Do $$$AssertEquals(r.code, "INVALID_TRANSITION", "not in review")
	Do $$$AssertEquals(svc.ResolveReview("case_nope", {"kind": "cancel", "operator": "Carla", "expectedCaseVersion": 1, "reason": "x"}).code, "NOT_FOUND", "unknown case")
}

Method TestCancel()
{
	Set svc = ##class(SignalNoir.Application.CaseService).Default()
	Set caseId = ..ReviewCase(svc, "res-cancel")
	Set r = svc.ResolveReview(caseId, {"kind": "cancel", "operator": "Carla", "expectedCaseVersion": 2, "reason": " "})
	Do $$$AssertEquals(r.code, "VALIDATION_FAILED", "reason required")
	Do $$$AssertEquals(svc.GetCase(caseId).obj.state, "ReviewRequired", "unchanged")
	Set r = svc.ResolveReview(caseId, {"kind": "cancel", "operator": "Carla", "expectedCaseVersion": 2, "reason": "duplicate confirmed with the unit"})
	Do $$$AssertTrue(r.ok, "cancelled")
	Set c = svc.GetCase(caseId).obj
	Do $$$AssertEquals(c.state, "Cancelled", "Cancelled")
	Do $$$AssertEquals(..Outbox(caseId, "Execute"), 0, "no execution")
	Set tl = svc.GetTimeline(caseId, 0, 500).list
	Set found = 0
	For i = 1 : 1 : tl.Count() {
		Set e = tl.GetAt(i)
		If (e.type = "OperatorResolution") && (e.payload.reason = "duplicate confirmed with the unit") && (e.actor = "operator:Carla") Set found = 1
	}
	Do $$$AssertEquals(found, 1, "operator and reason on the Timeline")
	Do $$$AssertEquals(r.obj.kind, "cancel", "result kind")
}

}
