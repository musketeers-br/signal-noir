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
