Class SignalNoir.Tests.Core.TestDossierBuilder Extends %UnitTest.TestCase
{

/// 009 T004 - the Dossier is built only from the Case's records
ClassMethod Ev(id, source, kind = "fact", result = "") As SignalNoir.Core.Dto.Evidence
{
	Set ev = ##class(SignalNoir.Core.Dto.Evidence).%New()
	Set ev.evidenceId = id, ev.source = source, ev.kind = kind
	Set ev.result = $Select($IsObject(result): result, kind = "absence": {"available": false, "reason": "simulator unreachable"}, 1: {"status": "UP"})
	Return ev
}

ClassMethod List(evs...) As %ListOfObjects
{
	Set l = ##class(%ListOfObjects).%New()
	For i = 1 : 1 : $Get(evs) Do l.Insert(evs(i))
	Return l
}

ClassMethod Order() As %DynamicObject
{
	Return {"orderId": "ORD-1", "patient": {"patientId": "SYN-PAT-0107", "name": "Ana Souza", "birthDate": "1980-01-02"}, "exams": [{"code": "GLIC-J"}], "specimen": {"specimenId": "SP-1", "collectedAt": "2026-10-23T10:00:00Z", "type": "SERUM"}}
}

/// Every evidence id mentioned anywhere in the dossier JSON
ClassMethod CitedIds(d As %DynamicObject) As %List
{
	Set json = d.%ToJSON(), out = ""
	Set p = 0
	For {
		Set p = $Find(json, """evid_", p)
		Quit:p=0
		Set id = "evid_" _ $Piece($Extract(json, p, p + 80), """", 1)
		If '$ListFind(out, id) Set out = out _ $ListBuild(id)
	}
	Return out
}

Method TestReasonMapping()
{
	Set R = "SignalNoir.Core.DossierReason"
	For pair = "provider unavailable: AI Hub is not available>provider_unavailable", "invalid proposer response>invalid_agent_response", "investigation budget exceeded: time>budget_exceeded", "investigation interrupted>investigation_interrupted", "second rejection>second_denial", "validator blocked: X>validator_blocked", "review requested: business error>review_requested", "moved by test>review_requested" {
		Do $$$AssertEquals($ClassMethod(R, "From", $Piece(pair, ">", 1)), $Piece(pair, ">", 2), $Piece(pair, ">", 1))
	}
	Do $$$AssertTrue($ClassMethod(R, "Text", "provider_unavailable", "provider unavailable: X") [ "provider unavailable: X", "text quotes the recorded reason")
	Do $$$AssertTrue($ClassMethod(R, "NextStep", "budget_exceeded") '= "", "next step")
}

Method TestProviderUnavailableBeforeAnyProposal()
{
	Set evs = ..List(..Ev("evid_1", "system.exception"), ..Ev("evid_2", "tool.partner_health"), ..Ev("evid_3", "tool.mapping_catalog", "absence"))
	Set d = ##class(SignalNoir.Core.DossierBuilder).Build("provider unavailable: AI Hub is not available on this instance", evs, "", ..Order(), "2026-10-25T10:00:00Z")
	Do $$$AssertEquals(d.reason, "provider_unavailable", "reason")
	Do $$$AssertTrue(d.reasonText [ "AI Hub is not available", "explains why")
	Do $$$AssertEquals(d.%GetTypeOf("partialDiagnosis"), "null", "no partial diagnosis")
	Do $$$AssertEquals(d.relevantEvidenceIds.%ToJSON(), "[""evid_1"",""evid_2"",""evid_3""]", "the evidence collected so far")
	Set text = d.unknowns.%ToJSON()
	Do $$$AssertTrue(text [ "no interpretation", "no diagnosis is an unknown")
	Do $$$AssertTrue(text [ "tool.mapping_catalog", "absence is an unknown, naming the source")
	Do $$$AssertTrue(d.suggestedNextStep '= "", "next step")
	For f = "reason", "reasonText", "createdAt", "suggestedNextStep", "hypotheses", "conflicts", "collidingRecords", "unconfirmedCandidates", "unknowns" Do $$$AssertTrue(d.%IsDefined(f), "has " _ f)
}

Method TestWithProposalAndNothingInvented()
{
	Set evs = ..List(..Ev("evid_1", "system.exception"), ..Ev("evid_2", "tool.partner_health"))
	Set p = ##class(SignalNoir.Core.Dto.Proposal).%New()
	Set p.diagnosis = {"summary": "s", "claims": [{"text": "c", "evidenceIds": ["evid_1", "evid_404"]}], "hypotheses": [{"text": "outage", "status": "discarded", "reason": "health UP", "evidenceIds": ["evid_2"]}], "conflicts": [{"evidenceIds": ["evid_1", "evid_2"], "description": "500 but UP"}, {"evidenceIds": ["evid_1", "evid_999"], "description": "ghost"}]}
	Set d = ##class(SignalNoir.Core.DossierBuilder).Build("invalid proposer response", evs, p, ..Order(), "2026-10-25T10:00:00Z")
	Do $$$AssertEquals(d.partialDiagnosis.summary, "s", "partial diagnosis")
	Do $$$AssertEquals(d.hypotheses.%Get(0).reason, "health UP", "discard reason kept")
	Do $$$AssertEquals(d.conflicts.%Size(), 1, "only conflicts between recorded Evidence")
	Set cited = ..CitedIds(d)
	For i = 1 : 1 : $ListLength(cited) Do $$$AssertTrue($ListFind($ListBuild("evid_1", "evid_2"), $ListGet(cited, i)), "cited id exists: " _ $ListGet(cited, i))
}

Method TestNoEvidenceAtAll()
{
	Set d = ##class(SignalNoir.Core.DossierBuilder).Build("investigation interrupted", ..List(), "", ..Order(), "2026-10-25T10:00:00Z")
	Do $$$AssertEquals(d.reason, "investigation_interrupted", "reason")
	Do $$$AssertEquals(d.relevantEvidenceIds.%Size(), 0, "no ids")
	Do $$$AssertTrue(d.unknowns.%ToJSON() [ "No evidence was collected", "says so")
}

Method TestIdentityCollision()
{
	Set receipts = {"items": [
		{"receiptId": "rcp_1", "orderId": "ORD-0", "orderSnapshot": {"patient": {"patientId": "SYN-PAT-0107", "name": "Ana Souza", "birthDate": "1980-01-02"}}},
		{"receiptId": "rcp_2", "orderId": "ORD-9", "orderSnapshot": {"patient": {"patientId": "SYN-PAT-0311", "name": "ana souza", "birthDate": "1981-03-04"}}}
	]}
	Set evs = ..List(..Ev("evid_1", "system.exception"), ..Ev("evid_7", "tool.receipts_and_orders_by_patient", "fact", receipts))
	Set d = ##class(SignalNoir.Core.DossierBuilder).Build("review requested: ambiguous identity", evs, "", ..Order(), "2026-10-25T10:00:00Z")
	Do $$$AssertEquals(d.reason, "ambiguous_identity", "a generic review over colliding records is an identity case")
	Do $$$AssertEquals(d.collidingRecords.%Size(), 2, "two colliding records")
	Set r = d.collidingRecords.%Get(1)
	Do $$$AssertEquals(r.recordRef, "SYN-PAT-0311", "record ref")
	Do $$$AssertEquals(r.source, "evid_7", "from the recorded Evidence")
	Do $$$AssertTrue(r.divergentFields.%ToJSON() [ "patientId", "patientId diverges")
	Do $$$AssertTrue(r.divergentFields.%ToJSON() [ "birthDate", "birthDate diverges")
	Do $$$AssertTrue('(r.divergentFields.%ToJSON() [ "name"), "name matches (normalized)")
	Do $$$AssertTrue(d.unknowns.%ToJSON() [ "which of the records", "identity is an unknown")
	; a specific cause is kept even when records collide
	Do $$$AssertEquals(##class(SignalNoir.Core.DossierBuilder).Build("provider unavailable: x", evs, "", ..Order(), "2026-10-25T10:00:00Z").reason, "provider_unavailable", "specific cause kept")
	; the same rule decides for the Rules proposer
	Do $$$AssertEquals(##class(SignalNoir.Core.Identity).Collisions(evs, ..Order()).%Size(), 2, "one identity rule in the core")
}

Method TestUnconfirmedPriorReceipt()
{
	Set receipts = {"items": [{"receiptId": "rcp_9", "orderId": "ORD-8", "orderSnapshot": {"patient": {"patientId": "SYN-PAT-0107"}, "exams": [{"code": "GLIC-J"}], "specimen": {"specimenId": "SP-2", "collectedAt": "2026-10-23T09:00:00Z"}}}]}
	Set evs = ..List(..Ev("evid_7", "tool.receipts_and_orders_by_patient", "fact", receipts))
	Set p = ##class(SignalNoir.Core.Dto.Proposal).%New()
	Set p.diagnosis = {"summary": "s", "claims": [], "hypotheses": []}
	Set p.priorReceiptCandidate = {"receiptId": "rcp_9", "orderId": "ORD-8"}
	Set d = ##class(SignalNoir.Core.DossierBuilder).Build("moved by test", evs, p, ..Order(), "2026-10-25T10:00:00Z")
	Do $$$AssertEquals(d.unconfirmedCandidates.%Size(), 1, "candidate listed")
	Do $$$AssertEquals(d.unconfirmedCandidates.%Get(0).mismatchedFields.%ToJSON(), "[""collectedAt"",""specimenId""]", "mismatched equivalence fields")
	Set p.priorReceiptCandidate = {"receiptId": "rcp_missing", "orderId": "ORD-7"}
	Set d = ##class(SignalNoir.Core.DossierBuilder).Build("moved by test", evs, p, ..Order(), "2026-10-25T10:00:00Z")
	Do $$$AssertEquals(d.unconfirmedCandidates.%Size(), 0, "not invented")
	Do $$$AssertTrue(d.unknowns.%ToJSON() [ "rcp_missing", "missing candidate is an unknown")
}

Method TestNothingFlagged()
{
	Set evs = ..List(..Ev("evid_1", "system.exception"))
	Set p = ##class(SignalNoir.Core.Dto.Proposal).%New()
	Set p.diagnosis = {"summary": "s", "claims": [{"text": "c", "evidenceIds": ["evid_1"]}], "hypotheses": []}
	Set d = ##class(SignalNoir.Core.DossierBuilder).Build("second rejection", evs, p, ..Order(), "2026-10-25T10:00:00Z")
	Do $$$AssertEquals(d.unknowns.%Size(), 0, "empty unknowns: nothing flagged")
}

}
