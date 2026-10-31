Class SignalNoir.Application.ResolutionValidator Extends %RegisteredObject
{

/// The one place a Proposal reaches the Validator (feature 009; 006's
/// routing joins at G2). InputFor gathers everything the Validator needs from
/// the Case; Verdict calls the injected port (seam v2) and returns the
/// contract ValidatorVerdict with the reference-data versions (004).
ClassMethod InputFor(rec As SignalNoir.Application.Model.CaseRecord, proposal As SignalNoir.Core.Dto.Proposal, now As %String) As SignalNoir.Core.Dto.ValidationInput
{
	Set input = ##class(SignalNoir.Core.Dto.ValidationInput).%New()
	Set input.proposal = proposal
	Set input.now = now
	Set evidence = ##class(SignalNoir.Application.CaseService).%New().ListEvidence(rec.caseId)
	For i = 1 : 1 : evidence.Count() Do input.evidence.Insert(evidence.GetAt(i))
	Set orderRec = ##class(SignalNoir.Application.Model.OrderRecord).%OpenId(rec.orderId)
	Set input.order = $Select($IsObject(orderRec) && (orderRec.snapshotJson '= ""): {}.%FromJSON(orderRec.snapshotJson), 1: {})
	; 008 records Attempts; until then the count is 0
	Set input.attemptCount = 0
	Set run = {"policyVersion": null, "mappingVersion": null}
	Do run.%Set("inRun", rec.runId '= "", "boolean")
	If rec.runId = "" {
		Do run.%Set("runId", "", "null")
	} Else {
		Set run.runId = rec.runId
	}
	Set input.run = run
	Set snapshot = ##class(SignalNoir.Application.Reference.Store).For(run)
	If snapshot.ok Set input.reference = snapshot.obj
	Return input
}

ClassMethod Verdict(validator As SignalNoir.Core.Port.Validator, input As SignalNoir.Core.Dto.ValidationInput) As %DynamicObject
{
	Return validator.Validate(input).ToJson()
}

}
