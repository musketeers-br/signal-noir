Class SignalNoir.Core.ProposalShape Extends %RegisteredObject
{

/// Converts a proposer's answer (data) into the immutable Proposal DTO, the
/// same way for every origin (spec 006 FR-012, FR-014). Pure: no I/O.
/// Refuses an answer that is not a structured Proposal: Action outside the
/// catalog, missing or unknown parameters, unknown confidence or
/// precondition, claims without Evidence or citing Evidence not on the Case,
/// discarded hypotheses without a reason. Result.obj = Proposal; on refusal
/// code invalid_response and details.reasons.
ClassMethod Convert(answer, evidenceIds As %ListOfDataTypes, author As %String, versions As %DynamicObject, metrics As %DynamicObject) As SignalNoir.Core.Result
{
	Set reasons = []
	If '$IsObject(answer) || 'answer.%IsA("%DynamicObject") {
		Do reasons.%Push("answer:not_an_object")
		Return ..Refuse(reasons)
	}
	; diagnosis
	Set diagnosis = answer.%Get("diagnosis")
	If '..IsObj(diagnosis) {
		Do reasons.%Push("diagnosis:missing")
		Set diagnosis = {}
	}
	If ..Text(diagnosis.%Get("summary")) = "" Do reasons.%Push("diagnosis.summary:missing")
	Set claims = diagnosis.%Get("claims")
	If '..IsArr(claims) || (claims.%Size() = 0) {
		Do reasons.%Push("diagnosis.claims:missing")
		Set claims = []
	}
	Set cleanClaims = []
	For i = 0 : 1 : claims.%Size() - 1 {
		Set claim = claims.%Get(i)
		If '..IsObj(claim) || (..Text(claim.%Get("text")) = "") {
			Do reasons.%Push("diagnosis.claims[" _ i _ "].text:missing")
			Continue
		}
		Set ids = claim.%Get("evidenceIds")
		If '..IsArr(ids) || (ids.%Size() = 0) {
			Do reasons.%Push("diagnosis.claims[" _ i _ "].evidenceIds:missing")
			Continue
		}
		Set keep = []
		For j = 0 : 1 : ids.%Size() - 1 {
			Set id = ids.%Get(j)
			If $IsObject(id) || (evidenceIds.Find(id) = "") {
				Do reasons.%Push("diagnosis.claims[" _ i _ "].evidenceIds:unknown:" _ $Select($IsObject(id): "?", 1: id))
			} Else {
				Do keep.%Push(id)
			}
		}
		Do cleanClaims.%Push({"text": (claim.%Get("text")), "evidenceIds": (keep)})
	}
	Set hypotheses = diagnosis.%Get("hypotheses")
	If '..IsArr(hypotheses) Set hypotheses = []
	Set cleanHyp = []
	For i = 0 : 1 : hypotheses.%Size() - 1 {
		Set h = hypotheses.%Get(i)
		If '..IsObj(h) || (..Text(h.%Get("text")) = "") {
			Do reasons.%Push("diagnosis.hypotheses[" _ i _ "].text:missing")
			Continue
		}
		Set status = h.%Get("status")
		If (status '= "chosen") && (status '= "discarded") {
			Do reasons.%Push("diagnosis.hypotheses[" _ i _ "].status:invalid")
			Continue
		}
		If (status = "discarded") && (..Text(h.%Get("reason")) = "") Do reasons.%Push("diagnosis.hypotheses[" _ i _ "].reason:missing")
		Set item = {"text": (h.%Get("text")), "status": (status)}
		If ..Text(h.%Get("reason")) '= "" Do item.%Set("reason", h.%Get("reason"))
		Set hids = h.%Get("evidenceIds")
		If ..IsArr(hids) {
			Set keep = []
			For j = 0 : 1 : hids.%Size() - 1 {
				Set id = hids.%Get(j)
				If $IsObject(id) || (evidenceIds.Find(id) = "") {
					Do reasons.%Push("diagnosis.hypotheses[" _ i _ "].evidenceIds:unknown:" _ $Select($IsObject(id): "?", 1: id))
				} Else {
					Do keep.%Push(id)
				}
			}
			Do item.%Set("evidenceIds", keep)
		}
		Do cleanHyp.%Push(item)
	}
	Set conflicts = diagnosis.%Get("conflicts")
	Set cleanConf = []
	If ..IsArr(conflicts) {
		For i = 0 : 1 : conflicts.%Size() - 1 {
			Set c = conflicts.%Get(i)
			If '..IsObj(c) || '..IsArr(c.%Get("evidenceIds")) || (c.%Get("evidenceIds").%Size() < 2) || (..Text(c.%Get("description")) = "") {
				Do reasons.%Push("diagnosis.conflicts[" _ i _ "]:invalid")
				Continue
			}
			Do cleanConf.%Push({"evidenceIds": (c.%Get("evidenceIds")), "description": (c.%Get("description"))})
		}
	}
	; action and parameters
	Set action = answer.%Get("action")
	If $IsObject(action) || '##class(SignalNoir.Core.Vocab).IsAction(action) Do reasons.%Push("action:not_in_catalog:" _ $Select($IsObject(action): "?", 1: action))
	Set params = answer.%Get("params")
	If params = "" Set params = {}
	If '..IsObj(params) {
		Do reasons.%Push("params:not_an_object")
		Set params = {}
	}
	Set cleanParams = {}
	Set it = params.%GetIterator()
	While it.%GetNext(.key, .val) {
		If $ListFind($ListBuild("mappingId", "mappingVersion", "reason"), key) = 0 {
			Do reasons.%Push("params." _ key _ ":unknown")
			Continue
		}
		If $IsObject(val) {
			Do reasons.%Push("params." _ key _ ":not_text")
			Continue
		}
		Do cleanParams.%Set(key, val)
	}
	If action = "APPLY_APPROVED_MAPPING" {
		If ..Text(cleanParams.%Get("mappingId")) = "" Do reasons.%Push("params.mappingId:missing")
		If ..Text(cleanParams.%Get("mappingVersion")) = "" Do reasons.%Push("params.mappingVersion:missing")
	}
	; confidence and preconditions
	Set confidence = answer.%Get("confidence")
	If $ListFind($ListBuild("HIGH", "MEDIUM", "LOW"), confidence) = 0 Do reasons.%Push("confidence:invalid")
	Set pre = answer.%Get("preconditions")
	If pre = "" Set pre = []
	Set cleanPre = []
	If '..IsArr(pre) {
		Do reasons.%Push("preconditions:not_an_array")
	} Else {
		For i = 0 : 1 : pre.%Size() - 1 {
			Set p = pre.%Get(i)
			Set check = $Select(..IsObj(p): p.%Get("check"), 1: "")
			If $IsObject(check) || ($ListFind(##class(SignalNoir.Core.Vocab).Preconditions(), check) = 0) {
				Do reasons.%Push("preconditions[" _ i _ "].check:unknown")
				Continue
			}
			If 'p.%IsDefined("expected") {
				Do reasons.%Push("preconditions[" _ i _ "].expected:missing")
				Continue
			}
			Do cleanPre.%Push({"check": (check), "expected": (p.%Get("expected"))})
		}
	}
	; scope is always single_case in v1
	Set scope = answer.%Get("scope")
	If (scope '= "") && (scope '= "single_case") Do reasons.%Push("scope:invalid")
	Set prior = answer.%Get("priorReceiptCandidate")
	If (prior '= "") && ('..IsObj(prior) || (..Text(prior.%Get("receiptId")) = "") || (..Text(prior.%Get("orderId")) = "")) Do reasons.%Push("priorReceiptCandidate:invalid")
	If reasons.%Size() > 0 Return ..Refuse(reasons)
	Set proposal = ##class(SignalNoir.Core.Dto.Proposal).%New()
	Set proposal.origin = author
	Set proposal.diagnosis = {"summary": (diagnosis.%Get("summary")), "claims": (cleanClaims), "hypotheses": (cleanHyp), "conflicts": (cleanConf)}
	Set proposal.action = action
	Set proposal.params = cleanParams
	Set proposal.scope = "single_case"
	Set proposal.confidence = confidence
	Set proposal.preconditions = cleanPre
	Set proposal.versions = $Select($IsObject(versions): versions, 1: {})
	Set proposal.metrics = $Select($IsObject(metrics): metrics, 1: {})
	If ..IsObj(prior) Set proposal.priorReceiptCandidate = {"receiptId": (prior.%Get("receiptId")), "orderId": (prior.%Get("orderId"))}
	Return ##class(SignalNoir.Core.Result).OkObj(proposal)
}

/// Parses a model's text answer: one JSON object, optionally inside a
/// Markdown code fence. Returns "" when the text is not one JSON object.
ClassMethod ParseText(text As %String) As %DynamicObject
{
	Set t = ##class(SignalNoir.Core.Canon).Trim($Translate($Get(text), $Char(13, 10), "  "))
	If $Extract(t, 1, 3) = "```" {
		If $Extract(t, *-2, *) '= "```" Return ""
		Set open = $Find(t, "{")
		If open = 0 Return ""
		Set t = ##class(SignalNoir.Core.Canon).Trim($Extract(t, open - 1, *-3))
	}
	If ($Extract(t) '= "{") || ($Extract(t, *) '= "}") Return ""
	Set obj = ""
	Try {
		Set obj = ##class(%DynamicAbstractObject).%FromJSON(t)
	}
	Catch {
		Set obj = ""
	}
	If '$IsObject(obj) || 'obj.%IsA("%DynamicObject") Return ""
	Return obj
}

ClassMethod Refuse(reasons As %DynamicArray) As SignalNoir.Core.Result [ Private ]
{
	Return ##class(SignalNoir.Core.Result).ErrorWith("invalid_response", "invalid proposer response", {"reasons": (reasons)})
}

ClassMethod IsObj(value) As %Boolean [ Private ]
{
	Return ($IsObject(value) && value.%IsA("%DynamicObject"))
}

ClassMethod IsArr(value) As %Boolean [ Private ]
{
	Return ($IsObject(value) && value.%IsA("%DynamicArray"))
}

ClassMethod Text(value) As %String [ Private ]
{
	If $IsObject(value) Return ""
	Return ##class(SignalNoir.Core.Canon).Trim($Get(value))
}

}
