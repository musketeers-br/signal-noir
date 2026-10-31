Class SignalNoir.Application.ResolutionValidator Extends %RegisteredObject
{

/// The one place a Proposal reaches the Validator (feature 009; 006's
/// routing joins at G2). InputFor gathers everything the Validator needs from
/// the Case; Verdict calls the injected port (seam v2) and returns the
/// contract ValidatorVerdict with the reference-data versions (004).
ClassMethod InputFor(rec As SignalNoir.Application.Model.CaseRecord, proposal As SignalNoir.Core.Dto.Proposal, now As %String) As SignalNoir.Core.Dto.ValidationInput
{
	Set input = ##class(SignalNoir.Core.Dto.ValidationInput).%New()
	; a Proposal gets its caseId when it is recorded; the Validator tells this Case's Evidence
	; from another Case's by it, so a Proposal still unrecorded takes the Case it is validated for
	If proposal.caseId = "" Set proposal.caseId = rec.caseId
	Set input.proposal = proposal
	Set input.now = now
	Set evidence = ##class(SignalNoir.Application.CaseService).%New().ListEvidence(rec.caseId)
	For i = 1 : 1 : evidence.Count() Do input.evidence.Insert(evidence.GetAt(i))
	Set input.priorReceiptOrder = ..PriorReceiptOrder(evidence, proposal)
	Set orderRec = ##class(SignalNoir.Application.Model.OrderRecord).%OpenId(rec.orderId)
	Set input.order = $Select($IsObject(orderRec) && (orderRec.snapshotJson '= ""): {}.%FromJSON(orderRec.snapshotJson), 1: {})
	; 008 records Attempts; until then the count is 0
	Set input.attemptCount = 0
	Set run = ..RunFor(rec)
	Set input.run = run
	Set snapshot = ##class(SignalNoir.Application.Reference.Store).For(run)
	If snapshot.ok Set input.reference = snapshot.obj
	Return input
}

/// The Order snapshot of the prior Receipt the Proposal names, as the Case's own Evidence
/// (tool.receipts_and_orders_by_patient) recorded it; "" when the Proposal names none or the
/// Evidence does not hold it. The Validator compares its canonical key with the Order's.
ClassMethod PriorReceiptOrder(evidence As %ListOfObjects, proposal As SignalNoir.Core.Dto.Proposal) As %DynamicObject [ Private ]
{
	Set candidate = proposal.priorReceiptCandidate
	If '$IsObject(candidate) || (candidate.%GetTypeOf("receiptId") '= "string") || (candidate.receiptId = "") Return ""
	For i = 1 : 1 : evidence.Count() {
		Set ev = evidence.GetAt(i)
		If (ev.source '= "tool.receipts_and_orders_by_patient") || (ev.kind '= "fact") || '$IsObject(ev.result) || 'ev.result.%IsA("%Library.DynamicObject") Continue
		If ev.result.%GetTypeOf("items") '= "array" Continue
		Set each = ev.result.items.%GetIterator()
		While each.%GetNext(.index, .item) {
			If $IsObject(item) && item.%IsA("%Library.DynamicObject") && (item.%Get("receiptId") = candidate.receiptId) && (item.%GetTypeOf("orderSnapshot") = "object") Return item.orderSnapshot
		}
	}
	Return ""
}

/// The run a Case belongs to, as the Store reads it. The reference data a Case is validated
/// against and the reference data its Tools serve are chosen from this one object. The versions
/// a BenchmarkRun pins are null until the run records them (007): the Store then falls back
/// to the versions in force.
ClassMethod RunFor(rec As SignalNoir.Application.Model.CaseRecord) As %DynamicObject
{
	Set run = {"policyVersion": null, "mappingVersion": null}
	Set runId = $Select($IsObject(rec): rec.runId, 1: "")
	Do run.%Set("inRun", runId '= "", "boolean")
	If runId = "" {
		Do run.%Set("runId", "", "null")
	} Else {
		Set run.runId = runId
	}
	Return run
}

ClassMethod Verdict(validator As SignalNoir.Core.Port.Validator, input As SignalNoir.Core.Dto.ValidationInput) As %DynamicObject
{
	Return validator.Validate(input).ToJson()
}

}
