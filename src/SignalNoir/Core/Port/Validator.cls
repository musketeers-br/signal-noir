Class SignalNoir.Core.Port.Validator Extends %RegisteredObject [ Abstract ]
{

/// Seam v2 (contract change 004). Deterministic, origin-blind, no I/O: every input,
/// including now and the reference-data snapshot, arrives in the ValidationInput.
Method Validate(input As SignalNoir.Core.Dto.ValidationInput) As SignalNoir.Core.Dto.ValidatorVerdict
{
	Set v = ##class(SignalNoir.Core.Dto.ValidatorVerdict).%New()
	Set v.verdict = "blocked"
	Do v.reasons.Insert("REFERENCE_DATA_UNAVAILABLE")
	If $IsObject(input) Set v.at = input.now
	Return v
}

/// The verdict plus one PreconditionResult per declared precondition, checked against
/// input.observed right before the send. Results are returned in results.
Method Revalidate(input As SignalNoir.Core.Dto.ValidationInput, Output results As %ListOfObjects) As SignalNoir.Core.Dto.ValidatorVerdict
{
	Set results = ##class(%ListOfObjects).%New()
	Return ..Validate(input)
}

/// Whether actor may approve within run (inRun, runId)
Method Admit(actor As %String, run As %DynamicObject) As SignalNoir.Core.Dto.Admission
{
	Set a = ##class(SignalNoir.Core.Dto.Admission).%New()
	Set a.admissible = 0
	Set a.reason = "ACTOR_NOT_ALLOWED_TO_APPROVE"
	Return a
}

}
