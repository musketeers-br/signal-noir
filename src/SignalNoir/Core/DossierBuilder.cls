Class SignalNoir.Core.DossierBuilder Extends %RegisteredObject
{

/// Builds the contract Review Dossier from the Case's own records (spec 009
/// FR-003 to FR-005). Pure: it only cites the Evidence ids it is given and
/// turns every absence of information into a factual unknown; an empty
/// unknowns list means nothing was flagged, never that everything is known.
/// evidence: list of Core.Dto.Evidence; proposal: the current Proposal or "".
ClassMethod Build(reviewReason As %String, evidence As %ListOfObjects, proposal, order As %DynamicObject, now As %String) As %DynamicObject
{
	Set reason = ##class(SignalNoir.Core.DossierReason).From(reviewReason)
	Set d = {"reason": (reason), "reasonText": (##class(SignalNoir.Core.DossierReason).Text(reason, reviewReason)), "createdAt": (now)}
	Set ids = [], known = ""
	For i = 1 : 1 : evidence.Count() {
		Set ev = evidence.GetAt(i)
		Do ids.%Push(ev.evidenceId)
		Set known = known _ $ListBuild(ev.evidenceId)
	}
	Do d.%Set("relevantEvidenceIds", ids)
	Set unknowns = []
	If evidence.Count() = 0 Do unknowns.%Push({"topic": "other", "text": "No evidence was collected before automation stopped."})
	; partial diagnosis: only the recorded Proposal's, and only citing recorded Evidence
	Set diagnosis = ""
	If $IsObject(proposal) && $IsObject(proposal.diagnosis) Set diagnosis = ..Clean(proposal.diagnosis, known)
	If $IsObject(diagnosis) {
		Do d.%Set("partialDiagnosis", diagnosis)
		Do d.%Set("hypotheses", diagnosis.hypotheses)
		Do d.%Set("conflicts", diagnosis.conflicts)
	} Else {
		Do d.%Set("partialDiagnosis", "", "null")
		Do d.%Set("hypotheses", [])
		Do d.%Set("conflicts", [])
		Do unknowns.%Push({"topic": "diagnosis", "text": "No diagnosis: no interpretation of this evidence exists."})
	}
	; absence of information is a fact about the sources, not a conclusion
	For i = 1 : 1 : evidence.Count() {
		Set ev = evidence.GetAt(i)
		If ev.kind '= "absence" Continue
		Set why = $Select($IsObject(ev.result) && ev.result.%IsA("%DynamicObject"): ev.result.reason, 1: "")
		Do unknowns.%Push({"topic": (..Topic(ev.source)), "text": ("No information from " _ ev.source _ $Select(why '= "": ": " _ why, 1: "") _ "."), "relatedEvidenceIds": [(ev.evidenceId)]})
	}
	; identity collisions from recorded synthetic patient records
	Set colliding = ..Collisions(evidence, order)
	Do d.%Set("collidingRecords", colliding)
	If colliding.%Size() > 0 Do unknowns.%Push({"topic": "identity", "text": "No evidence says which of the records is the right patient."})
	; prior-receipt candidate that the validator did not confirm
	Set candidates = []
	If $IsObject(proposal) && $IsObject(proposal.priorReceiptCandidate) && (proposal.priorReceiptCandidate.receiptId '= "") {
		Set found = ..Candidate(evidence, proposal.priorReceiptCandidate, order)
		If $IsObject(found) {
			Do:found.mismatchedFields.%Size()>0 candidates.%Push(found)
		} Else {
			Do unknowns.%Push({"topic": "prior_receipt", "text": ("The candidate receipt " _ proposal.priorReceiptCandidate.receiptId _ " does not appear in the recorded evidence.")})
		}
	}
	Do d.%Set("unconfirmedCandidates", candidates)
	Do d.%Set("unknowns", unknowns)
	Do d.%Set("suggestedNextStep", ##class(SignalNoir.Core.DossierReason).NextStep(reason))
	Return d
}

/// The diagnosis with claims, hypotheses and conflicts restricted to
/// recorded Evidence (nothing cited that did not happen)
ClassMethod Clean(diagnosis As %DynamicObject, known As %List) As %DynamicObject [ Private ]
{
	Set claims = []
	Set src = diagnosis.claims
	If $IsObject(src) {
		For i = 0 : 1 : src.%Size() - 1 {
			Set c = src.%Get(i)
			Set keep = ..Keep(c.evidenceIds, known)
			If keep.%Size() > 0 Do claims.%Push({"text": (c.text), "evidenceIds": (keep)})
		}
	}
	Set hyps = []
	Set src = diagnosis.hypotheses
	If $IsObject(src) {
		For i = 0 : 1 : src.%Size() - 1 {
			Set h = src.%Get(i)
			Set item = {"text": (h.text), "status": (h.status)}
			If h.reason '= "" Do item.%Set("reason", h.reason)
			If $IsObject(h.evidenceIds) Do item.%Set("evidenceIds", ..Keep(h.evidenceIds, known))
			Do hyps.%Push(item)
		}
	}
	Set conflicts = []
	Set src = diagnosis.conflicts
	If $IsObject(src) {
		For i = 0 : 1 : src.%Size() - 1 {
			Set c = src.%Get(i)
			Set keep = ..Keep(c.evidenceIds, known)
			If keep.%Size() = c.evidenceIds.%Size() && (keep.%Size() >= 2) Do conflicts.%Push({"evidenceIds": (keep), "description": (c.description)})
		}
	}
	Return {"summary": (diagnosis.summary), "claims": (claims), "hypotheses": (hyps), "conflicts": (conflicts)}
}

ClassMethod Keep(ids, known As %List) As %DynamicArray [ Private ]
{
	Set out = []
	If '$IsObject(ids) Return out
	For i = 0 : 1 : ids.%Size() - 1 {
		If $ListFind(known, ids.%Get(i)) Do out.%Push(ids.%Get(i))
	}
	Return out
}

/// Patients in recorded receipts/orders evidence that share the Order's
/// patient name but differ in identity
ClassMethod Collisions(evidence As %ListOfObjects, order As %DynamicObject) As %DynamicArray [ Private ]
{
	Set out = []
	Set own = $Select($IsObject(order) && $IsObject(order.patient): order.patient, 1: "")
	If '$IsObject(own) || (own.name = "") Return out
	Set name = ..Norm(own.name)
	Kill seen
	Set records = []
	Do records.%Push({"patient": (own), "source": "order"})
	For i = 1 : 1 : evidence.Count() {
		Set ev = evidence.GetAt(i)
		If (ev.source '= "tool.receipts_and_orders_by_patient") || (ev.kind '= "fact") || '$IsObject(ev.result) || '$IsObject(ev.result.items) Continue
		For j = 0 : 1 : ev.result.items.%Size() - 1 {
			Set item = ev.result.items.%Get(j)
			Set snap = item.orderSnapshot
			If '$IsObject(snap) || '$IsObject(snap.patient) Continue
			Do records.%Push({"patient": (snap.patient), "source": (ev.evidenceId)})
		}
	}
	; one record per patientId with the same normalized name
	For i = 0 : 1 : records.%Size() - 1 {
		Set p = records.%Get(i).patient
		If (..Norm(p.name) '= name) || (p.patientId = "") Continue
		If $Data(seen(p.patientId)) Continue
		Set seen(p.patientId) = i
	}
	Set n = 0, k = ""
	For {
		Set k = $Order(seen(k))
		Quit:k=""
		Set n = n + 1
	}
	If n < 2 Return out
	Set k = ""
	For {
		Set k = $Order(seen(k), 1, i)
		Quit:k=""
		Set rec = records.%Get(i)
		Set p = rec.patient
		Set fields = {}, divergent = []
		For f = "patientId", "name", "birthDate", "sex" {
			Set v = p.%Get(f)
			If v '= "" Do fields.%Set(f, v)
			Set other = own.%Get(f)
			Set differs = $Select(f = "name": ..Norm(v) '= ..Norm(other), 1: v '= other)
			If differs && ((v '= "") || (other '= "")) Do divergent.%Push(f)
		}
		; the Order's own record is the reference: it lists what the others diverge on
		If rec.source = "order" {
			Set divergent = []
			Set j = ""
			For {
				Set j = $Order(seen(j), 1, idx)
				Quit:j=""
				If idx = i Continue
				Set q = records.%Get(idx).patient
				For f = "patientId", "name", "birthDate", "sex" {
					Set differs = $Select(f = "name": ..Norm(q.%Get(f)) '= ..Norm(p.%Get(f)), 1: q.%Get(f) '= p.%Get(f))
					If differs && '..Has(divergent, f) Do divergent.%Push(f)
				}
			}
		}
		Do out.%Push({"recordRef": (p.patientId), "source": (rec.source), "fields": (fields), "divergentFields": (divergent)})
	}
	Return out
}

/// The candidate receipt found in recorded Evidence, with the equivalence
/// fields that do not match the Order; "" when it is not in the Evidence
ClassMethod Candidate(evidence As %ListOfObjects, candidate As %DynamicObject, order As %DynamicObject) As %DynamicObject [ Private ]
{
	For i = 1 : 1 : evidence.Count() {
		Set ev = evidence.GetAt(i)
		If (ev.source '= "tool.receipts_and_orders_by_patient") || (ev.kind '= "fact") || '$IsObject(ev.result) || '$IsObject(ev.result.items) Continue
		For j = 0 : 1 : ev.result.items.%Size() - 1 {
			Set item = ev.result.items.%Get(j)
			If item.receiptId '= candidate.receiptId Continue
			Set mine = ##class(SignalNoir.Core.Canon).Parts(##class(SignalNoir.Core.Canon).FromSnapshot(order))
			Set theirs = ##class(SignalNoir.Core.Canon).Parts(##class(SignalNoir.Core.Canon).FromSnapshot(item.orderSnapshot))
			Set mismatched = []
			For f = "patientId", "examCodes", "collectedAt", "specimenId" {
				Set a = mine.%Get(f), b = theirs.%Get(f)
				If $IsObject(a) Set a = a.%ToJSON(), b = b.%ToJSON()
				If a '= b Do mismatched.%Push(f)
			}
			Return {"receiptId": (item.receiptId), "orderId": (item.orderId), "mismatchedFields": (mismatched)}
		}
	}
	Return ""
}

ClassMethod Topic(source As %String) As %String [ Private ]
{
	If source = "tool.receipts_and_orders_by_patient" Return "prior_receipt"
	If source = "tool.origin_order_status" Return "origin_status"
	If (source = "tool.policies") || (source = "tool.mapping_catalog") Return "policy"
	If (source = "tool.partner_health") || (source = "tool.partner_failure_history") Return "partner_acceptance"
	Return "other"
}

ClassMethod Norm(text) As %String [ Private ]
{
	Return $ZConvert(##class(SignalNoir.Core.Canon).Trim($Get(text)), "L")
}

ClassMethod Has(arr As %DynamicArray, value As %String) As %Boolean [ Private ]
{
	For i = 0 : 1 : arr.%Size() - 1 {
		If arr.%Get(i) = value Return 1
	}
	Return 0
}

}
